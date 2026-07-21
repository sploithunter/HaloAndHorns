#!/usr/bin/env python3
"""Read-only export of Halo & Horns RetentionEvents_v1 through Roblox Open Cloud v2."""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterator

BASE_URL = "https://apis.roblox.com/cloud/v2/"
DEFAULT_STORE = "RetentionEvents_v1"
MAX_API_ATTEMPTS = 8
RETRYABLE_HTTP_CODES = {429, 500, 502, 503, 504}
ENTRY_REQUEST_DELAY_SECONDS = 0.25


def api_get(path: str, api_key: str, params: dict[str, str] | None = None) -> dict[str, Any]:
    url = BASE_URL + path.lstrip("/")
    if params:
        url += "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"x-api-key": api_key})
    for attempt in range(MAX_API_ATTEMPTS):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            is_final_attempt = attempt + 1 >= MAX_API_ATTEMPTS
            if error.code not in RETRYABLE_HTTP_CODES or is_final_attempt:
                raise RuntimeError(
                    f"Roblox Open Cloud returned HTTP {error.code}: {body}"
                ) from error

            retry_after = error.headers.get("Retry-After")
            try:
                delay_seconds = float(retry_after) if retry_after else 2**attempt
            except ValueError:
                delay_seconds = 2**attempt
            delay_seconds = min(60.0, max(1.0, delay_seconds))
            print(
                f"Roblox Open Cloud returned HTTP {error.code}; "
                f"retrying in {delay_seconds:g}s "
                f"(attempt {attempt + 2}/{MAX_API_ATTEMPTS}).",
                file=sys.stderr,
            )
            time.sleep(delay_seconds)

    raise RuntimeError("Roblox Open Cloud request exhausted retries")


def list_entries(
    universe_id: str, store: str, api_key: str, key_prefix: str
) -> Iterator[dict[str, Any]]:
    path = f"universes/{universe_id}/data-stores/{urllib.parse.quote(store, safe='')}/entries"
    page_token = ""
    while True:
        params = {
            "maxPageSize": "100",
            "filter": f'id.startsWith("global/{key_prefix}")',
        }
        if page_token:
            params["pageToken"] = page_token
        payload = api_get(path, api_key, params)
        yield from payload.get("dataStoreEntries", [])
        page_token = payload.get("nextPageToken", "")
        if not page_token:
            return


def get_entry(entry: dict[str, Any], api_key: str) -> dict[str, Any]:
    path = entry.get("path")
    if not isinstance(path, str) or not path:
        raise RuntimeError(f"List response did not include an entry path: {entry!r}")
    payload = api_get(path, api_key)
    value = payload.get("value")
    if not isinstance(value, dict):
        raise RuntimeError(f"Entry {path} did not contain an object value")
    value["_entryPath"] = path
    # The v2 entry-read budget is lower than a local loop can consume. A small
    # deterministic delay avoids turning a large launch export into a burst of
    # 429 responses; api_get still backs off when other clients share the key.
    time.sleep(ENTRY_REQUEST_DELAY_SECONDS)
    return value


def listed_session_number(entry: dict[str, Any]) -> int | None:
    """Read the session number from a listed, URL-encoded event entry path."""
    path = entry.get("path")
    if not isinstance(path, str):
        return None
    decoded = urllib.parse.unquote(path)
    start = decoded.rfind("/s")
    if start < 0:
        return None
    start += 2
    end = decoded.find("/c", start)
    if end < 0:
        return None
    try:
        return int(decoded[start:end])
    except ValueError:
        return None


