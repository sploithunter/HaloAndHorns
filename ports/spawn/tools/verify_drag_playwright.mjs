// Real mouse/touch regression in a dedicated test player's isolated room. Prepare a claimed
// bay with four T1 board eggs and 200 coins (collect 600, buy four). Refuse other starting states.
import assert from 'node:assert/strict';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const endpoint = process.argv[2];
if (!endpoint) throw new Error('Usage: node tools/verify_drag_playwright.mjs <CDP URL>');
const browser = await chromium.connectOverCDP(endpoint);
try {
  const page = browser.contexts()[0].pages()[0];
  page.setDefaultTimeout(8000);
  let hud;
  for (const frame of page.frames()) if (await frame.locator('#hh[data-mine="true"]').count()) { hud=frame; break; }
  assert.ok(hud, 'Claim a fresh bay in an isolated test room first');
  const tier = async id => Number(await hud.locator(id).getAttribute('data-target-tier'));
  const waitTier = (id, value) => hud.waitForFunction(({id,value}) => Number(document.querySelector(id)?.dataset.targetTier) === value, {id,value});
  for(let i=0;i<16;i++) assert.equal(await tier('#world-egg-'+i),i<4?1:0,'Expected exactly four initial T1 eggs');
  for(let i=0;i<4;i++) assert.equal(await tier('#world-hatcher-'+i),0,'Expected empty hatchers');
  const center=async id=>{const r=await hud.locator(id).boundingBox();assert.ok(r,id+' must be visible');return{x:r.x+r.width/2,y:r.y+r.height/2};};
  const ghostVisible=()=>hud.locator('.hh-drag-ghost').isVisible();
  async function mouse(from,to,value) {
    const a=await center(from),b=await center(to);
    await page.mouse.move(a.x,a.y);await page.mouse.down();await page.mouse.move(b.x,b.y,{steps:20});
    assert.ok(await ghostVisible());await page.mouse.up();
    if(value!==undefined)await waitTier(to,value);
    await page.waitForTimeout(200);
  }
  await mouse('#world-egg-0','#world-egg-1',2);
  await mouse('#world-egg-1','#world-egg-2');
  assert.equal(await tier('#world-egg-1'),2);assert.equal(await tier('#world-egg-2'),1);
  await mouse('#world-egg-3','#world-egg-2',2);
  await mouse('#world-egg-1','#world-hatcher-0',2);
  await mouse('#world-egg-2','#world-hatcher-0',3);
  await hud.locator('#buy-egg').click();await waitTier('#world-egg-0',1);
  await hud.locator('#buy-egg').click();await waitTier('#world-egg-1',1);
  await hud.getByRole('button',{name:'Egg board',exact:true}).click();
  await mouse('#egg-0','#world-hatcher-1',1);
  await hud.locator('.board header button').click();
  const cdp=await page.context().newCDPSession(page);
  async function touch(from,to,cancel=false) {
    const a=await center(from),b=typeof to==='string'?await center(to):to;
    const point=(x,y)=>({x,y,id:1,radiusX:2,radiusY:2,force:1});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point(a.x,a.y)]});
    for(let i=1;i<=10;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[point(a.x+(b.x-a.x)*i/10,a.y+(b.y-a.y)*i/10)]});
    assert.ok(await ghostVisible());
    await cdp.send('Input.dispatchTouchEvent',{type:cancel?'touchCancel':'touchEnd',touchPoints:[]});
  }
  await touch('#world-egg-1','#world-hatcher-1');await waitTier('#world-hatcher-1',2);
  await hud.locator('#hatcher-card-1').click();await waitTier('#world-egg-0',2);
  await touch('#world-egg-0',{x:200,y:100},true);assert.equal(await tier('#world-egg-0'),2);assert.equal(await ghostVisible(),false);
  const a=await center('#world-egg-0');await page.mouse.move(a.x,a.y);await page.mouse.down();await page.mouse.move(200,100,{steps:20});
  await page.keyboard.press('Escape');await page.mouse.up();assert.equal(await tier('#world-egg-0'),2);assert.equal(await ghostVisible(),false);
  console.log('PASS: world/panel drag, board/stand stacking, wrong-tier rejection, touch and cancellation');
} finally { await browser.close(); }
