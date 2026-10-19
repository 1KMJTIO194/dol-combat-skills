/* ============================================================================
 * CombatSkills mod v1.12.1 ― 安装脚本（ModLoader 的 scriptFileList）
 * 由 dist/CombatSkillsPatch.js 提供 window.CombatSkills_patch，
 * 这里把 SugarCube 的 Macro 交给它（与 DoLLinkButtonFilter 的做法一致）。
 * 版本号会在控制台打印，方便确认浏览器实际加载的是哪一版（排错用）。
 * ==========================================================================*/
(function () {
	var CS_VERSION = "1.12.1";
	try {
		var MacroRef = (typeof Macro !== "undefined" && Macro) || (typeof window !== "undefined" && window.Macro) || null;
		if (!MacroRef) {
			console.error("[CombatSkills] installCombatSkillsPatch.js 取不到 Macro");
			return;
		}
		if (typeof window.CombatSkills_patch !== "function") {
			console.error("[CombatSkills] 缺少 dist/CombatSkillsPatch.js（boot.json 的 scriptFileList_inject_early 未生效？）");
			return;
		}
		window.CombatSkills_version = CS_VERSION;
		console.log("[CombatSkills] v" + CS_VERSION + " 已加载：战斗属性 + 战利品 + 拳击俱乐部 + 酒吧斗殴");
		window.CombatSkills_patch(MacroRef);
	} catch (e) {
		console.error("[CombatSkills] installCombatSkillsPatch.js 出错", e);
	}
})();
