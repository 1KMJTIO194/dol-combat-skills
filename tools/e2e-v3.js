// e2e v3：真实游戏 + mods 运行时验证（每段 reload 后点 Start Game! 初始化玩家状态）
const fs = require('fs');
const LOG = 'F:\\omgd\\网站\\DOL\\modsrc\\tools\\e2e-v3-log.txt';
const PORT = '9337';
fs.writeFileSync(LOG, '');
const log = (s) => { console.log(s); fs.appendFileSync(LOG, s + '\n'); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const ok = (name, pass, detail = '') => { results.push({ name, pass, detail }); log(`${pass ? 'PASS' : 'FAIL'} | ${name}${detail ? ' | ' + detail : ''}`); };
setTimeout(() => { log('GLOBAL TIMEOUT'); summary(); process.exit(3); }, 420000);

let send, ev, passage, body, clickText, reload;

async function connect() {
  const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
  const page = list.find((t) => t.type === 'page' && t.url.includes('Degrees'));
  if (!page) throw new Error('找不到游戏页面');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await race(new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; }), 15000);
  let id = 0; const pending = new Map();
  ws.onmessage = (e) => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
  send = (method, params = {}) => new Promise((res) => { const mid = ++id; pending.set(mid, res); ws.send(JSON.stringify({ id: mid, method, params })); });
  ev = async (expr, timeoutMs = 15000) => {
    const r = await race(send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true, userGesture: true }), timeoutMs);
    if (r.__timeout) throw new Error('eval timeout: ' + expr.slice(0, 80));
    if (r.result && r.result.exceptionDetails) throw new Error('JS异常: ' + (r.result.exceptionDetails.exception?.description || r.result.exceptionDetails.text));
    return r.result?.result?.value;
  };
  passage = () => ev('State.passage');
  body = () => ev('document.body.innerText');
  clickText = (txt) => ev(`(function(txt){const els=[...document.querySelectorAll('a.link-internal,a,button')];const el=els.find(e=>e.textContent.trim().includes(txt)&&e.offsetParent!==null);if(el){el.click();return el.textContent.trim();}return null;})(${JSON.stringify(txt)})`);
  await send('Page.enable');
  reload = async () => {
    await send('Page.reload', { ignoreCache: true });
    for (let i = 0; i < 90; i++) {
      await sleep(1000);
      try {
        const r = await ev('!!(window.SugarCube && window.SugarCube.Engine && window.State && window.State.passage && window.modUtils && window.modUtils.getModListNameNoAlias().length > 20)', 6000);
        if (r) { await sleep(1500); return true; }
      } catch (e) {}
    }
    throw new Error('页面重载后未就绪');
  };
}
function race(p, ms) { return Promise.race([p, new Promise((res) => setTimeout(() => res({ __timeout: true }), ms))]); }
async function play(p) { await ev(`SugarCube.Engine.play(${JSON.stringify(p)})`); await sleep(1500); }
async function initGame() {
  await clickText('Start Game!');
  for (let i = 0; i < 40; i++) { await sleep(700); const p = await passage(); if (p && p !== 'Start') { await sleep(1000); return p; } }
  return await passage();
}

