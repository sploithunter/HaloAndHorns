#!/usr/bin/env python3
"""Read-only export of Halo & Horns RetentionEvents_v1 through Roblox Open Cloud v2."""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterator

BASE_URL = "https://apis.roblox.com/cloud/v2/"
DEFAULT_STORE = "RetentionEvents_v1"


def api_get(path: str, api_key: str, params: dict[str, str] | None = None) -> dict[str, Any]:
    url = BASE_URL + path.lstrip("/")
    if params:
        url += "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"x-api-key": api_key})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Roblox Open Cloud returned HTTP {error.code}: {body}") from error


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
    return value


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


def write_exports(output_dir: Path, chunks: list[dict[str, Any]]) -> tuple[int, int]:
    output_dir.mkdir(parents=True, exist_ok=True)
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
    with (output_dir / "events.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    manifest = {
        "schemaVersion": 1,
        "chunkCount": len(chunks),
        "eventCount": len(rows),
        "files": ["chunks.jsonl", "events.jsonl", "events.csv"],
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

    key_prefix = f"d{args.date}/" if args.date else "d"
    output_dir = args.output or Path(f"retention-export-{args.date or 'all'}")
    chunks = []
    for listed in list_entries(args.universe_id, args.store, api_key, key_prefix):
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
    chunk_count, event_count = write_exports(output_dir, chunks)
    print(f"Exported {event_count} events in {chunk_count} chunks to {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
