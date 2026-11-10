# 更新日志

## 2026-11-03 LocationsExt v1.7.4：衣柜关闭选项不再消失（原版 wardrobeExits 机制）

- **修复：旅店/公寓衣柜里换装一次后，「关上衣柜」选项消失**
  - 原因：原版衣柜 JS 每次交互后会执行 `$('#wardrobeExits').html(new Wikifier(null, "<<wardrobeExits>>").output)` 刷新出口；
    `wardrobeExits` widget 按 `$passage` 分支，而我们的自定义衣柜段落不在分支里 → 刷新后出口为空
  - 修复：构建脚本新增第 4 条 TweeReplacer 补丁，给 `Widgets Wardrobe` 的 `wardrobeExits` widget 增加：
    `<<case "Inn Wardrobe">>` → 「关上衣柜」回 `Inn Room`；`<<case "Flats Own Wardrobe">>` → 「关上衣柜」回 `Flats Own Room`
  - 两个衣柜段落改为原版写法 `<div id="wardrobeExits"><<wardrobeExits>></div>`
- 实测：打开衣柜 → 模拟/多次换装刷新出口 → 「关上衣柜」始终存在且可点回房间；原版 `Wardrobe`（孤儿院）不受影响
- 探针新增：两个衣柜段落使用 `<<wardrobeExits>>`

## 2026-11-02 LocationsExt v1.7.3：旅店原版式上床方式 + 衣柜

- **旅店房间补上原版孤儿院床的三种上床方式**
  - 「爬到床上」：直接进被窝（不脱衣）
  - 「脱光并爬到床上」：`<<undressSleep "wardrobe">>` 把衣服收进衣柜后上床
  - 「穿上〇〇并爬到床上」：照原版 `listsleepoutfits` 列出衣柜里标记为 sleep 的套装，选中后 `<<wearoutfit>>` 穿上再上床
- **新增旅店衣柜** `Inn Wardrobe`：原版 Wardrobe 界面（`<<wardrobeSelection>>` / `<<wardrobewear>>` / `<<wardrobe>>`），
  自定义退出「关上衣柜」回房间；脱光上床 / 起床后都可用它换衣服
- `Inn Bed` 顶部按原版 Bed 加 `<<wearoutfit>>`，爬下床时 `<<storeon "wardrobe">>` 整理衣物
- 探针新增检查：`Inn Wardrobe`、衣柜链接、脱光上床、睡衣列表 widget
- 实测（Headless Chrome 真实点击）：脱光上床 → 裸体状态、衣柜打开/关闭、睡 8 小时疲劳 800→0、起床回房间，15/15 全过

## 2026-11-02 LocationsExt v1.7.2：旅店床铺改为原版式睡眠

- **修复：旅店床上睡觉没有任何效果**（时间不推进、疲劳不恢复）
  - 原因：旧版 `Inn Sleep` 直接调用 `<<sleep>>`，但没有先设置原版睡眠时长变量 `$sleephour`，
    导致 `sleephour` 的每小时循环一次都不执行（`<<pass 1 hour>>` 不运行）
  - 修复：照原版孤儿院床流程重做
    - 房间点「爬到床上」→ 新段落 `Inn Bed`：`<<nightmareCheck "Inn Sleep">>` + `<<generateSleepLinks "Inn Sleep">>`
      （出现原版「睡 8/7/…/1 小时」「只管去睡」选项 + 预计时间）+ 「爬下床」
    - 选时长后进入 `Inn Sleep`：`<<sleep>>` + `<<effects>>` + `<<sleepeffects>>` + `<<wakingEffects $sleepHoursTotal>>`，
      按原版每小时 −200（无创伤再 −50）疲劳
    - 醒来有「起床」回房间 /「下楼，退房离开」
- 实测：睡 8 小时 → 时间 +8.00 小时、疲劳 900→0，来回房间正常
- 探针新增检查项：`Inn Bed` 段落、睡 1~8 小时链接、`nightmareCheck`
- 探针修复：`Story.get` 改为通过 `SugarCube.Story` 读取（否则探针项全 fail）

## 2026-11-01 LocationsExt v1.7.1：版本自检（探针 + 页面版本水印）

