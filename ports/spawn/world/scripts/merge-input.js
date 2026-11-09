import DATA from "./lib/data/merge.yml";
export function onInput(ctx, input) {
  if (input.pressed.select) {
    const index = input.actionData?.select?.index;
    if (Number.isInteger(index) && index >= 0 && index < DATA.tuning.boardSlots)
      ctx.self.state.mergeSelected = index;
  }
  if (input.pressed.board)
    ctx.self.state.mergeBoardOpen = !ctx.self.state.mergeBoardOpen;
  if (input.pressed.dragState) {
    const slot = input.actionData?.dragState?.slot;
    ctx.self.faded =
      Number.isInteger(slot) && slot >= 0 && slot < DATA.tuning.boardSlots
        ? {
            [`hh-board-egg-${slot}`]: DATA.tuning.interaction.dragSourceOpacity,
          }
        : {};
  }
  if (input.pressed.command) {
    const request = input.actionData?.command;
    if (request && typeof request.kind === "string")
      ctx.emit("hh:command", request, { to: "hh-director" });
  }
}

export function update(ctx) {
  // One development-scene migration; durable coins and eggs are preserved.
  if (ctx.self.state.mergeSceneVersion !== DATA.tuning.scene.sceneVersion) {
    ctx.self.feetPosition = DATA.tuning.scene.spawn;
    ctx.self.state.mergeSceneVersion = DATA.tuning.scene.sceneVersion;
  }
}

export const ears = {
  "hh:wall-command": (ctx, request, meta) => {
    if (meta.sourceId !== "hh-upgrade-board") return;
    ctx.emit(
      "hh:command",
      { ...request, station: "upgrade-board" },
      { to: "hh-director" },
    );
  },
};
