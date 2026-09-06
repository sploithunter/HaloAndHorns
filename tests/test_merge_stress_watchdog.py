import importlib.util
import json
from pathlib import Path
import signal
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("watchdog", ROOT / "tools/merge_stress_watchdog.py")
watchdog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watchdog)


class WatchdogTest(unittest.TestCase):
    def setUp(self):
        self.cfg = json.loads((ROOT / "configs/merge_stress_host.json").read_text())
        self.base = {"start_identity": 123, "pressure_level": 1, "footprint_bytes": 5 * 1024**3}

    def reason(self, **changes):
        return watchdog.limit_reason(self.cfg, self.base, {**self.base, **changes}, 1)

    def test_healthy(self):
        watchdog.validate_config(self.cfg)
        self.assertIsNone(self.reason())

    def test_footprint_not_rss_is_the_limit(self):
        self.assertEqual(self.reason(footprint_bytes=8 * 1024**3, resident_bytes=1), "process_footprint")

    def test_growth_and_system_pressure(self):
        self.assertEqual(self.reason(footprint_bytes=7 * 1024**3), "process_growth")
        self.assertEqual(self.reason(pressure_level=2), "system_memory_pressure")

    def test_pid_reuse_and_duration(self):
        self.assertEqual(self.reason(start_identity=124), "process_identity_changed")
        self.assertEqual(watchdog.limit_reason(self.cfg, self.base, self.base, 180), "duration_limit")

    def test_refuse_unsafe_start(self):
        current = {**self.base, "footprint_bytes": 6 * 1024**3}
        self.assertEqual(watchdog.limit_reason(self.cfg, current, current, 0, startup=True), "startup_footprint")

    def test_config_rejects_nan_and_no_headroom(self):
        for cfg in ({**self.cfg, "sample_seconds": float("nan")}, {**self.cfg, "maximum_start_footprint_gib": 9}):
            with self.assertRaises(ValueError):
                watchdog.validate_config(cfg)

    def test_suspend_only_the_expected_live_process(self):
        calls = []
        class Process:
            pid = 4242
            executable = "/studio"
            birth = 123
            def path(self):
                return self.executable
            def identity(self):
                return self.birth
        process = Process()
        send = lambda *args: calls.append(args)
        self.assertTrue(watchdog.suspend_exact(process, 123, "/studio", send))
        self.assertEqual(calls, [(4242, signal.SIGSTOP)])
        process.birth = 124
        self.assertFalse(watchdog.suspend_exact(process, 123, "/studio", send))
        process.birth, process.executable = 123, "/another-app"
        self.assertFalse(watchdog.suspend_exact(process, 123, "/studio", send))
        self.assertEqual(len(calls), 1)


if __name__ == "__main__":
    unittest.main()
