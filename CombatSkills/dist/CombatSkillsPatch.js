/* ============================================================================
 * CombatSkills mod v1.5.0 ― 防御力减伤 + 敏捷接入技能判定（不修改任何游戏文件）
 * ----------------------------------------------------------------------------
 * 1) 防御力：玩家受伤的唯一统一入口是 JS 宏 pain(amount, modifier = 4)
 *        pain = amount * modifier  →  V.pain += pain * 体温系数
 *    用 Macro.delete + Macro.add 包一层 handler，把 modifier 乘上
 *    (1 - 防御力/100)，即「防御力每 1 点 -1% 受到伤害」，上限 -90%。
 *
 * 2) 敏捷：游戏读取技能值的统一入口是 window.currentSkillValue(skill, disableModifiers)
 *    —— 全游戏 1281 处调用，事件判定几乎都走它；而特征面板的技能框用的是
 *    $danceskill / $athletics 原值，不经过这里。
 *    本脚本包装它：对「敏捷类」技能（舞蹈 / 运动 / 游泳 / 足部）额外加上
 *    $combatBonus.agility，于是这些技能参与的事件判定（缠斗里的闪避判定用的是
 *    feetskill + danceskill，因此也包含在内）都会享受到敏捷加成。
 *    只改 window 上的只读查询结果，不动任何存档变量；disableModifiers 非 0 的
 *    内部查询（游戏自己用来拿原值的）保持原样。
 *
 * 用法：由 dist/js/installCombatSkillsPatch.js（ModLoader 的 scriptFileList）调用：
 *     window.CombatSkills_patch(Macro);
 *
 * 刻意不改动：$violence（暴力值）、$stress/$trauma（压力/创伤）——只减「伤害(pain)」；
 * 也不改 pain 的 arousal 计算：只缩放 modifier，不缩放 amount。
 * ==========================================================================*/
