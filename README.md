# DoL 扩展模组合集（CombatSkills / CombatActionsExt / LocationsExt）

《Degrees of Lewdity》（DoL）的 **ModLoader 模组**合集，**不修改任何游戏文件**，
全部通过 ModLoader 的段落替换（TweeReplacer）与脚本注入实现。

> 适配版本：**DoL 0.5.12.13**（0.5.11.9 的补丁锚点同样兼容；其它版本锚点可能对不上，构建脚本会拒绝打包）
> 语言：中文（模组自带文案，不走汉化表）· 许可：MIT（代码）

## 模组一览

| 模组 | 当前版本 | 内容 | 文档 |
|---|---|---|---|
| **CombatSkills** | v1.13.2 | 战斗技能面板（攻击/防御/敏捷 F~S）+ 战斗成长、战利品（含扒衣服）、拳击俱乐部、酒吧斗殴、反剪双臂 | [CombatSkills/README.md](CombatSkills/README.md) |
| **CombatActionsExt** | v0.9.2 | 战斗中性行为扩展（咬 / 脱衣 / 揉捏 / 插入 / 拳交 / 脚部动作 / 敌人高潮选择），NSFW | [CombatActionsExt/README.md](CombatActionsExt/README.md) |
| **LocationsExt** | v1.7.0 | 旅店（High Street，£40/天、当天自由进出、隔天贝利式拦路；卧室+浴室）、公寓可购买房间（£62000，衣柜/淋浴/书架升级）、森林快速旅行（按距离算步数、运动技能加速、单一快速出林） | [LocationsExt/README.md](LocationsExt/README.md) |

三个模组相互独立（各自有独立 `boot.json`），可以只装其中一个，也可以全部启用。


## 功能

### 1. 战斗技能面板

「特征」面板的武器技能下方新增 **战斗技能** 区块：

| 属性 | 每档加成 | 满级（S） | 实际效果 |
|---|---|---|---|
| 攻击 | 攻击力 +5 | +75 | 每 1 点攻击力 → 造成伤害 +1% |
| 防御 | 防御力 +5 | +75 | 每 1 点防御力 → 受到伤害 −1%（上限 −90%），疼痛同步降低 |
| 敏捷 | 敏捷 +5 | +75 | 直接计入 舞蹈 / 运动 / 游泳 / 足部 的技能判定（含缠斗闪避） |

等级 F- ~ S 共 16 档，技能值 0 ~ 1000，显示复用游戏自身的 `<<characteristic-box>>`。

### 2. 战斗成长

- 打中敌人 → 攻击 +1
- 被击中 / 被怪物扑袭 → 防御 +1、敏捷 +1
- 敏捷判定成功（缠斗闪避/险闪）→ 敏捷 +10

### 3. 战利品

- 击败人类 NPC：65% 掉钱（£10~30）、30% 掉物品
- 击败非人类 NPC：45% 掉它身上带着的东西
- 战斗结束界面显示「战利品」面板（逐项 + 现金/赃款合计）
- **扒衣服**：击败人类敌人时另有 **40%** 概率获得对方身上剩下的一件衣物（按耐久度放进衣柜）

### 4. 拳击俱乐部（康努达塔斯街）

- 当陪练挣钱 (0:30)：攻击 +1、防御 +2、敏捷 +1、意志 +1，疼痛上升，报酬 £20~40
- 拳击训练 (0:20 £20)：攻击 +2、敏捷 +1、运动 +5 点经验
- 更衣室 (0:01)、浴室和淋浴间 (0:01)；胜场越多对手越硬

### 5. 酒吧斗殴（丰收街 Pub）

- 和路人约架：赢拿 £5~15 彩头，**输会被保镖丢出酒吧**扔到丰收街
- 对手随胜场变强

### 6. 战斗动作「反剪双臂」

- 左手/右手动作列表新增「反剪双臂」：力量（physique）判定
- 成功把对方双臂反剪按住，封住其用手类动作，按住 2 回合；期间可「继续压制」
- 失败被反制、吃疼痛；人类与野兽敌人都可用

