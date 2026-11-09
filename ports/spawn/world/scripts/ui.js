import DATA from "./lib/data/merge.yml";
import UI from "./lib/data/ui.yml";
import { eggPrice, formatMoney } from "./lib/merge-core.js";
import { mountEggDrag } from "./ui-egg-drag.js";
let serial = 0,
  disposeDrag;
function send(request) {
  sendAction("command", { ...request, nonce: `${Date.now()}-${++serial}` });
}
export function act(kind, from = -1, slot = -1) {
  send({ kind, from, slot });
}
export function select(index) {
  sendAction("select", { index });
}
export function board() {
  sendAction("board");
}
export function onMount(container) {
  disposeDrag?.();
  disposeDrag = mountEggDrag(container, {
    config: UI.drag,
    colors: DATA.tiers.map((t) => t.color),
    maxTier: DATA.tiers.length,
    sendDrop: send,
    selectEgg: select,
    dragState: (slot) => sendAction("dragState", { slot }),
  });
}
export function onDestroy() {
  disposeDrag?.();
  disposeDrag = null;
}
const escape = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const number = (value) => formatMoney(DATA, value);
const button = (
  text,
  action,
  enabled = true,
  cls = "",
  id = "",
  attributes = "",
) =>
  `<button ${id ? `id="${id}"` : ""} class="${cls}" ${enabled ? "" : "disabled"} ${attributes} onclick="${action}">${text}</button>`;
const targetAttrs = (kind, slot, tier) =>
  `data-egg-target="${kind}" data-target-slot="${slot}" data-target-tier="${tier}"`;
const eggAttrs = (slot, tier) =>
  `${targetAttrs("board", slot, tier)} ${tier ? `data-egg-source="${slot}" data-source-tier="${tier}" title="${escape(DATA.tiers[tier - 1]?.name)}"` : ""}`;
const dimensions = (width, height) =>
  `style="--egg-hit-width:${width};--egg-hit-height:${height};--egg-projection:${UI.drag.projectionFactor}"`;