(function () {
	"use strict";

	if (window.CombatSkills_patch) { return; }   /* 幂等：重复注入时直接复用 */

	/* 与 twee 里 combatStatTable 完全一致的 16 档阈值（F- ~ S） */
	var TIERS = [0, 67, 133, 200, 267, 333, 400, 467, 533, 600, 667, 733, 800, 867, 933, 1000];
	/* 每档加成：攻击力+5 / 防御力+5 / 敏捷+5（敏捷直接加在 0~1000 的技能判定尺度上） */
	var RATE = { attack: 5, defense: 5, agility: 5 };
	var MAX_REDUCTION = 90;                            /* 减伤上限（%） */
	/* 敏捷计入判定的技能（与游戏里「看舞蹈等技能」的判定方式一致） */
	var AGILITY_SKILLS = ["danceskill", "athletics", "swimmingskill", "feetskill"];

	function getVars() {
		try {
			var S = (typeof window !== "undefined") ? window.State : null;
			return (S && S.variables) ? S.variables : null;
		} catch (e) {
			return null;
		}
	}

	function tierIndex(value) {
		var v = Number(value);
		if (isNaN(v)) { return 0; }
		var idx = 0;
		for (var i = 0; i < TIERS.length; i++) { if (v >= TIERS[i]) { idx = i; } }
		return idx;
	}

	/* 优先读 $combatBonus；面板还没打开过（未初始化）时，直接从 $combatSkills 兜底换算 */
	function bonusOf(key) {
		var V = getVars();
		if (!V) { return 0; }
		var b = V.combatBonus;
		if (b && typeof b[key] === "number") { return b[key]; }
		var s = V.combatSkills;
		if (!s) { return 0; }
		var raw = s[key];
		if (typeof raw !== "number" && key === "agility") { raw = s.dodge; }   /* v1.2.0 旧存档 */
		if (typeof raw === "number") { return tierIndex(raw) * (RATE[key] || 0); }
		return 0;
	}

	/* ---- 1) 防御力：包装 pain 宏 ---- */
	function installPainPatch(Macro) {
		if (!Macro || typeof Macro.get !== "function") { return false; }
		var def = Macro.get("pain");
		if (!def) { return false; }
		if (def.__combatSkillsPatched) { return true; }
		var orig = def.handler;
		if (typeof orig !== "function") { return false; }

		var wrapper = function () {
			try {
				var reduction = Math.min(MAX_REDUCTION, Math.max(0, bonusOf("defense"))) / 100;
				if (reduction > 0 && this && this.args && this.args.length > 0) {
					/* 默认 modifier = 4；调用方显式传了就用它的值 */
					var raw = (this.args.length > 1 && this.args[1] !== undefined && this.args[1] !== null)
						? Number(this.args[1])
						: 4;
					if (!isNaN(raw)) { this.args[1] = raw * (1 - reduction); }
				}
			} catch (e) {
				console.error("[CombatSkills] pain 减伤计算失败", e);
			}
			return orig.apply(this, arguments);
		};

		var newDef = { tags: def.tags, handler: wrapper };
		if (def.isWidget !== undefined) { newDef.isWidget = def.isWidget; }
		if (def.skipArgs !== undefined) { newDef.skipArgs = def.skipArgs; }

		try {
			Macro.delete("pain");
			Macro.add("pain", newDef);
		} catch (e) {
			console.error("[CombatSkills] 无法替换 pain 宏", e);
			return false;
		}
		newDef.__combatSkillsPatched = true;
		console.log("[CombatSkills] pain 宏已接管：防御力每 1 点 = 受到伤害 -1%（上限 -90%）");
		return true;
	}

	/* ---- 2) 敏捷：包装 currentSkillValue ---- */
	function installSkillValuePatch() {
		var orig = window.currentSkillValue;
		if (typeof orig !== "function") { return false; }
		if (orig.__combatSkillsPatched) { return true; }

		var wrapper = function (skill, disableModifiers) {
			var base = orig.apply(this, arguments);
			try {
				if (!disableModifiers && AGILITY_SKILLS.indexOf(skill) !== -1) {
					var add = bonusOf("agility");
					if (add > 0) { return base + add; }
				}
			} catch (e) {
				console.error("[CombatSkills] 敏捷加成计算失败", e);
			}
			return base;
		};
		wrapper.__combatSkillsPatched = true;
		window.currentSkillValue = wrapper;
		console.log("[CombatSkills] currentSkillValue 已接管：敏捷计入 " + AGILITY_SKILLS.join(" / ") + " 的判定");
		return true;
	}

	function ensurePatches(Macro) {
		var painDone = false;
		var skillDone = false;
		function attempt() {
			if (!painDone) { painDone = installPainPatch(Macro); }
			if (!skillDone) { skillDone = installSkillValuePatch(); }
			return painDone && skillDone;
		}
		if (attempt()) { return; }
		/* 游戏脚本可能比本脚本更晚就位：轮询 60 次 × 250ms = 15 秒 */
		var tries = 0;
		var timer = setInterval(function () {
			tries += 1;
			if (attempt() || tries > 60) {
				clearInterval(timer);
				if (!painDone) { console.error("[CombatSkills] 找不到 pain 宏，防御力减伤未生效"); }
				if (!skillDone) { console.error("[CombatSkills] 找不到 window.currentSkillValue，敏捷加成未生效"); }
			}
		}, 250);
	}

	window.CombatSkills_patch = function (Macro) {
		try {
			ensurePatches(Macro);
		} catch (e) {
			console.error("[CombatSkills] 补丁初始化失败", e);
		}
	};

	/* 供控制台自查 */
	window.CombatSkills_debug = function () {
		var V = getVars();
		var d = bonusOf("defense");
		return {
			combatSkills: V ? V.combatSkills : undefined,
			combatBonus: V ? V.combatBonus : undefined,
			attackBonus: bonusOf("attack"),
			defenseBonus: d,
			damageReduction: Math.min(MAX_REDUCTION, Math.max(0, d)) / 100,
			agilityBonus: bonusOf("agility"),
			agilitySkills: AGILITY_SKILLS.slice(),
			agilitySample: {
				danceskill: (typeof window.currentSkillValue === "function") ? window.currentSkillValue("danceskill") : undefined,
				athletics: (typeof window.currentSkillValue === "function") ? window.currentSkillValue("athletics") : undefined
			},
			painPatched: !!(window.Macro && window.Macro.get && window.Macro.get("pain") && window.Macro.get("pain").__combatSkillsPatched),
			skillValuePatched: !!(window.currentSkillValue && window.currentSkillValue.__combatSkillsPatched)
		};
	};
})();
