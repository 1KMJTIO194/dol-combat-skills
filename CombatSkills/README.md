# CombatSkills（战斗属性：攻击 / 防御 / 敏捷）

## 作者 / 反馈 / 声明

- **作者**：见发布帖（本 mod 为原创作品，非整合、非搬运）
- **问题反馈**：在发布帖回复或私信作者，请附上 **mod 版本号**（游戏内「特征」面板最底部）与
  **F12 控制台里 `[CombatSkills]` 开头的行 / 红色报错**
- **免责声明**：非官方模组，《Degrees of Lewdity》版权归 Vrelnir 所有，请支持正版；
  本 mod 免费发布、禁止商用；转载或二创请注明作者与发布帖
- 适配 **0.5.12.13**（旧版本 0.5.11.9 的补丁锚点同样兼容）；不修改任何游戏文件，卸载即完全恢复原状
DoL 0.5.12.13 的 ModLoader mod。在「特征」面板的 **武器技能下方**、**不安感上方** 增加一个
**战斗技能** 区块，三个属性：

| 属性 | 存档键 | 每档加成 | F-（0 档） | … | S（15 档） |
|---|---|---|---|---|---|
| 攻击 | `attack`  | 攻击力 +5  | +0  | … | +75 |
| 防御 | `defense` | 防御力 +5  | +0  | … | +75 |
| 敏捷 | `agility` | 敏捷 +5    | +0  | … | +75 |

等级档位 **F- / F / F+ / D- / D / D+ / C- / C / C+ / B- / B / B+ / A- / A / A+ / S**，共 16 档，
技能值 0 ~ 1000（F- 为第 0 档，S 为第 15 档）。显示样式复用游戏自身的 `<<characteristic-box>>`
（等级字母、配色、百分比进度条、汉化后的等级文字全部自动一致）。

| 档位 | F- | F | F+ | D- | D | D+ | C- | C | C+ | B- | B | B+ | A- | A | A+ | S |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 技能值 | 0 | 67 | 133 | 200 | 267 | 333 | 400 | 467 | 533 | 600 | 667 | 733 | 800 | 867 | 933 | 1000 |
| 攻击力 | +0 | +5 | +10 | +15 | +20 | +25 | +30 | +35 | +40 | +45 | +50 | +55 | +60 | +65 | +70 | +75 |
| 防御力 | +0 | +5 | +10 | +15 | +20 | +25 | +30 | +35 | +40 | +45 | +50 | +55 | +60 | +65 | +70 | +75 |
| 敏捷 | +0 | +5 | +10 | +15 | +20 | +25 | +30 | +35 | +40 | +45 | +50 | +55 | +60 | +65 | +70 | +75 |

## 数据（存档字段）

| 变量 | 含义 |
|---|---|
| `$combatSkills` | `{ attack, defense, agility }`，0 ~ 1000，**保存在存档里** |
| `$combatBonus`  | `{ attack, defense, agility }`，由档位换算出的加成；战斗公式与面板都调用 `<<combatStatSync>>` 刷新 |

两个变量都在第一次渲染时惰性初始化：**新档、旧档都安全**。
v1.2.0 及更早的存档里第三项叫 `dodge`，载入时会**自动迁移**成 `agility`（原值保留）。

## 战斗成长

五处挂钩全部走 `TweeReplacer`，锚点均为**代码/注释**（不含英文文本，不受汉化影响）：

| 事件 | 经验 | 挂点（段落 / 锚点） |
|---|---|---|
| 攻击敌人 | **攻击 +1 点** | `Widgets` / `<<set _defiance to (_args[0] * (1 + ($sadism / 1000)))>>` —— `defiance` 是玩家对敌人造成伤害的统一结算宏（全游戏 78 处调用） |
| 被击中 | **防御 +1 点、敏捷 +1 点** | `Widgets` / `<<widget "hitstat">>` 定义内 —— `hitstat` 是玩家被打中的统一计数器（133 处调用） |
| 被怪物扑袭 | **防御 +1 点、敏捷 +1 点** | `Widgets Struggle` / `<!-- lurkers attacc -->` —— struggle 系统里每次怪物发起攻击的入口 |
| 敏捷判定成功 | **敏捷 +10 点** | `Widgets Struggle` / `<<set $dodging -= 1>>` —— `$dodging` + `_doge_chance gte _hit_chance` 判定成功分支内（「dodging it.」与「narrowly dodging it.」都算） |
| 攻击力 → 伤害 | — | `Widgets` / `<<set _thedamage to (2 * _defiance * ($physique / 4000))>>`（见下节） |

