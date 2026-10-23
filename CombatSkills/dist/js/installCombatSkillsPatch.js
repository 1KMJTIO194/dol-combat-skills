/* ============================================================================
 * CombatSkills mod v1.12.3 ― 安装脚本（ModLoader 的 scriptFileList）
 * 由 dist/CombatSkillsPatch.js 提供 window.CombatSkills_patch，
 * 这里把 SugarCube 的 Macro 交给它（与 DoLLinkButtonFilter 的做法一致）。
 * 版本号会在控制台打印，方便确认浏览器实际加载的是哪一版（排错用）。
 * ==========================================================================*/
(function () {
	var CS_VERSION = "1.12.3";
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
		console.log("[CombatSkills] v" + CS_VERSION + " 已加载：战斗属性 + 战利品 + 拳击俱乐部 + 酒吧斗殴 + 汉化兜底");
	/* ---- 兼容垫片：汉化 mod 缺失 setup.NPC_CN_TYPE 时兜底 ----
	 * 现象：汉化的 <<beast>> widget 补丁里调用 <<= setup.NPC_CN_TYPE(...)>>，
	 *       但定义该函数的汉化脚本没加载 → "setup.NPC_CN_TYPE is not a function" 报错。
	 * 这里只在函数确实缺失时补一个最小实现（返回传入值本身），避免报错刷屏；
	 * 汉化正常时不会生效（不覆盖真函数），重装汉化后中文名照常显示。 */
	try {
		if (typeof setup !== "undefined" && setup && typeof setup.NPC_CN_TYPE !== "function") {
			setup.NPC_CN_TYPE = function (x) {
				return (x === undefined || x === null) ? "" : String(x);
			};
			console.warn("[CombatSkills] 检测到汉化函数 setup.NPC_CN_TYPE 缺失（汉化 mod 未完整加载），已临时兜底：野兽类型名可能显示为英文");
		}
	} catch (e) {
		console.warn("[CombatSkills] 汉化兜底垫片安装失败（不影响本 mod）", e);
	}
		window.CombatSkills_patch(MacroRef);
	} catch (e) {
		console.error("[CombatSkills] installCombatSkillsPatch.js 出错", e);
	}
})();
