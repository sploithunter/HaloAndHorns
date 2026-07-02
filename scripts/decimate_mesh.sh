#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
SCRIPT="${ROOT}/scripts/blender/decimate_for_roblox.py"
DEFAULT_TARGETS="3000,5000,7500,10000"

usage() {
  cat <<EOF
Decimate Meshy (or other) models to Roblox-friendly triangle budgets.

Usage:
  bash scripts/decimate_mesh.sh <input.obj|input_dir> [more inputs...] [options]

Options:
  --output <dir>       Output directory (default: <input_dir>/roblox_decimated)
  --targets <list>     Comma-separated triangle targets (default: ${DEFAULT_TARGETS})
  --tolerance <float>  Relative face-count tolerance (default: 0.03)
  --help               Show this help

Examples:
  bash scripts/decimate_mesh.sh ~/Downloads/Meshy_AI_Emerald_Crystal_Garde_0603155051_texture_obj
  bash scripts/decimate_mesh.sh model.obj --output ./assets/decimated/emerald
  bash scripts/decimate_mesh.sh ~/Downloads/Meshy_* --targets 3000,5000,7500,10000

Requires Blender on macOS at:
  /Applications/Blender.app/Contents/MacOS/Blender
Override with BLENDER=/path/to/Blender
EOF
}

if [[ ! -x "${BLENDER}" ]]; then
  echo "Blender not found at: ${BLENDER}" >&2
  echo "Install Blender or set BLENDER to the executable path." >&2
  exit 1
fi

if [[ ! -f "${SCRIPT}" ]]; then
  echo "Missing Blender script: ${SCRIPT}" >&2
  exit 1
fi

OUTPUT=""
TARGETS="${DEFAULT_TARGETS}"
TOLERANCE="0.03"
INPUTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --targets)
      TARGETS="${2:-}"
      shift 2
      ;;
    --tolerance)
      TOLERANCE="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      INPUTS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#INPUTS[@]} -eq 0 ]]; then
  usage >&2
  exit 1
fi

resolve_output_dir() {
  local input_path="$1"
  local resolved
  resolved="$(python3 - <<'PY' "$input_path"
import sys
from pathlib import Path
path = Path(sys.argv[1]).expanduser().resolve()
if path.is_file():
    print(path.parent / "roblox_decimated")
else:
    print(path / "roblox_decimated")
PY
)"
  printf '%s\n' "${resolved}"
}

slugify() {
  python3 - <<'PY' "$1"
import re
import sys
name = sys.argv[1]
slug = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("_")
print(slug or "mesh")
PY
}

for input_path in "${INPUTS[@]}"; do
  if [[ ! -e "${input_path}" ]]; then
    echo "Input not found: ${input_path}" >&2
    exit 1
  fi

  if [[ -n "${OUTPUT}" && ${#INPUTS[@]} -eq 1 ]]; then
    out_dir="${OUTPUT}"
  elif [[ -n "${OUTPUT}" ]]; then
    base_name="$(basename "${input_path}")"
    base_name="${base_name%.obj}"
    out_dir="${OUTPUT}/$(slugify "${base_name}")"
  else
    out_dir="$(resolve_output_dir "${input_path}")"
  fi

  echo "==> Decimating ${input_path}"
  echo "    Output: ${out_dir}"

  "${BLENDER}" --background --python "${SCRIPT}" -- \
    --input "${input_path}" \
    --output "${out_dir}" \
    --targets "${TARGETS}" \
    --tolerance "${TOLERANCE}"
done

echo "All decimation jobs finished."
