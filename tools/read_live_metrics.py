#!/usr/bin/env python3
"""One-command acquisition and retention readout for Halo & Horns.

This intentionally reads only the 16 fixed daily keys in RetentionDashboard_v1.
It does not list or download RetentionEvents_v1 event chunks.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import export_retention
import read_retention_dashboard


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DAYS = 7


def load_env_file(path: Path) -> None:
    """Load a simple dotenv file without replacing explicit shell variables."""
    if not path.is_file():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        os.environ.setdefault(key, value)


def load_local_credentials() -> tuple[str, str]:
    # Local overrides are intentionally tried first. Secrets are never printed or
    # copied into the generated JSON report.
    load_env_file(ROOT / ".env.local")
    load_env_file(ROOT / ".env")
    api_key = os.environ.get("ROBLOX_API_KEY") or os.environ.get(
        "ROBLOX_OPEN_CLOUD_KEY"
    )
    universe_id = os.environ.get("ROBLOX_UNIVERSE_ID") or os.environ.get(
        "UNIVERSE_ID"
    )
    if not api_key:
        raise RuntimeError(
            "Set ROBLOX_OPEN_CLOUD_KEY (or ROBLOX_API_KEY) in .env.local or the shell."
        )
    if not universe_id:
        raise RuntimeError(
            "Set ROBLOX_UNIVERSE_ID (or UNIVERSE_ID) in .env.local or the shell."
        )
    return api_key, universe_id


def utc_date(value: str) -> datetime:
    try:
        return datetime.strptime(value, "%Y%m%d").replace(tzinfo=timezone.utc)
    except ValueError as error:
        raise argparse.ArgumentTypeError("date must be YYYYMMDD") from error


def fetch_day(
    universe_id: str,
    api_key: str,
    date_utc: str,
    store: str,
    bucket_count: int,
) -> dict[str, Any]:
    buckets = []
    for bucket in range(bucket_count):
        value = read_retention_dashboard.read_bucket(
            universe_id, store, date_utc, bucket, api_key
        )
        if value is not None:
            buckets.append(value)
    return read_retention_dashboard.dashboard_payload(
        buckets, date_utc, bucket_count
    )


def merge_days(days: list[dict[str, Any]]) -> dict[str, Any]:
    counters: dict[str, Any] = {}
    for day in days:
        source = day.get("counters")
        if isinstance(source, dict):
            export_retention.merge_numeric(counters, source)

    aggregates = []
    for day in days:
        aggregates.append(
            {
                "counters": day.get("counters", {}),
                "definitions": day.get("definitions", {}),
            }
        )
    return {
        "dates": [day["dateUtc"] for day in days],
        "counters": counters,
        "summary": export_retention.summary_from([{"counters": counters}]),
        "tutorialFunnel": export_retention.tutorial_rows(aggregates),
        "builds": sorted(
            {
                build_key
                for day in days
                for build_key in (day.get("builds") or {}).keys()
            }
        ),
    }


def funnel_reached(window: dict[str, Any], step_id: str) -> int:
    for row in window["tutorialFunnel"]:
        if row.get("step_id") == step_id:
            return int(row.get("reached") or 0)
    return 0


def ratio(numerator: float, denominator: float) -> float | None:
    return numerator / denominator if denominator else None


def metric_snapshot(window: dict[str, Any]) -> dict[str, Any]:
    counters = window["counters"]
    summary = window["summary"]
    new_players = int(summary.get("newPlayers") or 0)
    ended_new_players = int(summary.get("newPlayerSessionsEnded") or 0)
    sessions = int(summary.get("sessionsStarted") or 0)
    tutorial_complete = int(summary.get("newPlayerTutorialCompleted") or 0)
    below_level_2 = int(summary.get("exitedBeforeEarnedLevel2") or 0)
    starter = counters.get("starterChoice") or {}
    quests = counters.get("questsCompleted") or {}
    returners = counters.get("distinctReturners") or {}
    return {
        "newPlayers": new_players,
        "newPlayersPerDay": ratio(new_players, len(window["dates"])),
        "sessionsStarted": sessions,
        # This is session volume, not a unique-user D1 calculation.
        "repeatSessionVolume": max(0, sessions - new_players),
        "distinctD1Returners": int(returners.get("d1") or 0),
        "distinctD1RetentionRate": ratio(float(returners.get("d1") or 0), new_players),
        "distinctD2To7Returners": int(returners.get("d2_7") or 0),
        "distinctD2To7RetentionRate": ratio(
            float(returners.get("d2_7") or 0), new_players
        ),
        "distinctD8To30Returners": int(returners.get("d8_30") or 0),
        "distinctD8To30RetentionRate": ratio(
            float(returners.get("d8_30") or 0), new_players
        ),
        "averageCompletedNewPlayerSessionSeconds": summary.get(
            "averageCompletedNewPlayerSessionSeconds"
        ),
        "starterChoiceSelected": int(starter.get("selected") or 0),
        "starterChoiceShown": int(starter.get("shown") or 0),
        "starterChoiceRate": ratio(
            float(starter.get("selected") or 0), float(starter.get("shown") or 0)
        ),
        "firstHatch": funnel_reached(window, "hatch_first_egg"),
        "firstHatchRate": ratio(
            funnel_reached(window, "hatch_first_egg"), new_players
        ),
        "tutorialCompleted": tutorial_complete,
        "tutorialCompletionRate": ratio(tutorial_complete, new_players),
        "firstQuestCompleted": int(quests.get("fs_boost") or 0),
        "firstQuestCompletionRate": ratio(
            float(quests.get("fs_boost") or 0), new_players
        ),
        "firstStepsCompleted": int(quests.get("fs_cave") or 0),
        "firstStepsCompletionRate": ratio(
            float(quests.get("fs_cave") or 0), new_players
        ),
        "reachedLevel2ByExit": max(0, ended_new_players - below_level_2),
        "reachedLevel2ByExitRate": ratio(
            max(0, ended_new_players - below_level_2), ended_new_players
        ),
        "sessionEndCoverage": ratio(
            float(summary.get("sessionsEnded") or 0), sessions
        ),
        "newPlayerSessionEndCoverage": ratio(ended_new_players, new_players),
    }


def pct(value: Any) -> str:
    return "n/a" if value is None else f"{100 * float(value):.1f}%"


def seconds(value: Any) -> str:
    return "n/a" if value is None else f"{float(value):.0f}s"


def number(value: Any, digits: int = 1) -> str:
    return "n/a" if value is None else f"{float(value):.{digits}f}"


def change(current: Any, previous: Any, rate: bool = False) -> str:
    if current is None or previous is None:
        return "n/a"
    current_value = float(current)
    previous_value = float(previous)
    if rate:
        return f"{100 * (current_value - previous_value):+.1f} pp"
    if previous_value == 0:
        return f"{current_value - previous_value:+.1f} (prior 0)"
    return (
        f"{current_value - previous_value:+.1f} "
        f"({100 * (current_value / previous_value - 1):+.1f}%)"
    )


def print_readout(report: dict[str, Any]) -> None:
    current = report["currentWindow"]["metrics"]
    previous = report["previousWindow"]["metrics"]
    partial = report["todayPartial"]["metrics"]
    current_dates = report["currentWindow"]["dates"]
    previous_dates = report["previousWindow"]["dates"]

    print("Halo & Horns — acquisition and retention quick read")
    print(f"Pulled: {report['pulledAtUtc']}")
    print(
        f"Current complete window: {current_dates[0]}–{current_dates[-1]} UTC; "
        f"comparison: {previous_dates[0]}–{previous_dates[-1]} UTC"
    )
    print(
        "Internal/test username prefixes are excluded by the production dashboard: "
        + ", ".join(report["excludedNamePrefixes"])
    )
    print()
    print("TODAY (partial UTC day)")
    print(
        f"  {partial['newPlayers']} new players, {partial['sessionsStarted']} sessions, "
        f"{partial['repeatSessionVolume']} repeat-session volume"
    )
    print(
        f"  First hatch {partial['firstHatch']}/{partial['newPlayers']} "
        f"({pct(partial['firstHatchRate'])}); tutorial complete "
        f"{partial['tutorialCompleted']}/{partial['newPlayers']} "
        f"({pct(partial['tutorialCompletionRate'])})"
    )
    print(
        "  Average completed new-player session: "
        f"{seconds(partial['averageCompletedNewPlayerSessionSeconds'])}"
    )
    print()
    print(f"LAST {len(current_dates)} COMPLETE DAYS vs PRIOR {len(previous_dates)}")
    print(
        f"  New players: {current['newPlayers']} "
        f"({number(current['newPlayersPerDay'])}/day), "
        f"change {change(current['newPlayers'], previous['newPlayers'])}"
    )
    print(
        f"  Sessions: {current['sessionsStarted']}; repeat-session volume: "
        f"{current['repeatSessionVolume']}, change "
        f"{change(current['repeatSessionVolume'], previous['repeatSessionVolume'])}"
    )
    print(
        "  Distinct cohort returners: "
        f"D1 {current['distinctD1Returners']}/{current['newPlayers']} "
        f"({pct(current['distinctD1RetentionRate'])}); "
        f"D2–7 {current['distinctD2To7Returners']}/{current['newPlayers']} "
        f"({pct(current['distinctD2To7RetentionRate'])}); "
        f"D8–30 {current['distinctD8To30Returners']}/{current['newPlayers']} "
        f"({pct(current['distinctD8To30RetentionRate'])})"
    )
    print(
        "  Average completed new-player session: "
        f"{seconds(current['averageCompletedNewPlayerSessionSeconds'])}, change "
        f"{change(current['averageCompletedNewPlayerSessionSeconds'], previous['averageCompletedNewPlayerSessionSeconds'])}"
    )
    print(
        f"  First hatch: {current['firstHatch']}/{current['newPlayers']} "
        f"({pct(current['firstHatchRate'])}), change "
        f"{change(current['firstHatchRate'], previous['firstHatchRate'], rate=True)}"
    )
    print(
        f"  Tutorial complete: {current['tutorialCompleted']}/{current['newPlayers']} "
        f"({pct(current['tutorialCompletionRate'])}), change "
        f"{change(current['tutorialCompletionRate'], previous['tutorialCompletionRate'], rate=True)}"
    )
    print(
        f"  First quest: {current['firstQuestCompleted']}/{current['newPlayers']} "
        f"({pct(current['firstQuestCompletionRate'])}); First Steps: "
        f"{current['firstStepsCompleted']}/{current['newPlayers']} "
        f"({pct(current['firstStepsCompletionRate'])})"
    )
    print(
        f"  Reached level 2 by first-session exit: "
        f"{current['reachedLevel2ByExit']} "
        f"({pct(current['reachedLevel2ByExitRate'])}), change "
        f"{change(current['reachedLevel2ByExitRate'], previous['reachedLevel2ByExitRate'], rate=True)}"
    )
    print()
    print("FIRST-SESSION FUNNEL (current complete window)")
    for row in report["currentWindow"]["tutorialFunnel"]:
        print(
            f"  {int(row.get('step') or 0):>2}. {row.get('step_name')}: "
            f"{int(row.get('reached') or 0)}/{int(row.get('new_players') or 0)} "
            f"({pct(row.get('reach_rate'))}), "
            f"step conversion {pct(row.get('conversion_from_previous'))}"
        )
    print()
    print("DATA QUALITY / LIMITS")
    print(
        f"  Session-end coverage: {pct(current['sessionEndCoverage'])}; "
        f"new-player end coverage: {pct(current['newPlayerSessionEndCoverage'])}."
    )
    print("  Distinct-return rates are cohort-attributed; D1/D2–7/D8–30 mature after 1/7/30 UTC days.")
    print("  Repeat-session volume remains a non-distinct activity diagnostic, not retention.")
    print(
        "  Quest completion counters are all-session one-time events; dividing them by new players "
        "is a directional funnel proxy, not a strict first-session cohort rate."
    )
    print(
        "  Paid acquisition impressions/clicks/attributed plays remain Roblox Creator Hub / "
        "Analytics Query API metrics."
    )
    if len(report["currentWindow"]["builds"]) > 1:
        print(
            "  Current window mixes published builds: "
            + ", ".join(report["currentWindow"]["builds"])
            + "; do not attribute the aggregate change to one build."
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Read the live fixed-key dashboard and compare recent complete UTC days "
            "with the immediately preceding window."
        )
    )
    parser.add_argument(
        "--days", type=int, default=DEFAULT_DAYS, help="Complete days per window"
    )
    parser.add_argument(
        "--as-of",
        type=utc_date,
        help="UTC date YYYYMMDD to treat as the partial/current day (default: today)",
    )
    parser.add_argument("--universe-id", help="Override the .env.local universe ID")
    parser.add_argument(
        "--store", default=read_retention_dashboard.DEFAULT_STORE, help="DataStore name"
    )
    parser.add_argument(
        "--bucket-count",
        type=int,
        default=read_retention_dashboard.DEFAULT_BUCKET_COUNT,
    )
    parser.add_argument("--json-output", type=Path, help="Optionally save report JSON")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.days < 1 or args.days > 30:
        print("--days must be between 1 and 30", file=sys.stderr)
        return 2
    if args.bucket_count < 1 or args.bucket_count > 100:
        print("--bucket-count must be between 1 and 100", file=sys.stderr)
        return 2
    try:
        api_key, default_universe = load_local_credentials()
        universe_id = args.universe_id or default_universe
        as_of = args.as_of or datetime.now(timezone.utc)
        dates = [as_of - timedelta(days=offset) for offset in range(2 * args.days + 1)]
        daily = {
            date.strftime("%Y%m%d"): fetch_day(
                universe_id,
                api_key,
                date.strftime("%Y%m%d"),
                args.store,
                args.bucket_count,
            )
            for date in dates
        }
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1

    today_key = as_of.strftime("%Y%m%d")
    current_keys = [
        (as_of - timedelta(days=offset)).strftime("%Y%m%d")
        for offset in range(args.days, 0, -1)
    ]
    previous_keys = [
        (as_of - timedelta(days=offset)).strftime("%Y%m%d")
        for offset in range(2 * args.days, args.days, -1)
    ]
    current = merge_days([daily[key] for key in current_keys])
    previous = merge_days([daily[key] for key in previous_keys])
    partial = merge_days([daily[today_key]])
    exclusions = (daily[today_key].get("exclusions") or {}).get(
        "playerNamePrefixes"
    ) or ["colorado", "waxillium", "waxilium", "sploit", "macros"]
    report = {
        "schemaVersion": 2,
        "pulledAtUtc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source": args.store,
        "universeId": universe_id,
        "excludedNamePrefixes": exclusions,
        "todayPartial": {
            "dates": partial["dates"],
            "metrics": metric_snapshot(partial),
            "tutorialFunnel": partial["tutorialFunnel"],
            "builds": partial["builds"],
        },
        "currentWindow": {
            "dates": current["dates"],
            "metrics": metric_snapshot(current),
            "tutorialFunnel": current["tutorialFunnel"],
            "builds": current["builds"],
        },
        "previousWindow": {
            "dates": previous["dates"],
            "metrics": metric_snapshot(previous),
            "tutorialFunnel": previous["tutorialFunnel"],
            "builds": previous["builds"],
        },
    }
    print_readout(report)
    if args.json_output:
        args.json_output.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(f"\nSaved JSON: {args.json_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