> 关于敏捷判定：本 build 的闪避/躲避判定只存在于 **struggle（怪物缠斗）** 系统
> （`$feetaction is "evade"` → `$dodging`，进入战斗时默认就是 evade/guard）。
> 人类 NPC 战斗（`Widgets Combat Man-Combat`）与野兽/触手战斗没有躲避判定，
> 但那些场合的 舞蹈/运动/游泳/足部 判定同样吃敏捷加成（见下节）。

## 战利品掉落（v1.4.0；v1.6.0 修正 1v1 不触发；v1.7.0 加结束面板）

**两个挂钩**，都调用同一个 `combatLootDrop`，并按 NPC 上的 `.looted` 标记**幂等**（不会重复发）：

| # | 挂钩 | 覆盖 |
|---|---|---|
| ① | 段落 `Widgets NPC Damage` 的 `<<widget "defeatnpc">>`：「… staggers back, defeated.」之后 → `<<combatLootDrop _i>>` | 多敌人战斗里每倒下一个 NPC 立刻结算 |
| ② | 段落 `Widgets End Combat` 的 `<<widget "endcombat">>` 开头 → `<<combatLootVictory>>`（内部检查 `$enemyhealth lte 0`） | **1v1 单挑**（以及多敌人战斗的收尾兜底） |

> 为什么需要 ②：`defeatnpc` 全游戏只有 3 处调用，**全部被 `<<if $enemyno gte 2>>` 守卫**；
> 单挑时敌人是由 `$enemyhealth` 归零 → `endcombat` 结束的，永远不经过 `defeatnpc`。
> 所以 v1.4.0/1.5.0 在普通单挑里不会掉落 —— v1.6.0 已修正。

| 对象 | 掉落 | 概率 | 内容 |
|---|---|---|---|
| 人类 NPC（`$NPCList[_i].type is "man"`） | 钱 | **65%** | £10 ~ £30，走游戏自身的 `<<money … "thievery">>` 接口（会计入游戏的收入来源统计） |
| 人类 NPC | 物品 | **30%** | 从下方物品池随机一件 |
| 非人类 NPC（beast / plant / tentacles 等） | 身上的物品 | **45%** | 同一个物品池（设定上是「前一个受害者留在它身上的东西」） |

物品池（`combatLootItem`，改掉落只改这一个 widget）：

| 概率 | 内容 | 用到的游戏字段 |
|---|---|---|
| 45% | 未拆封的避孕套 ×1~2 | `$condoms`（游戏侧边栏会实时显示数量） |
| 30% | 胡椒喷雾 +1 格 | `<<spray 1>>`（仅在**已拥有喷雾罐且未补满**时才会出；否则自动转为下一项） |
| 25% | 零钱 £5 ~ £15（记为赃款） | `$blackmoney` |

## 战斗结束界面的「战利品」面板（v1.7.0）

每次掉落除了在击败瞬间显示一行绿字，还会记进本场战斗的清单 `$combatLootLog`；
战斗结束时由 `<<combatLootSummary>>` 渲染成一块面板，列出**本场获得的每一样东西**，
并给出**现金 / 赃款合计**，随后清空清单：

```
┌───────────────────────────────┐
│ 战利品                        │
│ 本场战斗的收获：              │
│  · 现金　£18                  │
│  · 物品　2 个未拆封的避孕套    │
│  · 赃款　£9 零钱（赃款）      │
│ 合计：现金 £18，赃款 £9        │
└───────────────────────────────┘
```

| 组成 | 实现 |
|---|---|
| 记录 | `<<combatLootLogAdd 分类 文案 键 金额>>` → 写入 `$combatLootLog`（本场临时清单） |
| 显示 | `<<combatLootSummary>>`，挂在 `endcombat`（战斗结束界面）上；胜负都会显示已记录的内容 |
| 清空 | 显示后立即清空；另外战斗开始时 `<<combatLootClear>>`（挂在 `combatinit` 上）也会清空，绝不串场 |
| 样式 | mod 自带 `CombatSkills.css`（走 `styleFileList`），选择器**全部限定在 `#combatLootSummary`**，配色沿用游戏调色板变量 |