export default function render(ctx, player) {
  const s = player.state.merge,
    bay = ctx.world.state.mergeBay ?? {},
    selected = player.state.mergeSelected ?? -1;
  if (!s?.version)
    return `<style>${UI.style}</style><div id="hh">${UI.preparing}</div>`;
  const mine = bay.owner === player.userId,
    fighting = s.status === "fighting",
    scene = DATA.tuning.scene,
    pos = player.feetPosition;
  const near = (point) =>
    Math.hypot(pos.x - point.x, pos.z - point.z) <
    DATA.tuning.interaction.promptRange;
  let html = `<style>${UI.style}</style><div id="hh" data-mine="${mine}" data-fighting="${fighting}"><div class="brand">${UI.brand}<small>${UI.subtitle}</small></div><div class="wave">${UI.wave} ${mine && fighting ? bay.wave : s.clearedWave}<small>${s.reserve} ${UI.reserve}${mine && fighting ? " · " + bay.enemies : ""}</small></div><div class="coins"><div class="amount">${number(s.coins)}<small>${UI.coins}</small></div>${mine && s.uncollected ? button(`${UI.collect} +${number(s.uncollected)}`, "act('collect')", true, "mint") : ""}</div>`;
  if (!mine) {
    html += `<div class="claim">${button(bay.owner ? UI.occupied : UI.claim, "act('claim')", !bay.owner, "gold")}<p>${bay.owner ? escape(bay.ownerName) + " " + UI.watching : UI.welcome}</p></div>`;
  } else {
    html += `<div class="squad"><h3>${UI.squad}</h3>${s.deployed.map((tier, i) => button(`<b>${tier ? "T" + tier : "+"}</b><span>${UI.hatcher} ${i + 1}<small>${tier ? escape(DATA.tiers[tier - 1].name) + " · " + DATA.petsPerHatcher[tier - 1] + " " + UI.pets : UI.empty}</small></span>`, tier ? `act('recall',-1,${i})` : `act('deploy',${selected},${i})`, !fighting, "", `hatcher-card-${i}`, targetAttrs("hatcher", i, tier))).join("")}${s.generator < DATA.tiers.length ? button(`${UI.upgrade} T${s.generator + 1} · ${escape(DATA.tiers[s.generator].name)} · ${number(eggPrice(DATA, s.generator + 1) * DATA.tuning.hatcherCount * DATA.economy.upgradeMultiplier)}`, "act('upgrade')", !fighting) : ""}</div>`;
    html += `<div class="dock">${button(UI.board, "board()")}${button(`${UI.buy} · ${number(eggPrice(DATA, s.generator))}`, "act('buy')", s.coins >= eggPrice(DATA, s.generator), "", "buy-egg")}${button(UI.merge, `act('merge',${selected})`, s.board[selected] > 0, "", "merge-pair")}${button(s.status === "complete" ? UI.complete : fighting ? UI.fighting : s.status === "lost" ? UI.restart : UI.start + " " + (s.clearedWave + 1), s.status === "lost" ? "act('restart')" : "act('start')", !fighting && s.status !== "complete", "gold start", "start-wave")}</div>`;
    html += `<div class="status ${player.state.mergeNotice ? "notice" : ""}">${escape(player.state.mergeNotice || s.message)}</div>`;
    if (player.state.mergeBoardOpen)
      html += `<section class="board"><header>${UI.board}${button(UI.close, "board()")}</header><div class="cells">${s.board.map((tier, i) => button(tier ? "T" + tier : "·", `select(${i})`, true, `cell ${selected === i ? "selected" : ""}`, `egg-${i}`, eggAttrs(i, tier))).join("")}</div><footer>${UI.boardHint}</footer></section>`;
    for (let i = 0; i < scene.board.length; i++) {
      const tier = s.board[i];
      if (!near(scene.board[i])) continue;
      const offset = tier ? scene.eggRadius * 1.2 : 0;
      html += `<div data-world-anchor="hh-board-slot-${i}" data-anchor-offset="0 ${offset} 0">${button(tier ? `<span class="egg-tier">T${tier}</span>` : "", `select(${i})`, true, `egg-hit ${tier ? "egg-pickup" : "egg-empty"} ${selected === i ? "egg-selected" : ""}`, `world-egg-${i}`, `${eggAttrs(i, tier)} ${dimensions(tier ? UI.drag.eggWidth : UI.drag.emptyCellWidth, tier ? UI.drag.eggHeight : UI.drag.emptyCellHeight)} aria-label="${UI.board} ${i + 1}${tier ? " T" + tier : ""}"`)}</div>`;
    }
    for (let i = 0; i < scene.hatcherX.length; i++) {
      const tier = s.deployed[i],
        p = { x: scene.hatcherX[i], z: scene.hatcherZ };
      const center = tier
        ? scene.eggStandHeight + scene.eggRadius * 1.15
        : scene.eggStandHeight / 2;
      const label = `${UI.hatcher} ${i + 1} · ${tier ? "T" + tier : s.board[selected] ? UI.deploy + " T" + s.board[selected] : UI.empty}`;
      html += `<div data-world-anchor="hh-hatcher-${i}" data-anchor-offset="0 ${center - 1.1} 0">${button(`<span class="stand-label ${near(p) ? "" : "stand-distant"}">${near(p) ? label : UI.hatcher + " " + (i + 1)}</span>`, tier ? `act('recall',-1,${i})` : `act('deploy',${selected},${i})`, !fighting, "egg-hit hatcher-drop", `world-hatcher-${i}`, `${targetAttrs("hatcher", i, tier)} ${dimensions(UI.drag.standWidth, UI.drag.standHeight)} aria-label="${label}"`)}</div>`;
    }
  }
  for (const enemy of [
    ...ctx.query({ tags: ["hh-enemy"] }),
    ...ctx.query({ tags: ["hh-pet"] }),
  ])
    if (enemy.visible !== false && enemy.state.maxHp > 0)
      html += `<div data-world-anchor="${enemy.id}" data-anchor-offset="0 1.8 0"><div class="health"><i style="width:${Math.max(0, (100 * enemy.state.hp) / enemy.state.maxHp)}%"></i></div></div>`;
  for (const hit of ctx.query({ tags: ["hh-combat-text"] })) {
    const v = hit.state,
      rounded = Math.round(v.amount),
      label =
        Math.abs(v.amount - rounded) < 0.05
          ? String(rounded)
          : v.amount.toFixed(1);
    html += `<div data-world-anchor="${hit.id}"><div id="number-${hit.id}" class="hh-combat-number" style="--damage-color:${v.color};--damage-size:${v.size}px;--damage-duration:${v.duration}s;--damage-rise:${v.rise}">${label}</div></div>`;
  }
  return html + `<div class="hint">${UI.controls}</div></div>`;
}
