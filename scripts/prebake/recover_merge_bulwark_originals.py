#!/usr/bin/env python3
"""Recover native Roblox bulwark Model packages from Studio's content cache.

Studio stores InsertService model results in an RBXH envelope.  The payload beginning at the
``<roblox!`` signature is the original RBXM package.  This tool matches packages by the durable
MeshId catalog and saves lossless, source-controlled snapshots for the Models.rbxm prebake.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


RBXM_MAGIC = b"<roblox!"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache-root", type=Path, required=True)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("scripts/merge_bulwark_model_ids.json"),
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("assets/source/props/merge_bulwarks/roblox_originals"),
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text())
    wanted: dict[bytes, tuple[str, dict]] = {}
    for family_id, family in manifest["families"].items():
        for entry in family["tiers"]:
            wanted[str(entry["meshId"]).encode()] = (family_id, entry)

    recovered: dict[str, dict] = {}
    for cache_file in args.cache_root.rglob("*"):
        if not cache_file.is_file():
            continue
        try:
            data = cache_file.read_bytes()
        except OSError:
            continue
        matches = [(mesh_id, value) for mesh_id, value in wanted.items() if mesh_id in data]
        if not matches:
            continue
        payload_offset = data.find(RBXM_MAGIC)
        if payload_offset < 0:
            continue
        payload = data[payload_offset:]
        for mesh_id, (family_id, entry) in matches:
            key = f"{family_id}/tier{entry['tier']}"
            if key in recovered:
                raise RuntimeError(f"multiple cached packages matched {key}")
            output_dir = args.output_root / family_id / f"tier{entry['tier']}"
            output_dir.mkdir(parents=True, exist_ok=True)
            output_path = output_dir / "model.rbxm"
            output_path.write_bytes(payload)
            recovered[key] = {
                "family": family_id,
                "tier": entry["tier"],
                "modelAssetId": str(entry["modelAssetId"]),
                "meshId": mesh_id.decode(),
                "sourceCacheFile": cache_file.name,
                "sha256": hashlib.sha256(payload).hexdigest(),
                "path": output_path.as_posix(),
            }

    missing = sorted(
        f"{family_id}/tier{entry['tier']}"
        for family_id, family in manifest["families"].items()
        for entry in family["tiers"]
        if f"{family_id}/tier{entry['tier']}" not in recovered
    )
    if missing:
        raise RuntimeError("missing cached native packages: " + ", ".join(missing))

    index_path = args.output_root / "index.json"
    index_path.write_text(json.dumps(dict(sorted(recovered.items())), indent=2) + "\n")
    print(f"recovered {len(recovered)} native Roblox model packages into {args.output_root}")


if __name__ == "__main__":
    main()
