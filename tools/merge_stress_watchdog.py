"""Independent macOS memory guard for a single, explicitly selected Studio PID.

Default is read-only. --suspend-on-limit requires operator authorization; it sends
SIGSTOP, never SIGKILL, and never resumes or restarts Studio automatically. Run in
a separate terminal before starting a bounded fixture. Logs contain measurements,
not account snapshots. A watchdog is risk reduction, not an OOM guarantee.
"""

import argparse
import ctypes
import json
import math
import os
from pathlib import Path
import signal
import sys
import time


class RUsageV0(ctypes.Structure):
    # Darwin SDK sys/resource.h, RUSAGE_INFO_V0 (stable first ten uint64 fields).
    _fields_ = [("uuid", ctypes.c_ubyte * 16)] + [
        (name, ctypes.c_uint64)
        for name in (
            "user_time", "system_time", "pkg_idle_wkups", "interrupt_wkups",
            "pageins", "wired_size", "resident_size", "phys_footprint",
            "proc_start_abstime", "proc_exit_abstime",
        )
    ]


class MacProcess:
    def __init__(self, pid):
        if sys.platform != "darwin":
            raise RuntimeError("This guard requires macOS")
        self.pid = pid
        self.lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        self.lib.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
        self.lib.proc_pid_rusage.restype = ctypes.c_int
        self.lib.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
        self.lib.proc_pidpath.restype = ctypes.c_int
        self.system = ctypes.CDLL("/usr/lib/libSystem.B.dylib", use_errno=True)
        self.system.sysctlbyname.argtypes = [
            ctypes.c_char_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t),
            ctypes.c_void_p, ctypes.c_size_t,
        ]
        self.system.sysctlbyname.restype = ctypes.c_int

    def path(self):
        buf = ctypes.create_string_buffer(4096)  # PROC_PIDPATHINFO_MAXSIZE, libproc.h
        if self.lib.proc_pidpath(self.pid, buf, len(buf)) <= 0:
            raise ProcessLookupError(self.pid)
        return os.fsdecode(buf.value)

    def usage(self):
        usage = RUsageV0()
        if self.lib.proc_pid_rusage(self.pid, 0, ctypes.byref(usage)) != 0:
            raise ProcessLookupError(self.pid)
        return usage

    def identity(self):
        return self.usage().proc_start_abstime

    def sample(self):
        usage = self.usage()
        pressure = ctypes.c_int()
        size = ctypes.c_size_t(ctypes.sizeof(pressure))
        if self.system.sysctlbyname(
            b"kern.memorystatus_vm_pressure_level", ctypes.byref(pressure),
            ctypes.byref(size), None, 0,
        ) != 0:
            raise OSError(ctypes.get_errno(), "Cannot read system memory pressure")
        return {
            "pid": self.pid, "start_identity": usage.proc_start_abstime,
            "footprint_bytes": usage.phys_footprint,
            "resident_bytes": usage.resident_size,
            "pressure_level": pressure.value,
        }


def validate_config(cfg):
    for key in (
        "sample_seconds", "maximum_seconds", "maximum_footprint_gib",
        "maximum_growth_gib", "maximum_start_footprint_gib", "maximum_pressure_level",
    ):
        value = cfg[key]
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
            raise ValueError(f"{key} must be finite and positive")
    if cfg["maximum_start_footprint_gib"] >= cfg["maximum_footprint_gib"]:
        raise ValueError("Startup must leave memory headroom")
    if not Path(cfg["studio_executable"]).is_absolute():
        raise ValueError("Explicit absolute Studio executable required")


def limit_reason(cfg, baseline, current, elapsed, startup=False):
    if current["start_identity"] != baseline["start_identity"]:
        return "process_identity_changed"
    if current["pressure_level"] > cfg["maximum_pressure_level"]:
        return "system_memory_pressure"
    gib = 1024 ** 3
    ceiling = cfg["maximum_start_footprint_gib"] if startup else cfg["maximum_footprint_gib"]
    if current["footprint_bytes"] >= ceiling * gib:
        return "startup_footprint" if startup else "process_footprint"
    if current["footprint_bytes"] - baseline["footprint_bytes"] >= cfg["maximum_growth_gib"] * gib:
        return "process_growth"
    if elapsed >= cfg["maximum_seconds"]:
        return "duration_limit"
    return None