- 想让击败瞬间**不再刷绿字、只在结束面板汇总**：控制台执行
  `SugarCube.State.variables.combatLootInline = false;`（默认 `true` 两边都显示）。
- 面板是纯文本 + 列表，无按钮、无点击事件，不影响战斗流程与存读档。

## 拳击俱乐部（v1.8.0 起；v1.9.0 修疼痛显示+训练加运动经验；v1.10.0 训练收 £20 并修正货币单位）

在**康努达塔斯街**的「Places of interest」列表里新增一个入口（插在「偷窃」入口之前）：

```
拳击俱乐部
```

**入口不消耗时间**；点进去是俱乐部大厅 `Boxing Club`，有四个去处：

| 去处 | 时间 | 效果 |
|---|---|---|
| 当陪练挣钱 `Boxing Club Spar` | **0:30** | **攻击 +1、防御 +2、敏捷 +1**（本 mod 的战斗属性）+ **意志 +1**（游戏核心技能 `<<willpower 1>>`）；**疼痛** `10~25`（`<<pain>>` + `<<gpain>>` 指示器）；£20~40（走游戏 `<<money>>`，来源记为 `boxingClub`）；体能 +4、疲劳 +10、压力 −6；三段随机对手文本 |
| 拳击训练 `Boxing Club Training` | **0:20 + £20** | **攻击 +2、敏捷 +1**；**运动（athletics）+5 点经验**（`<<gathletics>><<athletics 5>>`，结算行会显示当前 `$athletics` 值方便核对）；体能 +6、疲劳 +8、压力 −4；**学费 £20**（钱不够时大厅只显示提示，不会进入训练段落）；三段随机训练文本 |
| 更衣室 `Boxing Club Changing Room` | **0:01** | 可打开游戏自带的衣柜（`Changing Room`，通过 `$wardrobeExit` 返回本段落）、去淋浴间、回大厅 |
| 浴室和淋浴间 `Boxing Club Shower` | **0:01** | 随机冷水/热水文本 + `<<wash>>` 洗净；可去更衣室或回大厅 |

- 属性成长直接复用本 mod 的 `<<combatStatAdd>>`，所以**俱乐部练出来的点数会实时反映到「特征」面板的战斗技能区块**；
  运动经验走游戏自己的 `<<athletics>>` 宏，会体现在特征面板的「运动」技能框与技能判定里。
- 所有数值变动都配了游戏的变动指示器（`<<gpain>>` / `<<gphysique>>` / `<<gtiredness>>` / `<<lstress>>` / `<<gathletics>>`），
  侧边栏会显示红/绿箭头，不会出现「改了但看不出」。
- **宽容模式（soft）**：游戏的 `painClamp()` 会在该模式下把 `$pain` 强制归零，
  所以陪练段落会直接显示「（宽容模式：疼痛被禁用，本场只记疲劳。）」，而不是假装加了疼痛。
- 陪练的疼痛会被**防御力减免**（每 1 点 −1%），防御越高越耐打——这是本 mod 数值接入的自然联动。
- **货币单位提醒**：DoL 的 `$money` 以**便士**存储（`£1 = 100`，官方 `Labour value: £10` 对应 `<<money 1000>>`）。
  本 mod 所有金额都按这个单位写：训练费 `2000`（£20）、陪练收入 `2000~4000`（£20~40）、
  掉落现金 `1000~3000`（£10~30）、赃款 `500~1500`（£5~15）；显示时统一 `<<print (值 / 100)>>`。
- 只新增一个惰性初始化的计数 `$boxingClub = { spars, sessions }`（用于大厅台词变化），其余全部走游戏原有系统。
- 更衣室的衣柜用的是游戏自己的 `Changing Room` 段落，退出链接通过 `$wardrobeExit` 指回更衣室，不会把玩家丢到别处。

## 丰收街酒吧斗殴（v1.11.0）

在**丰收街（Harvest Street）酒吧 `Pub`** 的常驻链接列表里新增一条（插在「Look for someone else」之后，只在正常酒吧界面出现）：

