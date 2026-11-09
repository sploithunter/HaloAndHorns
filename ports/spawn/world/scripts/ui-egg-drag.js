// Page-only pointer controller. State and captured pointers live outside the render tree so a
// reactive HUD update cannot lose a held egg. No economy mutation occurs before a validated drop.
export function mountEggDrag(container, options) {
  const { config, colors, maxTier, sendDrop, selectEgg, dragState } = options;
  const doc = container.ownerDocument, win = doc.defaultView;
  let drag = null, suppressClick = false, highlighted = null;
  const ghost = doc.createElement('div');
  ghost.className = 'hh-drag-ghost'; ghost.hidden = true;
  ghost.innerHTML = '<div class="hh-drag-egg"><span></span></div><div class="hh-drag-message"></div>';
  container.appendChild(ghost);
  const tierLabel = ghost.querySelector('span'), message = ghost.querySelector('.hh-drag-message');
  const word = (name, tier) => config[name].replace('{tier}', String(tier));
  const root = () => doc.getElementById('hh');
  function hit(x, y) {
    return doc.elementsFromPoint(x, y).map(e => e.closest('[data-egg-target]')).find(Boolean) ?? null;
  }
  function verdict(target) {
    if (!target || !drag || root()?.dataset.mine !== 'true') return { valid: false, text: config.invalid };
    const kind = target.dataset.eggTarget, slot = Number(target.dataset.targetSlot), tier = Number(target.dataset.targetTier);
    if (kind === 'board' && slot === drag.from) return { valid: false, text: config.self };
    if (kind === 'hatcher' && root()?.dataset.fighting === 'true') return { valid: false, text: config.combat };
    if (tier && (tier !== drag.tier || tier >= maxTier)) return { valid: false, text: config.invalid };
    return { valid: true, text: word(tier ? 'merge' : kind === 'hatcher' ? 'install' : 'move', tier ? tier + 1 : drag.tier) };
  }
  function unmark() {
    if (highlighted) delete highlighted.dataset.dropHover;
    highlighted = null;
  }
  function paint(event) {
    ghost.style.left = event.clientX + 'px'; ghost.style.top = event.clientY + 'px';
    unmark(); highlighted = hit(event.clientX, event.clientY);
    const result = verdict(highlighted);
    if (highlighted) highlighted.dataset.dropHover = result.valid ? 'valid' : 'invalid';
    ghost.dataset.valid = String(result.valid); message.textContent = result.text;
  }
  function clear() {
    if (!drag) return;
    const pointerId = drag.pointerId, active = drag.active;
    drag = null; unmark(); ghost.hidden = true;
    doc.body.classList.remove('hh-egg-dragging');
    if (container.hasPointerCapture(pointerId)) container.releasePointerCapture(pointerId);
    if (active) { suppressClick = true; win.setTimeout(() => { suppressClick = false; }, 0); dragState(-1); }
  }
  function down(event) {
    if (drag) { if (event.pointerId !== drag.pointerId) clear(); return; }
    if (event.button !== 0 || root()?.dataset.mine !== 'true') return;
    const source = event.target.closest?.('[data-egg-source]');
    if (!source || Number(source.dataset.sourceTier) <= 0) return;
    event.preventDefault();
    drag = { from: Number(source.dataset.eggSource), tier: Number(source.dataset.sourceTier), pointerId: event.pointerId, x: event.clientX, y: event.clientY, active: false };
    container.setPointerCapture(event.pointerId);
  }
  function move(event) {
    if (!drag || event.pointerId !== drag.pointerId) return;
    if (root()?.dataset.mine !== 'true') { clear(); return; }
    if (!drag.active && Math.hypot(event.clientX - drag.x, event.clientY - drag.y) >= config.thresholdPixels) {
      drag.active = true; ghost.hidden = false;
      ghost.style.setProperty('--egg-color', colors[drag.tier - 1]);
      tierLabel.textContent = word('tierLabel', drag.tier);
      doc.body.classList.add('hh-egg-dragging'); dragState(drag.from);
    }
    if (drag.active) { event.preventDefault(); paint(event); }
  }
  function up(event) {
    if (!drag || event.pointerId !== drag.pointerId) return;
    if (!drag.active) { const from = drag.from; clear(); selectEgg(from); return; }
    event.preventDefault();
    const target = hit(event.clientX, event.clientY), result = verdict(target);
    if (result.valid) sendDrop({ kind: 'drop', from: drag.from, expectedTier: drag.tier, targetKind: target.dataset.eggTarget, targetSlot: Number(target.dataset.targetSlot), expectedTargetTier: Number(target.dataset.targetTier) });
    clear();
  }
  function cancel(event) { if (!event?.pointerId || event.pointerId === drag?.pointerId) clear(); }
  function click(event) {
    if (suppressClick) { suppressClick = false; event.preventDefault(); event.stopImmediatePropagation(); }
  }
  function key(event) { if (event.key === 'Escape') clear(); }
  function visibility() { if (doc.hidden) clear(); }
  const bindings = [[doc,'pointerdown',down],[doc,'pointermove',move],[doc,'pointerup',up],[doc,'pointercancel',cancel],[container,'lostpointercapture',cancel],[doc,'click',click],[doc,'keydown',key],[win,'blur',clear],[doc,'visibilitychange',visibility]];
  for (const [target, name, handler] of bindings) target.addEventListener(name, handler, { capture: true, passive: false });
  return () => { clear(); for (const [target,name,handler] of bindings) target.removeEventListener(name,handler,true); ghost.remove(); };
}