## 安装

> 前置：游戏自带 ModLoader（0.5.x 自带）+ **TweeReplacer** 插件

从 [Releases](../../releases) 下载对应版本的 zip，然后在游戏内 ModLoader → 添加 zip：

| 模组 | 下载文件 | 安装后确认 |
|---|---|---|
| CombatSkills | `CombatSkills_v1.13.2.zip` | 特征面板最底部显示 `CombatSkills mod v1.13.2` |
| CombatActionsExt | `CombatActionsExt_v0.9.2.zip` | F12 控制台有 `[CombatActionsExt] v0.9.2 已加载` 日志 |
| LocationsExt | `LocationsExt_v1.7.0.zip` | High Street 的 Alternate routes 里出现「旅店」；Flats 出现「看看待售的房间」 |

刷新页面后生效。**卸载**：ModLoader 里移除即可，游戏文件零改动、完全恢复原状。

## 目录结构

```
build.ps1                     CombatSkills 构建脚本（提取段落、断言锚点、打包 zip、生成 modList.json）
build-actions.ps1             CombatActionsExt 构建脚本
build-locations.ps1           LocationsExt 构建脚本
CombatSkills/                 CombatSkills mod 源（zip 内容）
  boot.json                   ModLoader 清单（tweeFileList / scriptFileList / addonPlugin）
  twee/CombatSkills.tw        全部 widget 与新增段落（拳击俱乐部、酒吧斗殴）
  dist/CombatSkillsPatch.js   JS 补丁：pain 减伤、currentSkillValue 敏捷接入、战利品衣物转换
  dist/CombatSkillsClothes.js NPC 衣物名 → 玩家衣物 别名表（覆盖 92%）
  dist/js/installCombatSkillsPatch.js
  CombatSkills.css            战利品面板样式（选择器全部限定在 #combatLootSummary）
  README.md                   详细文档（中文）
CombatActionsExt/             CombatActionsExt mod 源（NSFW）
  boot.json                   TweeReplacer 7 条挂点 + 探针/颜色脚本
  twee/CombatActionsExt.tw    动作注册 / 结算 / 清理 / 高潮拦截 widget
  dist/js/probe.js            版本探针（控制台可跑 CombatActionsExtProbe()）
  dist/js/actionColours.js    动作分类颜色（def/brat/sub）
  README.md
LocationsExt/                 LocationsExt mod 源
  boot.json                   TweeReplacer 3 条补丁（High Street / Flats / Forest）
  twee/LocationsExt.tw        旅店（前台/楼梯/房间/浴室/睡眠）、公寓房间（购买/衣柜/升级）、森林快速旅行
  README.md
docs/发布说明.md               发布帖草稿（作者/反馈/合规说明）
tools/decode-save.js           调试工具：解压 DoL 存档（lz-string）查看变量
tools/check-clothes-map.js     开发工具：统计 NPC 衣物名→玩家衣物的匹配覆盖率
tools/suggest-clothes-alias.js 开发工具：为未匹配的 NPC 衣物名推荐玩家衣物名
tools/e2e-v3.js                端到端测试：本地 HTTP + Headless Chrome 跑真实游戏流程
```

## 构建

需要 **DoL 0.5.12.13 的 `Degrees of Lewdity.html`** 与 **Node.js**（用于 `node --check` / 战利品测试）：

```powershell
# CombatSkills（默认从脚本上一级的游戏目录读取）
Set-ExecutionPolicy -Scope Process Bypass -Force
pwsh -File .\build.ps1 -GameDirOverride '<游戏目录>' -OutDir '<输出目录>'

# CombatActionsExt
pwsh -File .\build-actions.ps1 -GameDirOverride '<游戏目录>' -OutDir '<输出目录>'

# LocationsExt
pwsh -File .\build-locations.ps1 -GameDirOverride '<游戏目录>' -OutDir '<输出目录>'
```