async function main() {
  await connect();
  for (let i = 0; i < 90; i++) {
    try { if (await ev('!!(window.SugarCube && window.SugarCube.Engine && window.State && window.modUtils)', 5000)) break; } catch (e) {}
    await sleep(1000);
  }
  ok('游戏加载', (await passage()) === 'Start');

  // 段 0：基础
  const mods = await ev('window.modUtils.getModListNameNoAlias()');
  ok('ModLoader mod 数量', mods.length > 20, mods.length + ' 个');
  ok('四个关键 mod', ['CombatSkills', 'CombatActionsExt', 'LocationsExt', 'TweeReplacer'].every((n) => mods.includes(n)));
  const ver = await ev('(function(){try{const m=window.modUtils.getAnyModByNameNoAlias("LocationsExt");const bj=m&&(m.bootJson||m.boot||(m.modInfo&&m.modInfo.bootJson));return bj?bj.version:(m?m.version:"?");}catch(e){return "ERR";}})()');
  ok('LocationsExt 版本 1.6.0', ver === '1.6.0', String(ver));
  ok('探针 & CombatSkills JS 加载', (await ev('typeof window.CombatActionsExtProbe')) === 'function' && (await ev('typeof window.CombatSkills_lootClothes')) === 'function');

  // 初始化游戏（正常开局），验证玩家状态
  await reload();
  let initP = await initGame();
  ok('点 Start Game! 初始化玩家', !!(await ev('State.variables.worn')), 'passage=' + initP);

  // ===== 段 1：High Street → 旅店 → 租房 =====
  await ev('State.variables.money = 9999999');
  await play('High Street');
  ok('High Street 含「旅店」入口', (await body()).includes('旅店'));
  await clickText('旅店'); await sleep(1600);
  ok('进入 Inn', (await passage()) === 'Inn', 'passage=' + (await passage()));
  const clicked = await clickText('租一间房过夜'); await sleep(2000);
  ok('点击租房', clicked !== null, String(clicked));
  ok('进入 Inn Room', (await passage()) === 'Inn Room', 'passage=' + (await passage()));
  ok('扣款 money=9995999', (await ev('State.variables.money')) === 9995999, 'money=' + (await ev('State.variables.money')));
  ok('$caeInnStays=1', (await ev('State.variables.caeInnStays')) === 1);

  // ===== 段 2：浴室 =====
  await clickText('浴室'); await sleep(1800);
  ok('进入 Inn Bathroom', (await passage()) === 'Inn Bathroom', 'passage=' + (await passage()));
  const bathTxt = await body();
  ok('浴室含 泡澡/冲澡/upkeep', /泡个澡/.test(bathTxt) && /冲个澡/.test(bathTxt) && /刷牙|清洁|毛/.test(bathTxt));
  await clickText('泡个澡'); await sleep(2200);
  ok('进入 Inn Bath', (await passage()) === 'Inn Bath', 'passage=' + (await passage()));
  ok('泡澡后 hygiene=0', (await ev('State.variables.hygiene')) === 0);
  await clickText('起身'); await sleep(1600);
  ok('泡澡后回 Inn Room', (await passage()) === 'Inn Room', 'passage=' + (await passage()));
  await clickText('浴室'); await sleep(1400);
  await clickText('冲个澡'); await sleep(1800);
  ok('冲澡后仍在浴室', (await passage()) === 'Inn Bathroom', 'passage=' + (await passage()));
  ok('冲澡有清爽提示', /清爽/.test(await body()));
  const err2 = (await body()).match(/[^\n]*出错[^\n]*/g);
  ok('浴室无报错', !err2, err2 ? err2[0].slice(0, 120) : '');

  // ===== 段 3：睡眠 =====
  await clickText('卧室'); await sleep(1400);
  await clickText('睡下'); await sleep(3200);
  ok('进入 Inn Sleep', (await passage()) === 'Inn Sleep', 'passage=' + (await passage()));
  ok('醒来有「起床」', /起床/.test(await body()));
  await clickText('起床'); await sleep(1600);
  ok('起床回 Inn Room', (await passage()) === 'Inn Room', 'passage=' + (await passage()));

  // ===== 段 4：公寓 =====
  await reload(); await initGame();
  await ev('State.variables.money = 99999999');
  await play('Flats');
  ok('Flats 含待售房间入口', /待售的房间/.test(await body()));
  await clickText('待售的房间'); await sleep(1800);
  ok('进入 Flats Room Sale', (await passage()) === 'Flats Room Sale', 'passage=' + (await passage()));
  ok('显示 £62000', /62000/.test(await body()));
  await clickText('买下这间房'); await sleep(2000);
  ok('$caeFlatsRoom=1', (await ev('State.variables.caeFlatsRoom')) === 1);
  await clickText('进去看看'); await sleep(1800);
  ok('进入自己的房间', (await passage()) === 'Flats Own Room', 'passage=' + (await passage()));
  await clickText('衣柜'); await sleep(2000);
  ok('进入衣柜段落', (await passage()) === 'Flats Own Wardrobe', 'passage=' + (await passage()));
  ok('衣柜容器存在', await ev('document.querySelector("#wardrobewear") !== null'));
  await clickText('关上衣柜'); await sleep(1800);
  ok('关上衣柜回房间', (await passage()) === 'Flats Own Room', 'passage=' + (await passage()));
  await clickText('看看能添置什么'); await sleep(1400);
  ok('进入升级页', (await passage()) === 'Flats Own Upgrade', 'passage=' + (await passage()));
  await ev('State.variables.money = 99999999');
  await clickText('床垫'); await sleep(1200);
  await clickText('淋浴间'); await sleep(1200);
  await clickText('书架'); await sleep(1200);
  ok('三项升级状态', (await ev('State.variables.caeFlatsBed')) === 1 && (await ev('State.variables.caeFlatsBath')) === 1 && (await ev('State.variables.caeFlatsShelf')) === 1);
  await clickText('回房间'); await sleep(1400);
  ok('升级后房间描述更新', /淋浴|书架/.test(await body()));
  await clickText('睡一觉'); await sleep(3200);
  ok('公寓睡眠段落', (await passage()) === 'Flats Own Room Sleep', 'passage=' + (await passage()));
  ok('睡眠后能起床', /起床/.test(await body()));

  // ===== 段 5：森林快速旅行 =====
  await reload(); await initGame();
  await ev('State.variables.forest = 50; State.variables.eventskip = 1');
  await play('Forest');
  ok('Forest 含快速旅行入口', /快速旅行/.test(await body()));
  await clickText('快速旅行'); await sleep(1800);
  ok('进入快速旅行页', (await passage()) === 'Forest Fast Travel', 'passage=' + (await passage()));
  const ft = await body();
  ok('显示深度/技能/步数/分钟', /森林深度/.test(ft) && /运动技能/.test(ft) && /次快速前进/.test(ft) && /分钟/.test(ft));
  ok('只有森林内目的地', /湖泊/.test(ft) && /教堂墓地/.test(ft) && !/Wolf Street/.test(ft));
  await clickText('湖泊：岸边'); await sleep(2400);
  ok('到达后 forest=25', (await ev('State.variables.forest')) === 25, 'forest=' + (await ev('State.variables.forest')));
  ok('到达 Lake Shore', (await passage()) === 'Lake Shore', 'passage=' + (await passage()));

  // ===== 段 6：Street Dogs（野兽战保护） =====
  await reload(); await initGame();
  await play('Street Dogs'); await sleep(1500);
  const sd = await body();
  ok('Street Dogs 无报错', !/出错/.test(sd), (sd.match(/[^\n]*出错[^\n]*/) || [''])[0].slice(0, 150));
  ok('Street Dogs 无「咬」动作', !/咬/.test(sd));

  summary();
  process.exit(results.some((r) => !r.pass) ? 1 : 0);
}
function summary() {
  const pass = results.filter((r) => r.pass).length;
  const fails = results.filter((r) => !r.pass);
  log('');
  log(`===== 汇总：${pass}/${results.length} 通过 =====`);
  fails.forEach((f) => log('FAIL: ' + f.name + (f.detail ? ' | ' + f.detail : '')));
}
main().catch((e) => { log('脚本异常: ' + (e && e.stack || e)); summary(); process.exit(2); });
