import DATA from "./lib/data/merge.yml";
import UI from "./lib/data/ui.yml";
import { eggPrice, formatMoney } from "./lib/merge-core.js";

export const updateSchedule = {
  every: { seconds: DATA.tuning.simulation.step },
};
const escape = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
export function update(ctx) {
  const owner = ctx.world.players.find(
      (p) => p.userId === ctx.world.state.mergeBay?.owner,
    ),
    s = owner?.state.merge;
  const copy = UI.upgradeBoard,
    tier = s?.generator ?? 1,
    current = DATA.tiers[tier - 1],
    next = DATA.tiers[tier];
  const buyCost = eggPrice(DATA, tier),
    upgradeCost = next
      ? eggPrice(DATA, tier + 1) *
        DATA.tuning.hatcherCount *
        DATA.economy.upgradeMultiplier
      : 0;
  const idle = Boolean(s) && s.status !== "fighting",
    canBuy = s && s.coins >= buyCost && s.board.some((t) => !t),
    canUpgrade = idle && next && s.coins >= upgradeCost;
  const money = (n) => formatMoney(DATA, n),
    width =
      DATA.managementBoard.size.x *
      DATA.tuning.scene.sourceTransform.metersPerStud;
  ctx.self.ui = `<div face="front" width="${width.toFixed(2)}m" class="hh-upgrade-surface" id="hh-wall-upgrade-board"><style>${copy.style}</style>
    <header><h1>${copy.title}</h1><div class="bay-owner">${copy.owner}<b>${escape(owner?.displayName ?? "—")}</b></div></header>
    <main><button id="wall-buy-egg" ${canBuy ? "" : "disabled"}><b class="action-title">${copy.buy}</b><div><div class="egg-tier">${copy.tier} ${tier}</div><b class="egg-name">${escape(current.name)}</b><div class="details">${current.positions} ${copy.pets}</div></div><div class="price">${money(buyCost)}<small>${copy.coins}</small></div></button>
    <button id="wall-upgrade-generator" class="spawn-upgrade" ${canUpgrade ? "" : "disabled"}><b class="action-title">${copy.upgrade}</b><div><div class="egg-tier">${copy.tier} ${tier}${next ? " → " + (tier + 1) : ""}</div><b class="egg-name">${escape(next?.name ?? copy.maximum)}</b><div class="details">${next ? copy.cost + " · " + money(eggPrice(DATA, tier + 1)) + " " + copy.coins : copy.maximum}</div></div><div class="price">${next ? money(upgradeCost) : "—"}<small>${copy.coins}</small></div></button></main>
    <footer>${!s ? copy.claim : s.status === "fighting" ? copy.betweenWaves : copy.current + " · T" + tier + " " + escape(current.name)}</footer>
  </div>`;
}

function press(ctx, kind, { by }, meta) {
  const player = ctx.world.players.find((p) => p.id === by);
  if (!player || (meta?.sourceId && meta.sourceId !== by)) return;
  const serial = (ctx.self.session.pressSerial =
    (ctx.self.session.pressSerial ?? 0) + 1);
  ctx.emit(
    "hh:wall-command",
    { kind, nonce: `wall-${ctx.now()}-${serial}` },
    { to: by },
  );
}
export const ears = {
  "ui:wall-buy-egg": (ctx, data, meta) => press(ctx, "buy", data, meta),
  "ui:wall-upgrade-generator": (ctx, data, meta) =>
    press(ctx, "upgrade", data, meta),
};