- **新增加载自检探针** `dist/js/probe.js`：刷新后控制台打印 `[LocationsExt] v1.7.1 已加载（探针脚本）`；
  执行 `LocationsExtProbe()` 可检查旅店/公寓/森林段落是否为新版、ModLoader 列表里是否有 LocationsExt
- **旅店页面底部显示版本水印** `LocationsExt v1.7.1`，进店即可确认加载的是哪一版
- 用于排查「游戏里加载了旧副本导致旅店还是旧界面/点租房直接跳到 Inn Sleep」的问题：
  旧副本通常来自之前用 ModLoader 界面导入过的旧 zip（存在于浏览器本地存储，会覆盖文件夹里的新版），
  需要在 ModLoader 列表/本地存储里删除旧条目后再刷新
- 功能与 v1.7.0 一致：£40/天、当天自由进出、隔天贝利式拦路、二楼卧室+浴室、公寓房间、森林快速旅行

## 2026-10-30 合集更新：新增 CombatActionsExt v0.9.2 与 LocationsExt v1.7.0

- **新增 CombatActionsExt v0.9.2**（NSFW，可单独安装）：战斗中性行为扩展
  - 咬（人类战、嘴自由时必定命中）、脱掉上衣/下衣（原版 Undress 判定）、揉捏胸部、
    插入小穴→继续指奸→拳交、手指插入→继续指奸→拳交、脚揉胸部/脚趾插入、敌人高潮选择
  - v0.9.1 / v0.9.2 修复：野兽战与多目标战的 `$NPCList` 空条目保护、调度器仅人类战斗执行，
    不再出现 `Cannot read properties of undefined (reading 'vagina')`
- **新增 LocationsExt v1.7.0**：地点扩展
  - 旅店（High Street → Alternate routes）：£40/天，当天自由进出，隔天需重新付钱，
    没付房钱上楼会被店员拦住要钱（贝利式），掏不出钱被赶回前台（+压力）
  - 旅店二楼房间参考孤儿院卧室/浴室：睡下、浴室 (0:01)（泡澡 0:30 / 冲澡 0:10 / 原版 personalUpkeep / 妊娠检测）、下楼 (0:01)
  - 公寓可购买房间（Flats，£62000）：睡觉、衣柜（自定义退出回房间）、床垫/淋浴间/书架升级
  - 森林快速旅行：按「5 点深度 = 5 分钟」步数计时，运动技能缩短每步耗时；只列森林内目的地，
    森林外只保留「快速返回森林之外（Danube Street）」
- CombatSkills 保持 **v1.13.2**（本次未改动）
- 仓库新增 `build-actions.ps1` / `build-locations.ps1`，三个 mod 可分别单独构建

## actions-v0.9.5：拳交可以被对方主动挤出

- 旧逻辑只在**玩家手技判定失败**时才会被挤出；玩家手技/好感高了以后拳交几乎必定成功，等于插进去就拿不出来
- v0.9.5 起，**继续拳交**每回合先判定对方是否主动绞紧/收缩：
  概率 `Math.clamp(floor($enemyanger / 6) - floor(currentSkillValue("handskill") / 20) + 10, 5, 75)`
  —— 对方越愤怒越容易被挤出，玩家手技越高越不容易（最低 5%、最高 75%）
- 小穴被挤出：「对方的小穴猛地一阵绞紧，硬生生把你的左手整只拳头挤了出来，穴口还在微微收缩。」
- 肛门被挤出：「对方的肠道猛地一阵痉挛，硬生生把你的右手整只拳头挤了出来……」
- 被挤出后状态清空，下一回合恢复「手指插入小穴/肛门」等动作；原来玩家判定失败的挤出逻辑保留
- 实测（headless Chrome 真实运行时）：愤怒拉满时小穴/肛门都能在 1~2 回合内被挤出，46/46 通过
## actions-v0.9.4：手部链条修复 + 明确显示插入部位

- **修复「拳交」永远失败**：每回合开头的插入状态清理只放行「继续指奸」（*Keep），
  没放行「拳交」那一步（*Fist），导致手指状态在拳交动作执行前就被清掉、拳交前置条件永远不满足。
  现在左右手都同时放行 `caeHandFist` / `caeHandVagFist`