def suspend_exact(process, identity, expected_path, send_signal=os.kill):
    # Recheck both executable and birth time immediately before signaling. Never
    # signal a replacement process merely because the OS reused the numeric PID.
    if process.path() != expected_path or process.identity() != identity:
        return False
    send_signal(process.pid, signal.SIGSTOP)
    return True


def observation_reason(baseline, current, elapsed, duration):
    """Passive observation ignores memory thresholds and never requests a signal."""
    if current["start_identity"] != baseline["start_identity"]:
        return "process_identity_changed"
    return "observation_complete" if elapsed >= duration else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--config", type=Path, default=Path(__file__).resolve().parents[1] / "configs/merge_stress_host.json")
    parser.add_argument("--log", type=Path, required=True, help="New JSONL file outside /tmp; exclusive create")
    parser.add_argument("--suspend-on-limit", action="store_true", help="Only with operator authorization")
    parser.add_argument("--sample-only", action="store_true", help="One read-only sample; never sends signals")
    parser.add_argument("--observe-seconds", type=float, help="Passive time series: no memory gates or process signals")
    args = parser.parse_args()
    if args.observe_seconds is not None:
        if not math.isfinite(args.observe_seconds) or args.observe_seconds <= 0:
            parser.error("Observation duration must be positive and finite")
        if args.suspend_on_limit or args.sample_only:
            parser.error("Passive observation cannot be combined with signaling or sample-only mode")
    if args.pid <= 1:
        parser.error("An explicit Studio PID greater than 1 is required")
    cfg = json.loads(args.config.read_text())
    validate_config(cfg)
    process = MacProcess(args.pid)
    if process.path() != cfg["studio_executable"]:
        raise RuntimeError("Refusing a process that is not the configured Studio executable")
    baseline = process.sample()
    started = time.monotonic()
    # Exclusive creation prevents a rerun from overwriting previous evidence.
    with args.log.open("x", encoding="utf-8") as log:
        def emit(event, **fields):
            row = {"event": event, "utc_unix": time.time(), **fields}
            line = json.dumps(row, sort_keys=True)
            log.write(line + "\n")
            log.flush()
            print(line, flush=True)

        emit("sample" if args.sample_only else "starting", **baseline, config=cfg)
        if args.sample_only:
            return 0
        reason = None if args.observe_seconds else limit_reason(cfg, baseline, baseline, 0, startup=True)
        if reason:
            emit("refused_start", reason=reason)
            return 2  # Never suspend an already unsafe process merely by arming.
        emit("observing" if args.observe_seconds else "ready", pid=args.pid, suspension_enabled=args.suspend_on_limit)
        while True:
            time.sleep(cfg["sample_seconds"])
            try:
                current = process.sample()
                elapsed = time.monotonic() - started
                if args.observe_seconds:
                    reason = observation_reason(baseline, current, elapsed, args.observe_seconds)
                else:
                    reason = limit_reason(cfg, baseline, current, elapsed)
                emit("sample", **current)
            except ProcessLookupError:
                emit("process_exited")
                return 0
            except OSError as error:
                # Loss of monitoring is an unsafe test condition, not permission
                # to keep growing. Identity verification still precedes any signal.
                reason = "measurement_failed"
                emit("measurement_error", detail=str(error))
            if reason:
                if reason == "observation_complete":
                    emit("completed", reason=reason, suspended=False, pid=args.pid)
                    return 0
                suspended = False
                if args.suspend_on_limit and reason not in ("process_identity_changed", "duration_limit"):
                    try:
                        suspended = suspend_exact(process, baseline["start_identity"], cfg["studio_executable"])
                    except OSError as error:
                        emit("suspension_refused", detail=str(error))
                emit("limit", reason=reason, suspended=suspended, pid=args.pid)
                return 2


if __name__ == "__main__":
    sys.exit(main())
