/* ============================================================================
 * CombatActionsExt —— 动作分类着色（v0.6.0）
 * ----------------------------------------------------------------------------
 * 原版用 window.combatActionColours 给战斗动作上色/分类：
 *   def（反抗，红色）：bite / handbite / breastbite / bitepussy / headbutt …
 *   brat（暴躁）：leftupperpull / rightupperpull / steal …
 *   sub（顺从）：leftgrab / leftstroke / leftchest …
 * 我们自定义的动作不在原版表里，默认会显示成白色（看起来不像反抗行动）。
 * 这个脚本把我们的动作补进对应分类，让 UI 和原版一致。
 * 加载时机不确定，所以做「立即 + 延迟 + 每次过场」多次尝试，成功一次即停止。
 * ==========================================================================*/
(function () {
	var TAG = "[CombatActionsExt]";
	var GROUPS = {
		/* 反抗行动（红色）：咬 */
		def: ["caeMouthBite"],
		/* 暴躁/强硬（对应原版 leftupperpull 一类）：扯掉敌衣 */
		brat: ["caeUndressUpper", "caeUndressLower"],
		/* 顺从/性行为（对应原版 leftgrab / leftstroke / leftchest）：胸部与插入类 */
		sub: [
			"caeHandChest", "caeHandVag", "caeHandVagKeep", "caeHandVagFist", "caeHandVagFistKeep", "caeFeetChestKeep",
			"caeHandAnus", "caeHandAnusKeep", "caeHandFist", "caeHandFistKeep",
			"caeFeetChest", "caeFeetAnus", "caeFeetAnusKeep"
		]
	};
	var applied = false;

	function applyColours() {
		if (applied) { return true; }
		try {
			var colours = window.combatActionColours;
			if (!colours || typeof colours !== "object") { return false; }
			var changed = 0;
			for (var encounter in colours) {
				var table = colours[encounter];
				if (!table || typeof table !== "object" || Array.isArray(table)) { continue; }
				for (var group in GROUPS) {
					if (!Array.isArray(table[group])) { table[group] = []; }
					for (var i = 0; i < GROUPS[group].length; i++) {
						var action = GROUPS[group][i];
						if (table[group].indexOf(action) < 0) { table[group].push(action); changed++; }
					}
				}
			}
			if (changed > 0) {
				console.log(TAG + " 动作分类已生效：咬=反抗(def，红色) / 扯衣=brat / 胸部·插入=sub");
			}
			applied = changed > 0 || (colorsAlreadyApplied(colours));
			return applied;
		} catch (e) {
			console.warn(TAG + " 动作分类着色失败（不影响功能）", e);
			return false;
		}
	}

	function colorsAlreadyApplied(colours) {
		try {
			var table = colours.Default;
			return !!(table && Array.isArray(table.def) && table.def.indexOf("caeMouthBite") >= 0);
		} catch (e) { return false; }
	}

	function retry() {
		if (applyColours()) { return; }
		setTimeout(function () { if (applyColours()) { return; } setTimeout(retry, 1000); }, 0);
	}

	window.CombatActionsExtColours = applyColours;
	retry();
	try {
		if (typeof jQuery === "function") { jQuery(document).on(":passageinit", applyColours); }
	} catch (e) { /* 没有 jQuery 时靠定时器 */ }
})();
