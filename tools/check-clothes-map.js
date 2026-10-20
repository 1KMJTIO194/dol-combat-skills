/* 开发工具：统计「NPC 衣服 → 玩家可穿戴衣物」的匹配覆盖率
 * 别名表直接读取 mod 实际的 dist/CombatSkillsClothes.js（单一数据源）。
 * 用法：node tools/check-clothes-map.js "<Degrees of Lewdity.html>"
 */
"use strict";
const fs = require("fs");
const path = require("path");

const htmlPath = process.argv[2] || "Degrees of Lewdity.html";
const raw = fs.readFileSync(htmlPath, "utf8");

// ---- 别名表（来自 mod 的 dist/CombatSkillsClothes.js）----
const aliasFile = path.join(__dirname, "..", "CombatSkills", "dist", "CombatSkillsClothes.js");
const sandbox = { window: {} };
new Function("window", fs.readFileSync(aliasFile, "utf8"))(sandbox.window);
const ALIAS = sandbox.window.CombatSkills_clothesAlias || { upper: {}, lower: {} };

// ---- 玩家可穿戴衣物 ----
const player = { upper: new Set(), lower: new Set() };
for (const m of raw.matchAll(/new ClothesItem\(\{[\s\S]{0,2600}?\}\)/g)) {
	const seg = m[0];
	const slot = (seg.match(/slot:\s*"([^"]+)"/) || [])[1];
	const name = (seg.match(/name:\s*"([^"]+)"/) || [])[1];
	if (name && (slot === "upper" || slot === "lower")) player[slot].add(name);
}

// ---- NPC 衣物名称 ----
const start = raw.indexOf("T.npcClothesItems = {");
const brace = raw.indexOf("{", start);
let depth = 0, end = -1;
for (let i = brace; i < Math.min(brace + 40000, raw.length); i++) {
	const ch = raw[i];
	if (ch === "{") depth++;
	else if (ch === "}") { depth--; if (depth === 0) { end = i; break; } }
}
const block = raw.slice(brace, end + 1);
function slotNamesOf(blockText, slotName) {
	const si = blockText.indexOf('"' + slotName + '": {');
	if (si < 0) return [];
	const ob = blockText.indexOf("{", si);
	let d = 0, e = -1;
	for (let i = ob; i < blockText.length; i++) {
		const ch = blockText[i];
		if (ch === "{") d++;
		else if (ch === "}") { d--; if (d === 0) { e = i; break; } }
	}
	return [...new Set([...blockText.slice(ob, e + 1).matchAll(/name:\s*"([^"]+)"/g)].map(x => x[1]))];
}

function matchName(slot, npcName) {
	const names = player[slot];
	if (names.has(npcName)) return { name: npcName, how: "exact" };
	const ali = ALIAS[slot] || {};
	if (ali[npcName] && names.has(ali[npcName])) return { name: ali[npcName], how: "alias" };
	for (const suf of [" top", " bottoms", " bottom", " skirt"]) {
		if (npcName.endsWith(suf)) {
			const base = npcName.slice(0, npcName.length - suf.length);
			if (names.has(base)) return { name: base, how: "suffix" };
		}
	}
	let best = null;
	for (const p of names) {
		if (p.length < 4) continue;
		if (npcName.includes(p) || p.includes(npcName)) {
			if (!best || p.length > best.length) best = p;
		}
	}
	if (best) return { name: best, how: "partial" };
	return null;
}

// ---- 别名目标合法性检查 ----
let badAlias = 0;
for (const slot of ["upper", "lower"]) {
	for (const [npcName, target] of Object.entries(ALIAS[slot] || {})) {
		if (!player[slot].has(target)) {
			badAlias++;
			console.log(`[无效别名] ${slot}: "${npcName}" → "${target}"（玩家衣物里没有这个名字）`);
		}
	}
}
if (!badAlias) console.log("别名目标全部有效 ✓");
console.log("");

let total = 0, ok = 0;
for (const slot of ["upper", "lower"]) {
	const list = slotNamesOf(block, slot);
	let sOk = 0, sExact = 0, sAlias = 0, sSuffix = 0, sPartial = 0;
	const fail = [];
	for (const n of list) {
		const r = matchName(slot, n);
		if (r) {
			sOk++;
			if (r.how === "exact") sExact++;
			else if (r.how === "alias") sAlias++;
			else if (r.how === "suffix") sSuffix++;
			else sPartial++;
		} else fail.push(n);
	}
	total += list.length; ok += sOk;
	console.log(`=== ${slot}: ${sOk}/${list.length} (${Math.round((100 * sOk) / list.length)}%)  exact=${sExact} alias=${sAlias} suffix=${sSuffix} partial=${sPartial}`);
	if (fail.length) console.log(`    未匹配: ${fail.join(" | ")}`);
}
console.log("");
console.log(`总计: ${ok}/${total} (${Math.round((100 * ok) / total)}%)`);
