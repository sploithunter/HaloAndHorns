"""Generate Spawn-native definitions from HH's config-owned prototype content."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
WORLD = ROOT / "ports/spawn/world"
data = json.loads((WORLD / "scripts/lib/data/merge.yml").read_text())
scene = data["tuning"]["scene"]
objects = json.loads((ROOT / "configs/spawn_merge_scene.json").read_text())
cells = WORLD / "places/main/cells"
cells.mkdir(parents=True, exist_ok=True)
import math
partitions = {}
for identity, spec in objects.items():
    point = spec.get("feetPosition", {})
    key = "x" + str(math.floor(point.get("x", 0) / 128 + 0.5)) + "z" + str(math.floor(point.get("z", 0) / 128 + 0.5))
    partitions.setdefault(key, {})[identity] = spec
for old in cells.glob("*.scene"):
    old.unlink()
for key, entries in partitions.items():
    rows = ["# spawn-scene v2 yaml " + key]
    for identity, spec in entries.items():
        rows.append(json.dumps(identity) + ":")
        rows.extend("  " + json.dumps(field) + ": " + json.dumps(value) for field, value in spec.items())
        rows.append("")
    (cells / (key + ".scene")).write_text("\n".join(rows))
root = {
    "name": "Halo & Horns · Merge Bay Lab", "description": "Combine eggs. Deploy your pets. Hold the line.",
    "camera": "templates/camera.js#camera", "lighting": "scripts/lighting.js", "defaultPlace": "main",
    "engine": {"behaviors": ["scripts/arrival.js"], "networking": {"mode": "multiplayer"}, "ui": {"theme": {"font": "Geist Pixel Square"}}},
    "inputs": {"actions": {"jump": {"keys": ["space"]}, "select": {}, "command": {}, "dragState": {}, "board": {"keys": ["b"]}}, "axes": {"moveX": {"keys": "a/d"}, "moveZ": {"keys": "s/w"}, "zoomIn": {"mouse": "wheelY"}}},
    "player": "templates/player.js#player", "ui": {"render": "scripts/ui.js"}, "nametag": "ui/nametag.js",
}
(WORLD / "world.config.yaml").write_text(json.dumps(root, indent=2) + "\n")
place = {"mode": "3d", "terrain": {"kind": "none"}, "gravity": {"x": 0, "y": -24, "z": 0}, "defaultSpawnPoint": scene["spawn"],
         "atmosphere": scene["atmosphere"]}
(WORLD / "places/main/config.yaml").write_text(json.dumps(place, indent=2) + "\n")
player = {"behavior": ["scripts/humanoid-locomotion.js", "scripts/player.js", "scripts/merge-input.js"], "feetPosition": scene["spawn"], "physics": {"body": "character"}, "tags": ["player"], "platformState": ["merge"], "state": {"merge": None, "mergeSelected": -1, "mergeBoardOpen": False}}
(WORLD / "templates/player.js").write_text("export const player = " + json.dumps(player, indent=2) + ";\n")
camera = {"kind": "custom", "behavior": ["scripts/merge-camera.js"], "orientation": {"source": "script"}, "pointerLock": False, "state": {}}
(WORLD / "templates/camera.js").write_text("export const camera = " + json.dumps(camera, indent=2) + ";\n")
print("Built", len(objects), "scene rows")

assets = json.loads((ROOT / "configs/spawn_merge_assets.json").read_text())
(WORLD / "scripts/lib/data/assets.yml").write_text(json.dumps(assets, indent=2) + "\n")
ui = json.loads((ROOT / "configs/spawn_merge_ui.json").read_text())
ui["style"] = (ROOT / "configs/spawn_merge_ui.css").read_text()
(WORLD / "scripts/lib/data/ui.yml").write_text(json.dumps(ui, indent=2) + "\n")