- **动作名写明部位**：「手指插入小穴」「继续指奸（小穴）」「拳交（小穴）」「继续拳交（小穴）」；
  肛门链对应「手指插入肛门」「继续指奸（肛门）」「拳交（肛门）」「继续拳交（肛门）」
- **文案写明「哪只手 + 什么部位 + 哪个洞」**：插入/继续/拳交/被挤出/换动作抽出的所有提示都写清
  左手/右手、两根手指/整只手/拳头、小穴/肛门；不再使用「体内」「那里」等模糊说法
- **每回合结尾新增当前状态行**：如「现在：左手的拳头插在对方小穴里；右手的两根手指插在对方肛门里。」
- 构建新增自检：禁止 `体内`、必须含 `_caeHandCN`/`_caeStatusList`、必须放行拳交转移
- 实测（headless Chrome 真实 SugarCube 运行时）：左右手标签、小穴链 4 步、肛门链 4 步、
  双手双洞同时进行、换动作抽出提示，**42/42 通过**
## actions-v0.9.3

- **修复严重报错**：`combatActionsExtDo` 里把目标 NPC 临时变量误写成 `$_caeNPC`（story 变量），
  读取 `undefined.vagina` 抛 `TypeError` —— 在 Bus Seat Rape 等场景触发
  `<<effectsman>>: errors within widget code ... Cannot read properties of undefined (reading 'vagina')`
- 修正为临时变量 `_caeNPC`（24 处），并把动作结算的目标守卫拆成 `_caeHasNPC` / `_caeNeedsNPC`：
  无 NPCList 条目的场景只跳过需要目标的动作（咬/高潮选择仍可用）
- 构建脚本新增防回归自检：twee 里禁止出现 `$_cae*` 前缀；必须包含目标 NPC 守卫
## v1.13.4

- **修复酒吧斗殴胜利不加钱**：`<<money (500 + random(0, 10) * 100) "pubBrawl">>` 的表达式带空格，
  SugarCube 宏参数按空格切分后 amount 变成字符串 `"(500"`，`money()` 抛参数错误并被 `DefineMacro`
  静默吞掉（只 console.warn）→ 胜利文本正常但钱没进账
- 改为先 `<<set _brawlPay to 500 + random(0, 10) * 100>>` 再 `<<money _brawlPay "pubBrawl">>`
- 构建新增自检：twee 出现 `<<money (` 写法直接拒绝构建
- 实测（headless Chrome + 全 mod）：胜利分支 money 10000 → 11500（+£15）、`$pubBrawlWins=1`
## v1.13.3

- **修复严重数值 bug**：战斗掉落的「赃款」单位错误 —— `$blackmoney` 字段单位是英镑
  （游戏 `Pub Sell` 销赃时 `<<money $blackmoney * 100>>`），旧版把便士（500~1500）直接加进去，
  导致销赃时金额 ×100（£15 变 £1500）
- 现在先 `_clPounds = Math.floor(_clAmount / 100)` 再累加（£5~£15 正常），汇总面板仍按便士累加显示
- README 增加旧存档修复用的控制台一行代码
## v1.13.2

- 特征面板改为**运行期 JS 注入**：监听特征覆盖层（`#customOverlayContent`）渲染，
  把「战斗技能」插到武器技能（`#prof`）之后；**TweeReplacer 不再包含界面锚点**
  → 任何环境（汉化 / 原版优化 / Maplebirch / 整合包）都不会再有
  `[TweeReplacer] cannot find findString` 报错，面板也不会整栏消失
- TweeReplacer 参数从 14 条降为 13 条（干净环境与模拟整合包环境均为 ok13/error0）
- 战利品（多敌人）锚点保持纯代码 `<<widget "defeatnpc">>`（v1.13.1 起）
## v1.13.1

- 修复：部分 mod（原版优化 / Maplebirch 等改写段落的整合包）环境下
  「特征」页面整个战斗技能栏消失 —— 特征面板新增 **JS 兜底注入**
  （TweeReplacer 锚点失效时，进入特征页面仍会把战斗技能栏插到武器技能下方）
