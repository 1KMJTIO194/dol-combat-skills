/* 开发小工具：从游戏 HTML 里取出 lz-string 1.3.3，解压一个 DoL 存档文件并输出关键变量。
 * 用法： node modsrc/tools/decode-save.js "<save path>" [out.json]
 * 仅用于本地调试，不会打进 mod 包（build.ps1 只打包 CombatSkills 目录）。
 */
"use strict";
const fs = require("fs");

const htmlPath = process.argv[2] || "Degrees of Lewdity.html";
const savePath = process.argv[3];
const outPath = process.argv[4];

const html = fs.readFileSync(htmlPath, "utf8");
const start = html.indexOf("var LZString={");
if (start < 0) { throw new Error("找不到 LZString"); }
// 花括号配平找出对象结尾
let depth = 0, end = -1;
for (let i = html.indexOf("{", start); i < html.length; i++) {
	const ch = html[i];
	if (ch === "{") depth++;
	else if (ch === "}") { depth--; if (depth === 0) { end = i + 1; break; } }
}
if (end < 0) { throw new Error("LZString 括号配平失败"); }
const code = html.slice(start, end) + ";";
const LZString = new Function(code + " return LZString;")();

let raw = fs.readFileSync(savePath, "utf8").trim();
if (raw.startsWith('"') && raw.endsWith('"')) { raw = JSON.parse(raw); }   // 有些导出会再套一层 JSON 字符串
const json = LZString.decompressFromBase64(raw);
if (!json) { throw new Error("解压失败（不是 plaintext compressToBase64 格式？）"); }
console.log("解压成功，JSON 长度 =", json.length);

let data;
try { data = JSON.parse(json); } catch (e) { console.log("JSON.parse 失败：", e.message); console.log(json.slice(0, 500)); process.exit(1); }
console.log("顶层键 =", Object.keys(data).join(", "));

// 定位故事变量
function findVars(obj, path = "", depth = 0) {
	if (!obj || depth > 6) return null;
	if (obj.V && typeof obj.V === "object") return { path: path + "V", vars: obj.V };
	if (obj.variables && typeof obj.variables === "object") return { path: path + "variables", vars: obj.variables };
	for (const k of Object.keys(obj)) {
		if (typeof obj[k] === "object" && obj[k] !== null) {
			const r = findVars(obj[k], path + k + ".", depth + 1);
			if (r) return r;
		}
	}
	return null;
}
const found = findVars(data);
if (!found) { console.log("找不到故事变量（V）"); process.exit(1); }
console.log("变量位置 =", found.path);
const V = found.vars;

const picks = ["passage", "previousPassage", "gamemode", "enemyhealth", "enemynomax", "enemyno", "enemytype",
	"enemyarousal", "enemyarousalmax", "combat", "location", "money", "blackmoney", "pain", "combatSkills",
	"combatBonus", "combatLootLog", "boxingClub", "NPCList", "boxingClubSpars"];
const out = {};
for (const k of picks) {
	if (!(k in V)) { continue; }
	let val = V[k];
	if (k === "NPCList" && Array.isArray(val)) {
		val = val.map((n, i) => n && typeof n === "object" ? {
			i, type: n.type, fullDescription: n.fullDescription, health: n.health, stance: n.stance,
			active: n.active, looted: n.looted
		} : n);
	}
	out[k] = val;
}
console.log(JSON.stringify(out, null, 2));

if (outPath) { fs.writeFileSync(outPath, json); console.log("完整 JSON 已写入", outPath); }