```
斗殴 (0:05)
```

点进去是约战段落 `Pub Brawl`：酒吧角落腾出空地，一个随机路人向你叫阵；接受后进入 `Pub Brawl Fight`。

| 环节 | 内容 |
|---|---|
| 对手 | `<<generate1>><<person1>>` 生成一个随机人类 NPC（性别/体型随机），`<<maninit>>` 走游戏原生战斗初始化——所以是**完整战斗系统**：出拳、挨打、喝酒壮胆、逃跑等动作全都能用 |
| 难度 | `$pubBrawlWins` 记录胜场，每赢一场对手最大生命 +25（最多 +200），越打越硬 |
| 时间 | 入场 0:05 |
| 赢 | 彩头 **£5~15**（`<<money>>`，来源记 `pubBrawl`）、体能 +2、压力 −6、创伤 −3；本场**不触发战利品**（喝酒打架不是抢劫） |
| 输（被打倒） | **被保镖拖出侧门丢到丰收街**：压力 +12、创伤 +6、疼痛 +10，过 0:10，落在 `Harvest Street` |
| 敌方高潮 | 对手分神退开，斗殴不了了之，你可以回酒吧（不判负） |

- 判负条件沿用游戏自己的战斗退出条件：`_combatend or ($pain gte 100 and $willpowerpain is 0)`。
- 战斗里打出的拳、挨的打都会经过本 mod 的成长钩子（`defiance` / `hitstat`），所以**攻击 / 防御 / 敏捷会顺带涨**，防御力还会减免挨打的疼痛——练拳和斗殴互相喂。
- 只新增一个惰性初始化的计数 `$pubBrawlWins`，其余全用游戏原有系统。
- **入口锚点是纯代码**（`<<if C.npc.Gwylan.state is "scorned">>`）：v1.11.0 最初用的是含英文界面文字的锚点
  （`Look for someone else (0:01)`），而汉化 mod 会在本 mod 之后替换这些英文，导致 `TweeReplacer` 找不到锚点
  而**静默跳过整条补丁**（表现为酒吧里没有斗殴入口）。v1.11.1 已全部改用纯代码锚点，构建时也会拒绝含界面文字的锚点。
- **确认加载版本**：看「特征」面板最底部（`CombatSkills mod v1.11.1`），
  或 F12 控制台里的 `[CombatSkills] v1.11.1 已加载：…`。两个都没有 = 浏览器还在用旧版 mod。
### 已修：`le` 不是 SugarCube 运算符（v1.11.2）

v1.4.0~v1.11.1 的 `combatLootItem` 里写的是：

```
<<if _clRoll le 45>>          ← 错：SugarCube 没有 le 运算符
<<elseif _clRoll le 75 ...>>  ← 错
```

运行时会在 `<<endcombat>>` 里抛
`bad conditional expression in <<if>> clause: SyntaxError: Unexpected identifier 'le'`，
表现为**战斗结束时报错**（而且所有「掉物品」分支其实从没成功执行过）。

SugarCube 只认 `lt` / `lte` / `gt` / `gte` / `eq` / `neq`（游戏自身也没用过 `le`/`ge`/`ne`）。
v1.11.2 已改成 `lte`，并在构建脚本里加了运算符白名单校验：以后再写出 `le`/`ge`/`ne` 会**直接构建失败**。
### 其他 mod 引用了 0.5.11.9 里不存在的宏（v1.11.3 起兜底）

典型报错：

```
0.5.11.9 出错 (:: Lake Fishing Rock): macro <<askicon>> does not exist
```

- `askicon` **不是本 mod 引入的**（本 mod 源码里 0 次出现），0.5.11.9 原版也没有 `<<askicon>>`
  （原版只有 `baskicon`、`mysteryicon`（用的就是 `ask.png`）、`socialiseicon "ask"`）；
- 说明有**其它已安装的 mod**（多半是汉化/内容 mod，可能对应更新的游戏版本）改写该段落文本，
  引用了这一版游戏没有的宏；
- v1.11.3 起本 mod 额外定义了 `<<widget "askicon">>`（渲染原版资源 `ask.png`）做兜底，
  这类段落不会再整段报错，图标也能正常显示；