各脚本会：从游戏 HTML 提取段落 → **断言补丁锚点各出现 1 次**（版本不符立即中止）→
校验 twee / JS 一致 → 生成 `boot.json` → 打包 zip → 更新 `modList.json`（保留其它条目）→
输出游戏 HTML 与 `boot.json` 的 SHA256 前后比对，证明**游戏文件零改动**。

## 兼容性

- 与汉化 mod 兼容：所有补丁锚点都是**纯代码**，不依赖英文界面文本
- CombatSkills 的特征面板改为**运行期 JS 注入**（v1.13.2+），整合包/原版优化/Maplcbirch 等改写段落的 mod 环境也不会再出现 TweeReplacer 找不到锚点的报错
- CombatActionsExt 的调度器只在**人类战斗**（`$enemytype is "man"`）执行；野兽战不注册/不结算，避免 `$NPCList` 无数据时报错（v0.9.2+）
- LocationsExt 的 3 个锚点同样是纯代码（`<<stormdrain>>` / `<<set $eventskip to 0>>` / `<<set $eventskip to 0>>`），汉化替换不影响
- 仅适配 0.5.12.13（0.5.11.9 锚点兼容）；其它版本请勿直接使用，构建脚本会拒绝打包

## CombatActionsExt（NSFW，可单独安装）

战斗动作扩展，详见 [CombatActionsExt/README.md](CombatActionsExt/README.md)。要点：

- 嘴部「咬」：人类战斗、嘴自由且没被捂住时出现（必定命中，参考原版 `handbite` 的文本与数值）
- 「脱掉上衣 / 脱掉下衣」：参考原版 `Undress` 判定（`combatSkillCheck` + 衣物耐久）
- 手部「揉捏胸部 / 插入小穴（→继续指奸→拳交→继续拳交）/ 手指插入（→继续指奸→拳交→继续拳交）」
- 脚部「脚揉胸部（→继续揉胸）/ 脚趾插入（→继续踩弄）」，需赤脚
- 敌人高潮时可选「继续缠着 / 结束战斗」
- v0.9.1~v0.9.2 修复：野兽战 / 多目标战的 `$NPCList` 空条目保护、调度器人类战限制

## LocationsExt（地点扩展，可单独安装）

详见 [LocationsExt/README.md](LocationsExt/README.md)。要点：

- **旅店（High Street → Alternate routes）**：£40 租当天的房间；当天可自由进出（前台「上楼回房间」），**隔天需重新付钱**；没付当天房钱想上楼会被店员拦住要钱（贝利式），掏不出钱会被赶回前台（+压力）
- 旅店房间参考孤儿院：卧室（睡下/浴室 0:01/下楼 0:01）+ 浴室（泡澡 0:30 / 冲澡 0:10 / 原版 `personalUpkeep` / 妊娠检测）
- **公寓可购买房间（Flats）**：£62000 买断；房间内可睡觉、打开衣柜（自定义退出回房间）、花 £300/£200/£150 升级床垫/淋浴间/书架
- **森林快速旅行（Forest）**：按「5 点深度 = 5 分钟」步数计算用时，运动技能缩短每步耗时（`max(2, 5 - floor(athletics/250))`，高跟鞋另算）；只列森林内目的地（教堂墓地/湖泊/伊甸小屋/狼洞/小溪/秘密小路），森林外只保留一个「快速返回森林之外（Danube Street）」

## 反馈

- 反馈请附：**mod 版本号**（游戏内「特征」面板最底部）+ **F12 控制台里 `[CombatSkills]` 开头的行 / 红色报错**
- 也可在发布帖回复

## 版权

- 本模组为**非官方**作品，《Degrees of Lewdity》版权归 **Vrelnir** 所有，请支持正版
- 本仓库代码与文案原创，MIT 许可；**禁止商用**，转载/二创请注明作者与仓库地址
- 不包含任何游戏本体资源
