/* 开发工具：为未匹配的 NPC 衣物名给出候选玩家衣物名
 * 用法：node tools/suggest-clothes-alias.js "<Degrees of Lewdity.html>"
 */
"use strict";
const fs = require("fs");
const raw = fs.readFileSync(process.argv[2] || "Degrees of Lewdity.html", "utf8");

const player = { upper: new Set(), lower: new Set() };
for (const m of raw.matchAll(/new ClothesItem\(\{[\s\S]{0,2600}?\}\)/g)) {
	const seg = m[0];
	const slot = (seg.match(/slot:\s*"([^"]+)"/) || [])[1];
	const name = (seg.match(/name:\s*"([^"]+)"/) || [])[1];
	if (name && (slot === "upper" || slot === "lower")) player[slot].add(name);
}
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

// 简单停用词
const STOP = new Set(["the", "and", "of", "a", "an", "s", "top", "bottom", "bottoms", "others"]);

function words(s) {
	return [...new Set(s.toLowerCase().replace(/[^a-z0-9' ]+/g, " ").split(/\s+/).filter(w => w && !STOP.has(w)))];
}
function score(npcName, cand) {
	const bw = words(npcName), cw = words(cand);
	let sc = 0;
	for (const w of bw) {
		if (cw.includes(w)) sc += 3;
		else if (cw.some(c => c.startsWith(w) || w.startsWith(c))) sc += 1;
	}
	return sc;
}
for (const slot of ["upper", "lower"]) {
	const names = slotNamesOf(block, slot);
	console.log(`\n########## ${slot} ##########`);
	for (const n of names) {
		const namesArr = [...player[slot]];
		const exact = namesArr.includes(n);
		if (exact) continue;
		const cands = namesArr
			.map(c => ({ c, s: score(n, c) }))
			.filter(x => x.s > 0)
			.sort((a, b) => b.s - a.s)
			.slice(0, 4);
		if (!cands.length) { console.log(`- ${n}   → (无候选)`); continue; }
		console.log(`- ${n}   → ${cands.map(x => `${x.c}(${x.s})`).join(" , ")}`);
	}
}
