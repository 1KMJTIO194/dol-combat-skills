/* ============================================================================
 * LocationsExt —— 加载/补丁自检探针
 * ----------------------------------------------------------------------------
 * 作用：确认游戏里真正加载的是哪个版本的 LocationsExt、3 条 TweeReplacer 补丁
 *       有没有打进段落里（旅店入口 / 公寓房间入口 / 森林快速旅行入口）。
 *
 * 用法（游戏里按 F12 打开控制台）：
 *   1. 刷新页面后，控制台应出现：
 *        [LocationsExt] v1.7.1 已加载（探针脚本）
 *      —— 如果出现的是更小的版本号，或者一行都没有，说明加载的是旧副本
 *   2. 再执行：LocationsExtProbe()
 *      会打印一张检查表：true = 该功能/补丁已生效，false = 没加载到（旧版或被覆盖）
 * ==========================================================================*/
(function () {
	var TAG = "[LocationsExt]";
	var VERSION = "1.7.1";
	window.LocationsExt_version = VERSION;
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

	window.LocationsExtProbe = function () {
		var checks = [];
		function c(name, ok, detail) { checks.push({ name: name, ok: !!ok, detail: detail || "" }); }

		var inn = passageText("Inn");
		var innRoom = passageText("Inn Room");
		var innStairs = passageText("Inn Stairs");
		var innBath = passageText("Inn Bathroom");
		var flats = passageText("Flats Room Sale");
		var forest = passageText("Forest Fast Travel");

		c("Inn 段落存在", inn.length > 0, "长度=" + inn.length);
		c("旅店：新版租房（→Inn Room）", inn.indexOf("|Inn Room]]") >= 0);
		c("旅店：含「试着直接上楼」拦路", inn.indexOf("试着直接上楼") >= 0);
		c("旅店：含当天房钱判定", inn.indexOf("caeInnPaidToday") >= 0);
		c("旅店：描述含浴室", inn.indexOf("（带浴室）") >= 0);
		c("Inn Room 段落存在（二楼房间）", innRoom.length > 0);
		c("Inn Stairs 段落存在（拦路）", innStairs.length > 0);
		c("Inn Bathroom 段落存在（浴室）", innBath.length > 0);
		c("Flats Room Sale 段落存在（公寓房间）", flats.length > 0);
		c("Forest Fast Travel 段落存在", forest.length > 0);
		c("森林快速旅行：含湖泊目的地", forest.indexOf("湖泊") >= 0);

		try {
			var names = window.modUtils && window.modUtils.getModListNameNoAlias ? window.modUtils.getModListNameNoAlias() : [];
			c("ModLoader 已加载 LocationsExt", names.indexOf("LocationsExt") >= 0, "mod 数=" + names.length);
		} catch (e) { c("ModLoader 已加载 LocationsExt", false, e.message); }

		var pass = checks.filter(function (x) { return x.ok; }).length;
		console.log(TAG + " 自检 " + pass + "/" + checks.length);
		if (console.table) { console.table(checks); }
		else { checks.forEach(function (x) { console.log((x.ok ? "OK   " : "FAIL ") + x.name + (x.detail ? " | " + x.detail : "")); }); }
		return checks;
	};
})();