- 想知道是哪个 mod 干的：控制台执行 `window.modUtils.getModListNameNoAlias()` 看已装模组列表；
- 若还遇到别的 `<<xxxicon>>` 不存在，把宏名发我，可在同一处继续补兜底。
## 战斗动作：反剪双臂（v1.12.0）

战斗界面里，**左手 / 右手动作列表**各多出一个动作：

```
反剪双臂
```

| 项目 | 内容 |
|---|---|
| 出现条件 | 处于战斗中（`$combat is 1`）、位置不是 stalk、敌人是**人类（man）或野兽（beast）**、对应那只手空闲（`$leftarm`/`$rightarm` 为 0） |
| 判定 | **力量（physique）**：成功率 = `25 + 力量/10 − 敌人愤怒/8`，限制在 10%~90% |
| 成功 | 把对方双臂反剪到背后：NPC 双手置为游戏自带的 `"handhold"` 状态（= 被玩家握住）→ 对方所有用手类动作被阻塞；伤害 6、愤怒 +20、信任 −10；**按住 2 回合** |
| 按住期间 | 动作变成 **「继续压制」**：伤害 8、愤怒 +15，并把按住回合数刷新回 2（可以一直压着打） |
| 到期 | 自动放开，提示「对方猛地一挣，终于从你的钳制中脱开」 |
| 失败 | 被反制：疼痛 4、对方愤怒 +10 |
| 野兽 | 同样可用，文案改成「死死抱住它，把它的前肢别到背后」 |

实现方式（全部用游戏自身的动作系统，没有另造 UI）：

- **注册**：补丁把 `<<combatReversePinRegister "left">>` / `"right"` 插到段落 `Widgets Actions Generation` 里
  `leftActions` / `rightActions` 的 `_leftaction` / `_rightaction` 重置之后，动作键为 `reversePinArms` / `reversePinPress`；
- **结算**：补丁把 `<<combatReversePin>>` 插到段落 `Widgets Effects Man` 的 `effectsman` 开头，
  每回合先维护按住状态，再消费选中的动作（会清掉 `$leftaction`/`$rightaction` 并恢复默认动作）；
- 动作的可见效果与动画都沿用游戏机制（`<<stateman>>` 的血条、动作列表的变色），不额外加 CSS。
## 掉落判定与边界

- 判定「胜利」的标准是 `$enemyhealth lte 0`（把对方打到失去战斗力）。
  **靠兴奋/高潮结束的战斗不会掉落**（那不算击败，游戏走的是另一条结束分支）；如需覆盖可以再加挂钩。
- **衣物**：击败**人类** NPC 时另有 **40%** 概率扒下对方身上剩下的衣物（上衣或下装二选一）：
  先把 NPC 的简化衣物名转换成玩家可穿戴的同名衣物（`dist/CombatSkillsPatch.js` 的
  `window.CombatSkills_lootClothes`，别名表在 `dist/CombatSkillsClothes.js`，覆盖 92% 的 NPC 衣物名，
  其余退化为不加衣物），再按对方那件衣服的耐久度复制一件放进**衣柜**，并把对方那一格置为 naked。
  掉落在绿色提示里显示、也会进战利品面板（分类「衣物」，中文名优先用汉化 mod 提供的 `cn_name`）。
- 人类判定：本 build 里 `$NPCList[i].type` 对人类是 **`"human"`**（部分命名 NPC 可能是 `"man"`），
  所以判定同时看 `type` 与 `$enemytype`；v1.10.1 之前只认 `"man"`，导致人类敌人一直被当成野兽（只掉物品、不掉钱）。
- 全部使用游戏原有的宏与变量，**没有新增长期存档字段**（只有本场战斗的 `.looted` 标记与 `$combatLootLog` 清单，
  战斗开始时清空、`$NPCList` 在下一场战斗重建）。
- 概率与金额都是各自 widget 里的字面量，构建脚本会断言这些接口写法存在（防止改坏）。
- 已知未覆盖：纯 struggle 系统里的生物（lurker / 史莱姆等，走 `$struggle` 而不走 `$NPCList`）不会触发掉落，
  因为它们的胜利结算没有 `defeatnpc` 这样的统一入口；如需覆盖要单独挂到 `Struggle End` 上。

