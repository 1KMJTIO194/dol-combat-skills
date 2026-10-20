/* 开发/构建用的逻辑测试：验证「战利品衣物」的名称转换与衣柜写入
 * 用法：node tools/test-loot-clothes.js
 * 用 Node 的 vm 模拟游戏环境（window.setup.clothes / window.State.variables / clone），
 * 加载真实的 dist/CombatSkillsClothes.js 与 dist/CombatSkillsPatch.js，然后断言结果。
 */
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.join(__dirname, "..", "CombatSkills");
const aliasPath = path.join(root, "dist", "CombatSkillsClothes.js");
const patchPath = path.join(root, "dist", "CombatSkillsPatch.js");

const sandboxWindow = {};
sandboxWindow.window = sandboxWindow;
sandboxWindow.State = { variables: { wardrobe: {} } };
sandboxWindow.setup = {
	clothes: {
		upper: [
			{ name: "naked", integrity_max: 10 },
			{ name: "school shirt", integrity_max: 100, cn_name_cap: "校服衬衫" },
			{ name: "blazer", integrity_max: 100 },
			{ name: "large towel", integrity_max: 80 }
		],
		lower: [
			{ name: "naked", integrity_max: 10 },
			{ name: "school shorts", integrity_max: 120 },
			{ name: "jeans", integrity_max: 150 }
		]
	}
};
sandboxWindow.clone = o => JSON.parse(JSON.stringify(o));
const sandbox = {
	window: sandboxWindow,
	console,
	JSON,
	Math,
	Number,
	isNaN,
	setTimeout: () => 0,
	setInterval: () => 0,
	clearInterval: () => {}
};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(aliasPath, "utf8"), sandbox);
vm.runInContext(fs.readFileSync(patchPath, "utf8"), sandbox);

const loot = sandboxWindow.CombatSkills_lootClothes;
if (typeof loot !== "function") {
	console.error("FAIL: window.CombatSkills_lootClothes 未定义");
	process.exit(1);
}

let pass = 0, fail = 0;
function check(label, cond, extra) {
	if (cond) { pass++; console.log("  ✓ " + label); }
	else { fail++; console.log("  ✗ " + label + (extra ? "  → " + extra : "")); }
}

// 1) 别名转换：NPC "shirt" → 玩家 "school shirt"，显示中文名，耐久按传入值
let r = loot("upper", "shirt", 80);
check("NPC 'shirt' → 'school shirt'（别名）", r && r.name === "校服衬衫", JSON.stringify(r));
let w = sandboxWindow.State.variables.wardrobe;
check("物品已写进 wardrobe.upper", Array.isArray(w.upper) && w.upper.length === 1);
check("耐久写入 80", w.upper && w.upper[0] && w.upper[0].integrity === 80, JSON.stringify(w.upper && w.upper[0] && w.upper[0].integrity));

// 2) 完全同名 + 耐久夹到上限
r = loot("lower", "jeans", 9999);
check("NPC 'jeans' → 'jeans'（同名）", r && r.name === "jeans", JSON.stringify(r));
check("耐久被夹到 integrity_max(150)", w.lower[0].integrity === 150, String(w.lower[0].integrity));

// 3) 耐久为 0 时至少给 1（避免拿到损坏物品）
r = loot("upper", "blazer", 0);
check("耐久 0 → 至少 1", w.upper[w.upper.length - 1].integrity === 1, String(w.upper[w.upper.length - 1].integrity));

// 4) 无对应玩家衣物 → 返回 null（不硬塞错误物品）
r = loot("upper", "bikini top", 50);
check("NPC 'bikini top' 没有对应玩家衣物 → null", r === null, JSON.stringify(r));

// 5) 未知槽位按 upper 处理，不抛错
r = loot("weird", "school shirt", 50);
check("未知槽位不抛错", r && r.slot === "upper", JSON.stringify(r));

// 6) 别名表里的每个目标名都必须是真实玩家衣物（需要提供游戏 HTML 才能校验全量）
const alias = sandboxWindow.CombatSkills_clothesAlias || { upper: {}, lower: {} };
const htmlPath = process.argv[2];
if (htmlPath && fs.existsSync(htmlPath)) {
	const raw = fs.readFileSync(htmlPath, "utf8");
	const real = { upper: new Set(), lower: new Set() };
	for (const m of raw.matchAll(/new ClothesItem\(\{[\s\S]{0,2600}?\}\)/g)) {
		const seg = m[0];
		const slot = (seg.match(/slot:\s*"([^"]+)"/) || [])[1];
		const name = (seg.match(/name:\s*"([^"]+)"/) || [])[1];
		if (name && (slot === "upper" || slot === "lower")) real[slot].add(name);
	}
	let bad = 0;
	for (const slot of ["upper", "lower"]) {
		for (const [npcName, target] of Object.entries(alias[slot] || {})) {
			if (!real[slot].has(target)) { bad++; console.log(`  ✗ 别名无效: ${slot} "${npcName}" → "${target}"`); }
		}
	}
	check(`别名目标全部是真实玩家衣物（upper ${real.upper.size} / lower ${real.lower.size} 个定义）`, bad === 0, bad + " 条无效");
} else {
	console.log("  · 跳过别名目标校验（未提供游戏 HTML 路径）");
}

console.log("");
console.log(`结果: ${pass} 通过 / ${fail} 失败`);
process.exit(fail === 0 ? 0 : 1);
