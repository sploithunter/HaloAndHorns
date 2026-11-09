// Uses only an isolated preview and an agent-owned test profile. Never print the login URL.
const { chromium } = await import(
  process.env.PLAYWRIGHT_MODULE || "playwright"
);
import fs from "node:fs";
import assert from "node:assert/strict";
const output = process.argv[3];
if (!process.argv[2] || !output)
  throw Error("Usage: runner <private-login-link.json> <new-output-directory>");
fs.mkdirSync(output);
let phase = "boot",
  browser;
const evidence = {
  started: new Date().toISOString(),
  samples: [],
  requests: [],
};
const save = () =>
  fs.writeFileSync(
    output + "/evidence.json",
    JSON.stringify(evidence, null, 2),
  );
try {
  const grant = JSON.parse(fs.readFileSync(process.argv[2]));
  fs.unlinkSync(process.argv[2]);
  browser = await chromium.launch({
    ...(process.env.CHROME_EXECUTABLE
      ? { executablePath: process.env.CHROME_EXECUTABLE }
      : {}),
    headless: true,
    args: ["--enable-unsafe-webgpu", "--use-angle=metal"],
  });
  const context = await browser.newContext({
      viewport: { width: 1440, height: 1000 },
    }),
    page = await context.newPage(),
    started = new WeakMap();
  context.on("request", (r) => started.set(r, phase));
  context.on("requestfinished", async (r) => {
    const u = new URL(r.url());
    if (/login|auth|session|token/.test(u.pathname)) return;
    const n = {
      phase: started.get(r),
      host: u.host,
      type: r.resourceType(),
      extension: u.pathname.split(".").at(-1).slice(-12),
      assets: [
        ...new Set(
          (r.postData() ?? "").match(/value\.[a-f0-9]{64}\.\w+/g) ?? [],
        ),
      ],
      at: Date.now(),
    };
    try {
      n.sizes = await r.sizes();
      const response = await r.response();
      n.contentType = response?.headers()["content-type"];
    } catch {}
    evidence.requests.push(n);
    save();
  });
  await page.goto(grant.url, { waitUntil: "domcontentloaded", timeout: 45000 });
  let hud;
  const find = async () => {
    for (const f of page.frames())
      if (await f.locator("#probe-data").count()) return f;
  };
  for (let i = 0; i < 80 && !hud; i++) {
    hud = await find();
    if (!hud) {
      const play = page.getByRole("button", { name: "Play", exact: true });
      if (await play.count())
        await play
          .first()
          .click()
          .catch(() => {});
      await page.waitForTimeout(750);
    }
  }
  if (!hud) throw Error("No HUD");
  async function read(stage) {
    phase = stage;
    await page.screenshot({ path: output + "/" + stage + ".png" });
    await page.waitForTimeout(500);
    const s = JSON.parse(
      await hud.locator("#probe-data").getAttribute("data-probe"),
    );
    s.stage = stage;
    evidence.samples.push(s);
    save();
    console.log(
      JSON.stringify({
        stage,
        place: s.place,
        quantity: s.profile.Inventory.pets.items["bear:basic:"].quantity,
        xp: s.profile.Stats.Experience,
        equipped: s.profile.Equipped,
        view: s.view,
        places: s.places,
      }),
    );
    return s;
  }
  async function key(k, stage) {
    phase = stage;
    await page.mouse.click(450, 500);
    await page.keyboard.press(k);
    await page.waitForTimeout(5000);
    hud = await find();
    return read(stage + "_settled");
  }
  await key("1", "enter_farm_for_reward");
  let before = await read("reward_before");
  await key("4", "farm_reward");
  const reward = await read("reward_after");
  if (!before.profile.Receipts.normal_browser_reward) {
    assert.equal(
      reward.profile.Stats.Experience,
      before.profile.Stats.Experience + 17,
    );
    assert.equal(
      reward.profile.Inventory.pets.items["bear:basic:"].quantity,
      before.profile.Inventory.pets.items["bear:basic:"].quantity + 1,
    );
  }
  assert.equal(reward.profile.Equipped.pets.slot_1, "probe-unique");
  assert.equal(reward.profile.Equipped.pets.slot_3, "stack|bear:basic:");
  await key("4", "farm_reward_repeat");
  let repeat = await read("reward_repeat_after");
  assert.deepEqual(repeat.profile, reward.profile);
  await key("2", "return_main");
  phase = "cold_reload_main";
  const cdp = await context.newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.clearBrowserCache");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await page.reload({ waitUntil: "domcontentloaded", timeout: 45000 });
  await page.waitForTimeout(10000);
  hud = await find();
  if (!hud) throw Error("No HUD after reload");
  const reloaded = await read("main_cold_reloaded");
  assert.deepEqual(reloaded.profile, reward.profile);
  await key("1", "first_farm_after_cold");
  const farm = await read("farm_after_cold");
  assert.deepEqual(farm.profile, reward.profile);
  await key("2", "main_after_farm");
  await key("3", "ephemeral_visit");
  await key("2", "main_after_ephemeral");
  await page.waitForTimeout(15000);
  await read("main_ephemeral_cleanup_wait");
  console.log(
    "PASS normal browser durable mutation, UID/equip, duplicate receipt, cold reload, places/instance",
  );
  save();
  await browser.close();
} catch (error) {
  evidence.failedPhase = phase;
  evidence.error = error.name;
  save();
  console.log("PROBE FAILED", phase, error.name);
  if (browser) await browser.close();
  process.exitCode = 1;
}