## 排错：战斗结束报错时

v1.10.1 起，胜利结算会在浏览器控制台留两条面包屑（只在打赢时输出）：

```
[CombatSkills] 战利品结算开始 {...enemyhealth/enemynomax/npcCount...}
[CombatSkills] 战利品结算完成 [...本场清单...]
```

排查步骤：

1. 按 **F12 → Console**，把红色报错连同这两行面包屑一起复制出来；
2. 若只有「开始」没有「完成」→ 错误在掉落逻辑内部（把报错发我即可精确定位）；
3. 若两行都在、错误在其后 → 不是战利品代码，是战斗结束段落本身（游戏/汉化 mod）的问题；
4. 两行都不在 → 我们的钩子根本没执行（可能在钩子之前就报错了）。

同时 v1.10.1 给所有战利品代码加了防御性判断（`$NPCList`、`$enemynomax`、`$combatLootLog`、`$enemyhealth`
的缺失/类型异常都会被跳过而不是抛错），因为 `<<endcombat>>` 在全游戏有近 3000 处调用，其中大量与 NPC 战斗无关。

## 数值接入

| 属性 | 效果 | 挂点 | 实现 |
|---|---|---|---|
| 攻击力 | **每 1 点 = +1% 造成伤害**（满级 +75 点 → +75% 伤害） | `Widgets` / `defiance` 的 `_thedamage` 公式 | `TweeReplacer` 改成 `… * (1 + ($combatBonus.attack / 100))` |
| 防御力 | **每 1 点 = −1% 受到伤害**（满级 +75 点 → −75%，上限 −90%） | JS 宏 `pain(amount, modifier = 4)` | mod 自带脚本包装该宏：`modifier *= (1 − 防御力/100)` |
| 敏捷 | **每 1 点直接计入判定** | JS 全局 `window.currentSkillValue(skill, disableModifiers)` | mod 自带脚本包装它：对 舞蹈 / 运动 / 游泳 / 足部 额外加上 `$combatBonus.agility` |

### 敏捷为什么这么接（v1.3.0）

游戏读取技能值的统一入口是 `window.currentSkillValue(...)`（全游戏 **1281 处**调用，
`<<athleticsdifficulty>>` → `<<skill_difficulty currentSkillValue('athletics') …>>`、
缠斗里的 `currentSkillValue("feetskill") / 3 + currentSkillValue('danceskill') / 3` 都走它），
所以「像舞蹈那样参与事件判定」= 包装它：

```js
var AGILITY_SKILLS = ["danceskill", "athletics", "swimmingskill", "feetskill"];
var orig = window.currentSkillValue;
window.currentSkillValue = function (skill, disableModifiers) {
    var base = orig.apply(this, arguments);
    if (!disableModifiers && AGILITY_SKILLS.indexOf(skill) !== -1) {
        return base + 敏捷;          // 只加在查询结果上
    }
    return base;
};
```

- **不改存档变量**：只影响查询返回值，`$danceskill` / `$athletics` 本身不变。
- **特征面板不会被虚高**：面板的技能框用的是 `$danceskill` / `$athletics` 原值，不经过这个函数。
- **不干扰游戏内部取原值**：`disableModifiers` 非 0 的内部调用（游戏自己用来拿未修正值）保持原样。
- 想增减受影响技能，只改脚本里的 `AGILITY_SKILLS` 一行；构建脚本会断言这些技能名在游戏里存在。

### 防御力为什么用 JS 包装而不是改文件

玩家受伤的唯一统一入口是 JS 宏 `pain`（全游戏 **1428 处** `<<pain …>>` 调用），
而它定义在游戏的 JS 里、twee 层没有共同出口。本 mod 用 ModLoader 的
`scriptFileList_inject_early: dist/CombatSkillsPatch.js` + `scriptFileList: dist/js/installCombatSkillsPatch.js`
注入自己的脚本，按本 build 里已验证的写法（DoLLinkButtonFilter 同款）包一层：

```js
const def = Macro.get("pain");
Macro.delete("pain");
Macro.add("pain", { isWidget: def.isWidget, tags: def.tags, handler() {
    this.args[1] = (this.args[1] ?? 4) * (1 - 防御力 / 100);   // 只缩放 modifier，保留原 amount
    return orig.apply(this, arguments);
}});
```

