#!/usr/bin/env python3
"""Read the fixed-key Halo & Horns retention dashboard without listing raw events."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.parse
from pathlib import Path
from typing import Any

import export_retention

DEFAULT_STORE = "RetentionDashboard_v1"
DEFAULT_BUCKET_COUNT = 16


def entry_path(universe_id: str, store: str, key: str) -> str:
    return (
        f"universes/{universe_id}/data-stores/"
        f"{urllib.parse.quote(store, safe='')}/scopes/global/entries/"
        f"{urllib.parse.quote(key, safe='')}"
    )


def read_bucket(
    universe_id: str, store: str, date_utc: str, bucket: int, api_key: str
) -> dict[str, Any] | None:
    key = f"d{date_utc}/b{bucket:02d}"
    try:
        payload = export_retention.api_get(
            entry_path(universe_id, store, key),
            api_key,
        )
    except RuntimeError as error:
        if "HTTP 404" in str(error):
            return None
        raise
    value = payload.get("value")
    if not isinstance(value, dict):
        raise RuntimeError(f"Dashboard key {key} did not contain an object value")
    return value


def dashboard_payload(
    buckets: list[dict[str, Any]], date_utc: str, bucket_count: int
) -> dict[str, Any]:
    counters = export_retention.combined_counters(buckets)
    summary = export_retention.summary_from(buckets)
    definitions: dict[str, Any] = {}
    exclusions: dict[str, Any] = {}
    updated_at = 0
    builds: dict[str, dict[str, Any]] = {}
    for bucket in buckets:
        if not definitions and isinstance(bucket.get("definitions"), dict):
            definitions = bucket["definitions"]
        if not exclusions and isinstance(bucket.get("exclusions"), dict):
            exclusions = bucket["exclusions"]
        updated_at = max(updated_at, int(bucket.get("updatedAt") or 0))
        contributions = bucket.get("contributions")
        if not isinstance(contributions, dict):
            continue
        for contribution in contributions.values():
            if not isinstance(contribution, dict):
                continue
            server = (
                contribution.get("server")
                if isinstance(contribution.get("server"), dict)
                else {}
            )
            place_version = int(server.get("placeVersion") or 0)
            commit = "".join(
                character
                for character in str(server.get("buildCommit") or "")
                if character.isalnum() or character == "_"
            )
            if place_version > 0:
                build_key = f"place:{place_version}"
            elif commit:
                build_key = f"commit:{commit[:40]}"
            else:
                build_key = "unknown"
            build = builds.setdefault(
                build_key,
                {"server": server, "contributors": 0, "counters": {}},
            )
            build["contributors"] += 1
            contribution_counters = contribution.get("counters")
            if isinstance(contribution_counters, dict):
                export_retention.merge_numeric(build["counters"], contribution_counters)
    for build in builds.values():
        build["summary"] = export_retention.summary_from(
            [{"counters": build["counters"]}]
        )
    return {
        "schemaVersion": 2,
        "dateUtc": date_utc,
        "bucketCount": bucket_count,
        "bucketsPresent": len(buckets),
        "updatedAt": updated_at,
        "exclusions": exclusions,
        "definitions": definitions,
        "builds": builds,
        "summary": summary,
        "tutorialFunnel": export_retention.tutorial_rows(buckets),
        "starterChoice": counters.get("starterChoice", {}),
        "powerPicks": counters.get("powerPicks", {}),
        "earnedLevels": counters.get("earnedLevels", {}),
        "claimedLevels": counters.get("claimedLevels", {}),
        "newPlayerExitEarnedLevels": counters.get("newPlayerExitEarnedLevels", {}),
        "areasUnlocked": counters.get("areasUnlocked", {}),
        "questsCompleted": counters.get("questsCompleted", {}),
        "counters": counters,
    }


def percent(value: Any) -> str:
    if value is None:
        return "n/a"
    return f"{100 * float(value):.1f}%"


def seconds(value: Any) -> str:
    if value is None:
        return "n/a"
    return f"{float(value):.1f}s"


def print_dashboard(payload: dict[str, Any]) -> None:
    summary = payload["summary"]
    print(
        f"Halo & Horns retention dashboard — {payload['dateUtc']} UTC "
        f"({payload['bucketsPresent']}/{payload['bucketCount']} populated buckets)"
    )
    prefixes = (payload.get("exclusions") or {}).get("playerNamePrefixes") or []
    print(f"Excluded username prefixes: {', '.join(prefixes) if prefixes else 'none'}")
    print()
    print(
        "Sessions: "
        f"{summary['sessionsStarted']} started, {summary['sessionsEnded']} ended, "
        f"{seconds(summary['averageCompletedSessionSeconds'])} average completed"
    )
    print(
        "New players: "
        f"{summary['newPlayers']} started, {summary['newPlayerSessionsEnded']} ended, "
        f"{seconds(summary['averageCompletedNewPlayerSessionSeconds'])} average completed"
    )
    print(
        "Tutorial complete: "
        f"{summary['newPlayerTutorialCompleted']}/{summary['newPlayers']} "
        f"({percent(summary['newPlayerTutorialCompletionRate'])})"
    )
    print(
        "Distinct cohort returners: "
        f"D1 {summary['distinctD1Returners']}/{summary['newPlayers']} "
        f"({percent(summary['distinctD1RetentionRate'])}); "
        f"D2–7 {summary['distinctD2To7Returners']}/{summary['newPlayers']} "
        f"({percent(summary['distinctD2To7RetentionRate'])}); "
        f"D8–30 {summary['distinctD8To30Returners']}/{summary['newPlayers']} "
        f"({percent(summary['distinctD8To30RetentionRate'])})"
    )
    print("  Windows mature after 1, 7, and 30 complete UTC days, respectively.")
    print(
        "Exited below earned level 2: "
        f"{summary['exitedBeforeEarnedLevel2']}/{summary['newPlayerSessionsEnded']} "
        f"({percent(summary['exitedBeforeEarnedLevel2Rate'])})"
    )
    print()
    if payload.get("builds"):
        print("Published build populations")
        for build_key, build in sorted(payload["builds"].items()):
            build_summary = build["summary"]
            print(
                f"  {build_key}: {build_summary['newPlayers']} new players, "
                f"{build_summary['sessionsStarted']} sessions "
                f"({build['contributors']} server contributions)"
            )
        print()
    print("First-session tutorial funnel")
    for row in payload["tutorialFunnel"]:
        print(
            f"  {int(row['step'] or 0):>2}. {row['step_name']}: "
            f"{row['reached']}/{row['new_players']} "
            f"({percent(row['reach_rate'])}), "
            f"{seconds(row['mean_seconds_to_reach'])} mean, "
            f"{row['exited_while_step_active']} exits"
        )
    print()
    choice = payload.get("starterChoice") or {}
    print(
        "Starter choice: "
        f"{choice.get('selected', 0)}/{choice.get('shown', 0)} selected; "
        f"{json.dumps(choice.get('byPet', {}), sort_keys=True)}"
    )
    picks = payload.get("powerPicks") or {}
    pick_rows = export_retention.power_pick_share_rows(
        picks.get("byPower") if isinstance(picks, dict) else {},
        int(picks.get("total") or 0) if isinstance(picks, dict) else 0,
    )
    print(f"Power picks: {int(picks.get('total') or 0)} total")
    for row in pick_rows:
        print(f"  {row['power']}: {row['count']} ({percent(row['share'])})")
    print(
        "Levels earned: "
        f"{json.dumps(payload.get('earnedLevels', {}), sort_keys=True)}"
    )
    print(
        "New-player exit earned levels: "
        f"{json.dumps(payload.get('newPlayerExitEarnedLevels', {}), sort_keys=True)}"
    )
    print(
        "Areas unlocked: "
        f"{json.dumps(payload.get('areasUnlocked', {}), sort_keys=True)}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Read the small fixed-key external-player retention dashboard. "
            "No DataStore listing or raw event reads are performed."
        )
    )
    parser.add_argument("--universe-id", required=True, help="Roblox universe ID")
    parser.add_argument("--date", required=True, help="UTC date YYYYMMDD")
    parser.add_argument("--store", default=DEFAULT_STORE, help="DataStore name")
    parser.add_argument(
        "--bucket-count",
        type=int,
        default=DEFAULT_BUCKET_COUNT,
        help="Fixed bucket count from configs/retention.lua",
    )
    parser.add_argument("--json-output", type=Path, help="Optionally save the merged JSON")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    api_key = os.environ.get("ROBLOX_API_KEY")
    if not api_key:
        print("ROBLOX_API_KEY is required and is never written to output.", file=sys.stderr)
        return 2
    if len(args.date) != 8 or not args.date.isdigit():
        print("--date must be YYYYMMDD", file=sys.stderr)
        return 2
    if args.bucket_count < 1 or args.bucket_count > 100:
        print("--bucket-count must be between 1 and 100", file=sys.stderr)
        return 2

    buckets = []
    for bucket in range(args.bucket_count):
        value = read_bucket(
            args.universe_id,
            args.store,
            args.date,
            bucket,
            api_key,
        )
        if value is not None:
            buckets.append(value)
    payload = dashboard_payload(buckets, args.date, args.bucket_count)
    print_dashboard(payload)
    if args.json_output:
        args.json_output.write_text(
            json.dumps(payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print(f"\nMerged JSON: {args.json_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