def event_rows(chunks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for chunk in chunks:
        server = chunk.get("server") if isinstance(chunk.get("server"), dict) else {}
        for event in chunk.get("events", []):
            if not isinstance(event, dict):
                continue
            rows.append(
                {
                    "cohort_date": chunk.get("cohortDate"),
                    "user_id": chunk.get("userId"),
                    "session_number": chunk.get("sessionNumber"),
                    "session_started_at": chunk.get("sessionStartedAt"),
                    "chunk": chunk.get("chunk"),
                    "sequence": event.get("sequence"),
                    "event_at": event.get("at"),
                    "seconds_since_join": event.get("seconds"),
                    "event_name": event.get("name"),
                    "place_id": server.get("placeId"),
                    "universe_id": server.get("universeId"),
                    "job_id": server.get("jobId"),
                    "private_server": server.get("privateServer"),
                    "context_json": json.dumps(
                        event.get("context"), separators=(",", ":"), sort_keys=True
                    ),
                    "entry_path": chunk.get("_entryPath"),
                }
            )
    rows.sort(
        key=lambda row: (
            str(row["cohort_date"] or ""),
            int(row["user_id"] or 0),
            int(row["session_number"] or 0),
            int(row["sequence"] or 0),
        )
    )
    return rows


def merge_numeric(target: dict[str, Any], source: dict[str, Any]) -> None:
    for key, value in source.items():
        if isinstance(value, bool):
            continue
        if isinstance(value, (int, float)):
            target[key] = target.get(key, 0) + value
        elif isinstance(value, dict):
            child = target.setdefault(key, {})
            if isinstance(child, dict):
                merge_numeric(child, value)


def combined_counters(aggregates: list[dict[str, Any]]) -> dict[str, Any]:
    combined: dict[str, Any] = {}
    for aggregate in aggregates:
        counters = aggregate.get("counters")
        if isinstance(counters, dict):
            merge_numeric(combined, counters)
    return combined


def ratio(numerator: Any, denominator: Any) -> float | None:
    denominator = float(denominator or 0)
    return float(numerator or 0) / denominator if denominator > 0 else None


def summary_from(aggregates: list[dict[str, Any]]) -> dict[str, Any]:
    counters = combined_counters(aggregates)
    sessions_ended = counters.get("sessionsEnded", 0)
    new_players = counters.get("newPlayers", 0)
    new_player_sessions_ended = counters.get("newPlayerSessionsEnded", 0)
    return {
        "aggregateShardCount": len(aggregates),
        "sessionsStarted": counters.get("sessionsStarted", 0),
        "sessionsEnded": sessions_ended,
        "averageCompletedSessionSeconds": ratio(
            counters.get("totalSessionSeconds", 0), sessions_ended
        ),
        "newPlayers": new_players,
        "newPlayerSessionsEnded": new_player_sessions_ended,
        "averageCompletedNewPlayerSessionSeconds": ratio(
            counters.get("newPlayerTotalSessionSeconds", 0), new_player_sessions_ended
        ),
        "tutorialCompleted": counters.get("tutorialCompleted", 0),
        "newPlayerTutorialCompleted": counters.get("newPlayerTutorialCompleted", 0),
        "newPlayerTutorialCompletionRate": ratio(
            counters.get("newPlayerTutorialCompleted", 0), new_players
        ),
        "exitedBeforeEarnedLevel2": counters.get("exitedBeforeEarnedLevel2", 0),
        "exitedBeforeEarnedLevel2Rate": ratio(
            counters.get("exitedBeforeEarnedLevel2", 0), new_player_sessions_ended
        ),
        "exitedBeforeClaimedLevel2": counters.get("exitedBeforeClaimedLevel2", 0),
        "exitedBeforeClaimedLevel2Rate": ratio(
            counters.get("exitedBeforeClaimedLevel2", 0), new_player_sessions_ended
        ),
    }


def tutorial_rows(aggregates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    counters = combined_counters(aggregates)
    new_players = counters.get("newPlayers", 0)
    step_counters = counters.get("tutorialSteps", {})
    exit_counters = counters.get("tutorialExitBefore", {})
    definitions: list[dict[str, Any]] = []
    for aggregate in aggregates:
        candidate = (aggregate.get("definitions") or {}).get("tutorialSteps")
        if isinstance(candidate, list) and candidate:
            definitions = candidate
            break

    rows = []
    previous = new_players
    for step in definitions:
        metric = step_counters.get(step.get("id"), {})
        reached = metric.get("reached", 0)
        rows.append(
            {
                "step": step.get("index"),
                "step_id": step.get("id"),
                "step_name": step.get("name"),
                "new_players": new_players,
                "reached": reached,
                "reach_rate": ratio(reached, new_players),
                "conversion_from_previous": ratio(reached, previous),
                "drop_from_previous": max(0, previous - reached),
                "mean_seconds_to_reach": ratio(metric.get("totalSecondsToReach", 0), reached),
                "exited_while_step_active": exit_counters.get(step.get("id"), 0),
            }
        )
        previous = reached
    return rows


def level_exit_rows(aggregates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    counters = combined_counters(aggregates)
    rows = []
    for dimension in (
        "exitEarnedLevels",
        "exitClaimedLevels",
        "newPlayerExitEarnedLevels",
        "newPlayerExitClaimedLevels",
    ):
        values = counters.get(dimension, {})
        for level, players in values.items():
            rows.append({"dimension": dimension, "level": int(level), "players": players})
    rows.sort(key=lambda row: (row["dimension"], row["level"]))
    return rows


def event_count_rows(aggregates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    events = combined_counters(aggregates).get("events", {})
    return [
        {"event_name": name, "count": count}
        for name, count in sorted(events.items(), key=lambda item: (-item[1], item[0]))
    ]


def write_csv(path: Path, rows: list[dict[str, Any]], fields: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def write_exports(
    output_dir: Path,
    chunks: list[dict[str, Any]],
    aggregates: list[dict[str, Any]] | None = None,
    manifest_filters: dict[str, Any] | None = None,
) -> tuple[int, int]:
    output_dir.mkdir(parents=True, exist_ok=True)
    aggregates = aggregates or []
    rows = event_rows(chunks)

    with (output_dir / "chunks.jsonl").open("w", encoding="utf-8") as handle:
        for chunk in chunks:
            json.dump(chunk, handle, separators=(",", ":"), sort_keys=True)
            handle.write("\n")

    with (output_dir / "events.jsonl").open("w", encoding="utf-8") as handle:
        for row in rows:
            json.dump(row, handle, separators=(",", ":"), sort_keys=True)
            handle.write("\n")

    fields = list(rows[0]) if rows else [
        "cohort_date",
        "user_id",
        "session_number",
        "session_started_at",
        "chunk",
        "sequence",
        "event_at",
        "seconds_since_join",
        "event_name",
        "place_id",
        "universe_id",
        "job_id",
        "private_server",
        "context_json",
        "entry_path",
    ]
    write_csv(output_dir / "events.csv", rows, fields)

    with (output_dir / "aggregates.jsonl").open("w", encoding="utf-8") as handle:
        for aggregate in aggregates:
            json.dump(aggregate, handle, separators=(",", ":"), sort_keys=True)
            handle.write("\n")

    summary = summary_from(aggregates)
    (output_dir / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    write_csv(
        output_dir / "tutorial_funnel.csv",
        tutorial_rows(aggregates),
        [
            "step",
            "step_id",
            "step_name",
            "new_players",
            "reached",
            "reach_rate",
            "conversion_from_previous",
            "drop_from_previous",
            "mean_seconds_to_reach",
            "exited_while_step_active",
        ],
    )
    write_csv(
        output_dir / "level_exit.csv",
        level_exit_rows(aggregates),
        ["dimension", "level", "players"],
    )
    write_csv(
        output_dir / "event_counts.csv",
        event_count_rows(aggregates),
        ["event_name", "count"],
    )

    cohort_rows = []
    for cohort_date in sorted(
        {str(aggregate.get("cohortDate")) for aggregate in aggregates}
    ):
        cohort_aggregates = [
            aggregate
            for aggregate in aggregates
            if str(aggregate.get("cohortDate")) == cohort_date
        ]
        cohort_rows.append({"cohort_date": cohort_date, **summary_from(cohort_aggregates)})
    write_csv(
        output_dir / "cohort_summary.csv",
        cohort_rows,
        [
            "cohort_date",
            "aggregateShardCount",
            "sessionsStarted",
            "sessionsEnded",
            "averageCompletedSessionSeconds",
            "newPlayers",
            "newPlayerSessionsEnded",
            "averageCompletedNewPlayerSessionSeconds",
            "tutorialCompleted",
            "newPlayerTutorialCompleted",
            "newPlayerTutorialCompletionRate",
            "exitedBeforeEarnedLevel2",
            "exitedBeforeEarnedLevel2Rate",
            "exitedBeforeClaimedLevel2",
            "exitedBeforeClaimedLevel2Rate",
        ],
    )

    manifest = {
        "schemaVersion": 1,
        "filters": manifest_filters or {},
        "chunkCount": len(chunks),
        "eventCount": len(rows),
        "aggregateShardCount": len(aggregates),
        "files": [
            "chunks.jsonl",
            "events.jsonl",
            "events.csv",
            "aggregates.jsonl",
            "summary.json",
            "tutorial_funnel.csv",
            "level_exit.csv",
            "event_counts.csv",
            "cohort_summary.csv",
        ],
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return len(chunks), len(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export the read-only launch retention event store to JSONL and CSV."
    )
    parser.add_argument("--universe-id", required=True, help="Roblox universe ID")
    parser.add_argument("--date", help="UTC cohort date YYYYMMDD; omit to export every date")
    parser.add_argument("--user-id", type=int, help="Optionally retain only one player after listing")
    parser.add_argument(
        "--session-number",
        type=int,
        help="Read only event chunks for this session number (for example, 1 for acquisition cohorts)",
    )
    parser.add_argument("--store", default=DEFAULT_STORE, help="DataStore name")
    parser.add_argument("--output", type=Path, help="Output directory")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    api_key = os.environ.get("ROBLOX_API_KEY")
    if not api_key:
        print("ROBLOX_API_KEY is required and is never written to output.", file=sys.stderr)
        return 2
    if args.date and (len(args.date) != 8 or not args.date.isdigit()):
        print("--date must be YYYYMMDD", file=sys.stderr)
        return 2
    if args.session_number is not None and args.session_number < 1:
        print("--session-number must be at least 1", file=sys.stderr)
        return 2

    event_prefix = f"d{args.date}/" if args.date else "d"
    aggregate_prefix = f"a{args.date}/" if args.date else "a"
    output_dir = args.output or Path(f"retention-export-{args.date or 'all'}")
    chunks = []
    for listed in list_entries(args.universe_id, args.store, api_key, event_prefix):
        if (
            args.session_number is not None
            and listed_session_number(listed) != args.session_number
        ):
            continue
        chunk = get_entry(listed, api_key)
        if args.user_id is None or chunk.get("userId") == args.user_id:
            chunks.append(chunk)
    chunks.sort(
        key=lambda chunk: (
            str(chunk.get("cohortDate") or ""),
            int(chunk.get("userId") or 0),
            int(chunk.get("sessionNumber") or 0),
            int(chunk.get("chunk") or 0),
        )
    )
    aggregates = []
    if args.user_id is None:
        for listed in list_entries(args.universe_id, args.store, api_key, aggregate_prefix):
            aggregates.append(get_entry(listed, api_key))
        aggregates.sort(
            key=lambda aggregate: (
                str(aggregate.get("cohortDate") or ""),
                str((aggregate.get("server") or {}).get("jobId") or ""),
            )
        )
    chunk_count, event_count = write_exports(
        output_dir,
        chunks,
        aggregates,
        {
            "cohortDate": args.date,
            "userId": args.user_id,
            "rawSessionNumber": args.session_number,
            "aggregateScope": "all sessions in the selected UTC cohort date",
        },
    )
    print(
        f"Exported {event_count} events in {chunk_count} chunks and "
        f"{len(aggregates)} aggregate shards to {output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