- 若 `pain` / `currentSkillValue` 比脚本更晚就位，会以 250ms × 60 次轮询等待（最多 15 秒）。
- 面板没打开过、`$combatBonus` 还没算时，脚本会直接用 `$combatSkills` 兜底换算
  （档位表与 twee 完全一致，构建脚本会做一致性断言）。
- 只减 `pain`（伤害），不动 `$violence`（暴力值）与 `$stress` / `$trauma`；也不动 `pain` 内的
  masochism 兴奋计算，因为缩放的是 `modifier` 而不是 `amount`。
- 控制台自查：`window.CombatSkills_debug()` → 返回当前属性、加成、减伤比例、敏捷样本值，
  以及 `painPatched` / `skillValuePatched` 两个接管标志（都应为 `true`）。

## 接口（供剧情 / 其他 mod / 控制台使用）

```
<<combatStatAdd "agility" 10>>   /* 直接加属性值：敏捷 +10 点（0 ~ 1000） */
<<combatStatExp "attack" 3>>     /* 按经验加：内部 ×5（与游戏 prof() 同算法）→ +15 点 */
<<combatStatSet "attack" 500>>   /* 直接把攻击设为 500（调试用） */
<<combatStatSync>>               /* 依据 $combatSkills 刷新 $combatBonus（战斗公式会调它） */
<<combatStatBoxes>>              /* 渲染战斗技能区块（本 mod 已插入到特征面板） */
```

三个接口都同时接受旧名 `"dodge"`（自动当作 `"agility"`）。控制台等价写法：

```js
SugarCube.State.variables.combatSkills.agility = 800;   // 敏捷 → S 级（+75）
window.CombatSkills_debug();                            // 查看接管状态
```

## 实现方式

- 对段落 `Characteristics` 做**一次字符串插入**（界面区块），对 `Widgets` / `Widgets Struggle` / `Widgets NPC Damage`
  / `Widgets End Combat` / `Widgets NPCs` / `Connudatus Street` / `Pub` 做 10 处**代码级插入/替换**
  （成长 + 攻击力接入 + 战利品掉落 + 拳击俱乐部入口 + 酒吧斗殴入口），全部由 `TweeReplacer` 完成；
  界面插入点锚定在 `$prof.pickaxe` 注释块 + `#prof` / `#characteristics-display` 的闭合标签之后。
  锚点均为纯代码/注释/缩进、不含英文文本，因此**不受汉化 mod 的逐字符串替换影响**。
- 防御力减伤、敏捷接入走 mod 自带的两个 JS 脚本，由 ModLoader 注入并包装
  `pain` 宏与 `window.currentSkillValue`；**不修改游戏自身的任何 JS/HTML 文件**。
- 战利品结束面板的样式走 mod 自带的 `CombatSkills.css`（boot.json 的 `styleFileList`），
  选择器全部限定在 `#combatLootSummary`，不动游戏原有样式。
- 不覆盖任何原版段落。

## 安装 / 卸载

**安装（二选一，都不改动任何游戏文件）**

1. 游戏内：ModLoader 界面 → 添加 zip → 选 `CombatSkills_v1.13.1.zip`（存入浏览器 IndexedDB，和汉化/图包同方式）。
2. 网站自动加载：把 `CombatSkills_v1.13.1.zip` 与 `modList.json` 放在 `Degrees of Lewdity.html` 同级目录，
   通过 http 访问游戏时 ModLoader 的 RemoteLoader 会自动读取 `modList.json`（`file://` 打开不生效）。

**卸载**：删除 `modList.json`（或其中的条目）/ 在 ModLoader 界面移除本 mod 即可，游戏完全恢复原状
（`pain` 宏与 `currentSkillValue` 的包装都只存在于内存中，mod 不加载即不存在）。

