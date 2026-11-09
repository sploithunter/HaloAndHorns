import DATA from './lib/data/merge.yml';
import UI from './lib/data/ui.yml';
import { eggPrice } from './lib/merge-core.js';
let serial = 0;
export function act(kind, from = -1, slot = -1) { sendAction('command', { kind, from, slot, nonce: `${Date.now()}-${++serial}` }); }
export function select(index) { sendAction('select', { index }); }
export function board() { sendAction('board'); }
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' })[c]);
const number = value => Math.floor(value ?? 0).toLocaleString('en-US');
const button = (text, action, enabled = true, cls = '', id = '') => `<button ${id ? `id="${id}"` : ''} class="${cls}" ${enabled ? '' : 'disabled'} onclick="${action}">${text}</button>`;
export default function render(ctx, player) {
  const s = player.state.merge, bay = ctx.world.state.mergeBay ?? {}, selected = player.state.mergeSelected ?? -1;
  if (!s?.version) return `<style>${UI.style}</style><div id="hh">${UI.preparing}</div>`;
  const mine = bay.owner === player.userId, fighting = s.status === 'fighting', scene = DATA.tuning.scene, pos = player.feetPosition;
  const near = point => Math.hypot(pos.x - point.x, pos.z - point.z) < DATA.tuning.interaction.promptRange;
  let html = `<style>${UI.style}</style><div id="hh"><div class="brand">${UI.brand}<small>${UI.subtitle}</small></div><div class="wave">${UI.wave} ${mine && fighting ? bay.wave : s.clearedWave}<small>${s.reserve} ${UI.reserve}${mine && fighting ? ' · '+bay.enemies : ''}</small></div><div class="coins"><div class="amount">${number(s.coins)}<small>${UI.coins}</small></div>${mine && s.uncollected ? button(`${UI.collect} +${number(s.uncollected)}`,"act('collect')",true,'mint') : ''}</div>`;
  if (!mine) {
    html += `<div class="claim">${button(bay.owner ? UI.occupied : UI.claim,"act('claim')",!bay.owner,'gold')}<p>${bay.owner ? escape(bay.ownerName)+' '+UI.watching : UI.welcome}</p></div>`;
  } else {
    html += `<div class="squad"><h3>${UI.squad}</h3>${s.deployed.map((tier,i) => button(`<b>${tier ? 'T'+tier : '+'}</b><span>${UI.hatcher} ${i+1}<small>${tier ? DATA.petsPerHatcher[tier-1]+' '+UI.pets : UI.empty}</small></span>`,tier ? `act('recall',-1,${i})` : `act('deploy',${selected},${i})`,!fighting && (!!tier || s.board[selected]>0))).join('')}${s.generator<DATA.tuning.tiers.length ? button(`${UI.upgrade} T${s.generator+1} · ${number(eggPrice(DATA,s.generator+1)*DATA.tuning.hatcherCount*DATA.economy.upgradeMultiplier)}`,"act('upgrade')",!fighting) : ''}</div>`;
    html += `<div class="dock">${button(UI.board,'board()')}${button(`${UI.buy} · ${number(eggPrice(DATA,s.generator))}`,"act('buy')",s.coins>=eggPrice(DATA,s.generator),'', 'buy-egg')}${button(UI.merge,`act('merge',${selected})`,s.board[selected]>0,'','merge-pair')}${button(s.status==='complete' ? UI.complete : fighting ? UI.fighting : s.status==='lost' ? UI.restart : UI.start+' '+(s.clearedWave+1),s.status==='lost' ? "act('restart')" : "act('start')",!fighting && s.status!=='complete','gold start','start-wave')}</div>`;
    html += `<div class="status ${player.state.mergeNotice ? 'notice' : ''}">${escape(player.state.mergeNotice || s.message)}</div>`;
    if (player.state.mergeBoardOpen) html += `<section class="board"><header>${UI.board}${button(UI.close,'board()')}</header><div class="cells">${s.board.map((tier,i) => button(tier ? 'T'+tier : '·',`select(${i})`,true,`cell ${selected===i ? 'selected' : ''}`,`egg-${i}`)).join('')}</div><footer>${UI.boardHint}</footer></section>`;
    for (let i=0;i<scene.board.length;i++) if (s.board[i] && near(scene.board[i])) html += `<div data-world-anchor="hh-board-slot-${i}" data-anchor-offset="0 1 0">${button(s.board[i] ? 'T'+s.board[i] : '·',`select(${i})`,true,`world-cell ${selected===i ? 'selected' : ''}`)}</div>`;
    for (let i=0;i<scene.hatcherX.length;i++) {
      const p = {x:scene.hatcherX[i],z:scene.hatcherZ};
      if (near(p)) html += `<div data-world-anchor="hh-hatcher-${i}" data-anchor-offset="0 1 0">${button(`<b>${UI.hatcher} ${i+1}</b> · ${s.deployed[i] ? 'T'+s.deployed[i] : s.board[selected] ? UI.deploy+' T'+s.board[selected] : UI.empty}`,s.deployed[i] ? `act('recall',-1,${i})` : `act('deploy',${selected},${i})`,!fighting && (!!s.deployed[i] || s.board[selected]>0),'world-button')}</div>`;
    }
  }
  for (const enemy of ctx.query({tags:['hh-enemy']})) if (enemy.state.maxHp>0) html += `<div data-world-anchor="${enemy.id}" data-anchor-offset="0 1.8 0"><div class="health"><i style="width:${Math.max(0,100*enemy.state.hp/enemy.state.maxHp)}%"></i></div></div>`;
  return html+`<div class="hint">${UI.controls}</div></div>`;
}
