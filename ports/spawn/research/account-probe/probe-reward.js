// Isolated assessment fixture: artificial account and reward, never production gameplay.
import { replaceEquipped } from "./lib/pet-inventory.js";
export function onSpawn(ctx) {
  ctx.self.ui =
    '<div face="front" width="4m" style="width:1000px;height:500px;background:#11283a;padding:50px;color:white"><h1>ACCOUNT CONTINUITY TEST</h1><button id="probe-reward" style="font-size:60px;padding:30px">Farm test reward</button></div>';
}
export const ears = {
  "ui:probe-reward": (ctx, { by }, meta) => {
    const p = ctx.getObject(by);
    if (
      !p ||
      !p.state.hhAccountProbe ||
      (meta?.sourceId && meta.sourceId !== by)
    )
      return;
    const a = JSON.parse(JSON.stringify(p.state.hhAccountProbe));
    if (a.Receipts.normal_browser_reward) return;
    a.Inventory.pets.items["bear:basic:"].quantity++;
    a.Stats.Experience += 17;
    a.Receipts.normal_browser_reward = true;
    const result = replaceEquipped(
      a,
      ["probe-unique", "stack|bear:basic:", "stack|bear:basic:"],
      3,
    );
    if (result.ok) p.state.hhAccountProbe = result.account;
  },
};