## 构建

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force   # PS 5.1 需要
& .\modsrc\build.ps1
```

脚本会：① 从 `Degrees of Lewdity.html` 提取相关段落原文；
② **断言 14 个锚点各自恰好出现 1 次**（版本不符立即中止，不产出任何文件）；
③ 用 `node --check` 校验两个 JS 补丁；断言 JS 档位表与 twee 档位表一致、
   每档系数 JS/Twee 一致、`AGILITY_SKILLS` 里的技能名在游戏里存在、
   且游戏 HTML 里确实有 `window.currentSkillValue` 赋值（包装点存在）；
④ 生成 `boot.json`；⑤ 打包 zip（条目强制正斜杠）并校验必需条目；⑥ 生成/合并 `modList.json`；
⑦ 输出 HTML / boot.json 的 SHA256 前后比对，证明游戏文件零改动。

## 已知边界（有意为之）

- 防御力只减 **pain（伤害）**：不减 `$violence`（暴力值）、`$stress`、`$trauma`。
- 敏捷的躲避收益只体现在 **struggle（怪物缠斗）** 的躲避判定上（那里用 feetskill + danceskill，
  两者都在白名单内，因此敏捷按 2/3 折算进 `_doge_chance`）。
- 减伤上限 90%（脚本常量 `MAX_REDUCTION`）。
- 攻击力是**乘算**（+1% 伤害/点）；想改成加算（固定伤害 +N/点），只需改 `build.ps1` 里
  「攻击力 → 造成伤害」那条 `replace` 语句。

## 后续可选项

- 把防御力也接到 `$violence`（暴力值）与创伤/压力上——目前只减 `pain`。
- 给人类 NPC 战斗补一套躲避判定（要挂到 `Widgets Combat Man-Combat` 的攻击结算，改动面较大）。
- 调整 `AGILITY_SKILLS` 白名单（例如加入 `skulduggery` 诡术，让敏捷也帮偷窃/开锁）。
- 攻击力改成加算，或给每点系数换个数值（改 `build.ps1` 的对应 `replace`）。
- 战利品：调概率/金额（`combatLootHuman` / `combatLootCreature` / `combatLootItem`），
  或把纯 struggle 生物（lurker / 史莱姆）也纳入掉落（需挂到 `Struggle End`）。

## 兼容性：特征面板消失 / TweeReplacer 报 cannot find findString（v1.13.1 修复）

某些 mod（「原版优化」「Maplebirch Framework」或改动界面的整合包）会改写 `Characteristics`
或战斗文本段落，导致本 mod 的段落锚点对不上，后果是：

- 「特征」页面里的**整个战斗技能栏消失**（界面插入补丁失败）
- 多敌人击败时**不掉战利品**（战利品插入补丁失败）

v1.13.1 起：

1. **战利品锚点改为纯代码** `<<widget "defeatnpc">>`，不再依赖英文战斗文本
2. **特征面板增加 JS 兜底注入**：即使 TweeReplacer 的界面锚点失效，打开「特征」页面时
   也会把「战斗技能」区块插入到武器技能（`#prof`）下方，并在控制台打印
   `[CombatSkills] 界面锚点失效，已用 JS 兜底注入「战斗技能」面板`
3. 如果加载日志里仍有一条 Characteristics 的 `cannot find findString`，**可以忽略**：
   功能已由 JS 兜底接管（正常环境不会触发兜底，也不会有这条日志）

排查：控制台执行 `CombatSkills_debug()` 应能看到 `combatSkills` / `combatBonus` 数据。

## 汉化兼容（v1.12.3 起；v1.13.1 增强）

如果汉化 mod（ModI18N / I18nTweeList / I18nScriptList / I18nTweeReplacer）**没装全或脚本加载失败**，
游戏里会出现这种报错：

```
:: Temple Garden Wolf: <<beast>>: errors within widget code
(<<=>>: bad evaluation: TypeError: setup.NPC_CN_TYPE is not a function)
```

原因：`setup.NPC_CN_TYPE` 是**汉化 mod 提供的函数**（原版游戏里没有），
汉化的 `<<beast>>` widget 补丁会调用它；汉化脚本没加载时函数就不存在。

v1.13.1 起本 mod 的安装脚本会做**兜底**：只在 `setup.NPC_CN_TYPE` 缺失时补一个最小实现，
报错不再刷屏（控制台会打印一条 `[CombatSkills] ... 已临时兜底` 警告），
汉化正常时不会覆盖真函数、中文名照常显示。
**根治方法仍是把汉化装全/重装汉化。**

