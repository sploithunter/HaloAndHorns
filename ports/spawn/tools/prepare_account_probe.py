"""Create an isolated preview fixture; never writes to a Spawn clone or publishes."""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PORT = ROOT / "ports/spawn"


def scene(rows, cell="x0z0"):
    return f"# spawn-scene v2 yaml {cell}\n" + "\n".join(
        json.dumps(key) + ":\n" + "\n".join(
            "  " + json.dumps(field) + ": " + json.dumps(value)
            for field, value in row.items()
        ) + "\n" for key, row in rows.items()
    )


def clock(x=0, platform=True):
    row = dict(feetPosition=dict(x=x, y=0, z=0), render=False,
               behavior="scripts/probe-tick.js", state=dict(ticks=0), tags=["probe-clock"])
    if platform:
        row["simulatedBy"] = "platform"
    return row


def prepare(target):
    cfg = json.loads((ROOT / "configs/spawn_account_probe.json").read_text())
    assets = json.loads((ROOT / "configs/spawn_merge_assets.json").read_text())
    # copytree refuses an existing directory, including live/check-out directories.
    shutil.copytree(PORT / "world", target)
    fixture = PORT / cfg["fixtureDirectory"]
    for name in ("probe-player.js", "probe-reward.js", "probe-tick.js"):
        shutil.copy2(fixture / name, target / "scripts" / name)
    world = json.loads((target / "world.config.yaml").read_text())
    for name, key in dict(probeFarm="1", probeMain="2", probeEphemeral="3", probeReward="4").items():
        world["inputs"]["actions"][name] = dict(keys=[key])
    (target / "world.config.yaml").write_text(json.dumps(world, indent=2))
    player = target / "templates/player.js"
    text = player.read_text().replace('"scripts/merge-input.js"', '"scripts/merge-input.js", "scripts/probe-player.js"')
    player.write_text(text.replace('"merge"\n  ]', '"merge", "hhAccountProbe"\n  ]'))
    ui = target / "scripts/ui.js"
    text = ui.read_text()
    anchor = '  return html + `<div class="hint">'
    assert anchor in text
    ui.write_text(text.replace(anchor, (fixture / "hud.fragment.js").read_text() + anchor))
    main = target / "places/main/cells/x0z0.scene"
    main.write_text(main.read_text() + "\n" + scene({"probe-main-clock": clock()}))
    distance = cfg["farDistance"]
    far = {
        "probe-far-model": dict(feetPosition=dict(x=distance, y=0, z=0), model=assets["eggs"][cfg["farEgg"]]["url"], tags=["probe-far-model"]),
        "probe-far-clock": clock(distance, False),
        "probe-far-platform-clock": clock(distance),
        "probe-far-floor": dict(feetPosition=dict(x=distance, y=-.1, z=0), primitive=dict(kind="box", width=40, height=.2, depth=40), physics="static", material=dict(color="#596a7f")),
    }
    cell = f"x{distance // 128}z0"
    (main.parent / (cell + ".scene")).write_text(scene(far, cell))
    rows = {"probe-floor": dict(feetPosition=dict(x=0, y=-.1, z=-8), primitive=dict(kind="box", width=50, height=.2, depth=50), physics="static", material=dict(color="#335544"))}
    for i, egg in enumerate(cfg["coldEggs"]):
        rows[f"probe-cold-{i}"] = dict(feetPosition=dict(x=(i % 6 - 2.5) * 3, y=0, z=-6 - i // 6 * 4), model=assets["eggs"][egg]["url"], tags=["probe-cold-model"])
    for i in range(cfg["primitiveCount"]):
        rows[f"probe-box-{i}"] = dict(feetPosition=dict(x=(i % 24 - 12) * 1.4, y=i // 192 * .9, z=-14 - (i // 24 % 8) * 2.5), primitive=dict(kind="box", width=.5, height=.5, depth=.5), material=dict(color="#7d8faa"))
    rows["probe-farm-clock"] = clock()
    rows["probe-reward"] = dict(feetPosition=dict(x=0, y=2, z=-3), pivot="center", rotation=dict(yaw=180), primitive=dict(kind="box", width=4, height=2, depth=.1), material=dict(color="#11283a"), simulatedBy="platform", behavior="scripts/probe-reward.js")
    for ephemeral in (False, True):
        directory = target / "places" / ("farm_ephemeral_probe" if ephemeral else cfg["place"])
        (directory / "cells").mkdir(parents=True)
        config = dict(mode="3d", terrain=dict(kind="none"), gravity=dict(x=0, y=-24, z=0), defaultSpawnPoint=dict(x=0, y=.5, z=0), pregenerate=False, persistence="ephemeral" if ephemeral else "session")
        if ephemeral:
            config["instance"] = "solo"
        (directory / "config.yaml").write_text(json.dumps(config, indent=2))
        (directory / "cells/x0z0.scene").write_text(scene(rows))
    print("Created isolated account probe:", target)


if __name__ == "__main__":
    prepare(Path(sys.argv[1]).resolve())