- 修复：多敌人击败不掉战利品 —— 战利品锚点从英文战斗文本改为纯代码 `<<widget "defeatnpc">>`
- 加载日志中若仍有一条 Characteristics 的 `cannot find findString` 可忽略（已由兜底接管）
## v1.13.0

- 适配 **DoL 0.5.12.13**（全部 14 个补丁锚点重新校验，0.5.11.9 同样兼容）
- 修复 0.5.12.13 衣物改名导致的战利品别名失效（`swim shirt` → 现版本改用 `t-shirt`），衣物测试 9/9 通过
- 构建脚本新增 `-GameDirOverride` / `-OutDir` 参数，可对任意游戏目录构建
- 版本标注与文档更新到 0.5.12.13
## v1.12.3

- 兼容性：汉化 mod 未完整加载时（`setup.NPC_CN_TYPE is not a function`）
  安装脚本会临时兜底该函数，避免 `<<beast>>` widget 报错刷屏（只在其缺失时生效，不覆盖汉化实现）
## v1.12.2

- 新增战利品：击败**人类** NPC 时 **40%** 概率获得对方身上剩下的衣物（上衣/下装），
  按耐久度复制一件放进衣柜，并把对方那一格置为 naked
- 新增 `dist/CombatSkillsClothes.js`：NPC 简化衣物名 → 玩家可穿戴衣物 的别名表（覆盖 92%）
- 战利品面板新增「衣物」分类，绿色提示会显示获得的中文衣物名（优先用汉化提供的 `cn_name`）
## v1.12.1

- 敏捷每档加成 **+10 → +5**（满级 +150 → +75），与攻击/防御对齐
- JS 判定系数、面板档位描述、文档同步

## v1.12.0

- 新增战斗动作 **反剪双臂 / 继续压制**（力量判定、锁住对方双手、按住 2 回合）

## v1.11.3

- 为其它 mod 引用的 `<<askicon>>` 提供兼容兜底（0.5.11.9 原版没有该宏）
- 版本自检：面板页脚与控制台日志都会打印实际加载版本

## v1.11.2

- 修复 `le` 运算符导致的战斗结束报错（`SyntaxError: Unexpected identifier 'le'`），
  「掉物品」分支至此才真正生效
- 构建期新增 TwineScript 运算符白名单校验

## v1.11.1

- 酒吧斗殴入口锚点改为纯代码（原锚点含英文界面文字，会被汉化替换导致补丁静默失效）

## v1.11.0

- 新增 **丰收街酒吧斗殴**：赢拿彩头、输被保镖丢出酒吧

## v1.10.1

- 修正人类 NPC 判定（`$NPCList[i].type` 为 `"human"` 而非 `"man"`），人类敌人从此会掉钱
- 战利品代码全面加防御性判断（`<<endcombat>>` 全游戏近 3000 处调用）

## v1.10.0

- 拳击训练收费 £20；钱不够时只显示提示
- 修正货币单位（游戏以**便士**存储，之前金额小 100 倍）

## v1.9.0

- 陪练疼痛修复（含宽容模式提示、变动指示器）
- 拳击训练增加运动（athletics）经验

## v1.8.0

- 新增 **拳击俱乐部**：陪练挣钱 / 拳击训练 / 更衣室 / 浴室淋浴间

## v1.7.0

- 战斗结束界面新增「战利品」汇总面板

## v1.6.0

- 修正 1v1 战斗不掉落的问题（`defeatnpc` 只在多敌人时调用，改为挂 `endcombat`）

## v1.4.0

- 新增战利品掉落（人类掉钱/物品、非人类掉随身物品）

## v1.0.0

- 初版：「特征」面板新增战斗技能区块（攻击 / 防御 / 敏捷，F- ~ S 16 档）
- 攻击力：每点 +1% 造成伤害；防御力：每点 −1% 受到伤害（上限 −90%）
- 敏捷：计入 舞蹈 / 运动 / 游泳 / 足部 判定
- 战斗成长钩子：攻击 +1、受击 +1 防御 & 敏捷、闪避成功 +10 敏捷
