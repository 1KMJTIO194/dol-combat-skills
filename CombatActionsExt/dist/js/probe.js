/* ============================================================================
 * CombatActionsExt —— 加载/补丁自检探针（v0.5.2）
 * ----------------------------------------------------------------------------
 * 作用：像「体检」一样确认这个 mod 有没有真的加载、7 条 TweeReplacer 补丁有没有打上。
 * 用法（游戏里按 F12 打开控制台）：
 *   1. 刷新页面后，控制台应出现：[CombatActionsExt] v0.5.2 已加载（探针脚本）
 *   2. 再执行：CombatActionsExtProbe()
 *      会打印一张表，每项 true = 对应补丁已生效，false = 那条补丁没打上（通常是版本/冲突）
 * ==========================================================================*/
(function () {
	var TAG = "[CombatActionsExt]";
	var VERSION = "0.9.2";
	window.CombatActionsExt_version = VERSION;
	console.log(TAG + " v" + VERSION + " 已加载（探针脚本）");

	function passageText(name) {
		try {
			if (window.Story && typeof Story.get === "function") {
				var p = Story.get(name);
				return p && p.text ? p.text : "";
			}
		} catch (e) { /* ignore */ }
		return "";
	}

	function modListNames() {
		try {
			if (window.modUtils && typeof modUtils.getModListNameNoAlias === "function") {
				return modUtils.getModListNameNoAlias();
			}
		} catch (e) { /* ignore */ }
		return null;
	}

	window.CombatActionsExtProbe = function () {
		var gen = passageText("Widgets Actions Generation");
		var eff = passageText("Widgets Effects Man");
		var man = passageText("Widgets Actions Man");
		var end = passageText("Widgets End Combat");
		var own = passageText("CombatActionsExt Widgets");
		var names = modListNames();
		var nameJoined = names ? names.join(" | ") : "";
		var checks = {
			"mod 列表含 CombatActionsExt": nameJoined.indexOf("CombatActionsExt") >= 0,
			"mod 列表含 TweeReplacer": nameJoined.indexOf("TweeReplacer") >= 0,
			"自定义 widget 段落存在": own.indexOf("combatActionsExtRegister") >= 0,
			"左手注册补丁": gen.indexOf('combatActionsExtRegister "left"') >= 0,
			"右手注册补丁": gen.indexOf('combatActionsExtRegister "right"') >= 0,
			"脚部注册补丁": gen.indexOf('combatActionsExtRegister "feet"') >= 0,
			"嘴部注册补丁": gen.indexOf('combatActionsExtRegister "mouth"') >= 0,
			"effectsman 结算挂点": eff.indexOf("<<combatActionsExt>>") >= 0,
			"endcombat 清空挂点": end.indexOf("<<combatActionsExtClear>>") >= 0,
			"actionsman 高潮拦截": man.indexOf("<<combatActionsExtClimax>>") >= 0
		};
		var ok = 0, total = 0;
		for (var k in checks) { total++; if (checks[k]) { ok++; } }
		if (names) { console.log(TAG + " 当前 ModLoader 列表:", names); }
		try { console.table ? console.table(checks) : console.log(checks); } catch (e) { console.log(checks); }
		console.log(TAG + " 补丁检查：" + ok + "/" + total + " 项生效" + (ok === total ? "（完全正常）" : "（有补丁没打上，请看 false 项）"));
		return checks;
	};

	setTimeout(function () { try { window.CombatActionsExtProbe(); } catch (e) { /* ignore */ } }, 1500);
})();
