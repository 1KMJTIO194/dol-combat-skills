# CombatActionsExt（战斗中性行为扩展）

《Degrees of Lewdity》ModLoader 模组：在战斗动作列表里增加 **4 组针对敌人胸部/肛门的性行为动作**。

> 适配 **DoL 0.5.12.13** · 需要 ModLoader + **TweeReplacer** · 不修改任何游戏文件
> 这是 NSFW 内容扩展，与主 mod `CombatSkills` 相互独立（可单独启用/禁用）。

## 动作（v0.4.0 起支持普通战斗，v0.8.0 增加小穴/持续脚部/原版脱衣）

| 动作 | 用手/脚 | 部位 | 出现条件 |
|---|---|---|
| 「咬」 | 嘴 | 敌人（人类或野兽） | 嘴自由（`$mouthuse is 0`）且没被捂住/塞住（脸无 `face_covering`/`gag`） |
| 「脱掉上衣」 | 左手 / 右手 | 对方上衣 | 对方 `chest is "clothed"`（同原版 Undress）→ 原版判定 + `npcUndressText`/`npcRevealText` |
| 「脱掉下衣」 | 左手 / 右手 | 对方下衣 | 对方 `penis is "clothed"` 或 `vagina is "clothed"` → 成功后 penis/vagina 置 0 |
| 「揉捏胸部」 | 左手 / 右手 | 对方胸部 | `$NPCList[i].chest is 0`（上身裸露） |
| 「手指插入小穴」→「继续指奸（小穴）」→「拳交（小穴）」→「继续拳交（小穴）」 | 左手 / 右手 | 对方小穴 | 对方 `vagina is 0`（小穴已露且空着）；插入→继续指奸→拳交→继续拳交，动作名与文案都写明「小穴」 |
| 「手指插入肛门」→「继续指奸（肛门）」 | 左手 / 右手 | 对方肛门 | 对方下衣已脱；下身没被别的东西占着（占着只能失败） |
| 「拳交（肛门）」→「继续拳交（肛门）」 | 左手 / 右手 | 对方肛门 | **手指已插入**后出现；入口仍未被别的东西占着 |
| 「脚揉胸部」→「继续揉胸」 | 脚 | 对方胸部 | 玩家赤脚（`$worn.feet.type` 含 `"naked"`）+ 对方上身裸露；可持续 |
| 「脚趾插入」→「继续踩弄」 | 脚 | 对方肛门 | 玩家赤脚 + 对方下衣已脱；入口未占用 |

## v0.9.6：拳交不会被对方挤出

- 取消 v0.9.6 的「对方主动绞紧挤出」机制；现在**拳交（手指升级成整只拳头后）不会被对方挤出**
- 「继续拳交」判定失败时只是这一下没能抽动：对方会夹紧/收缩想要挤出，但拳头牢牢卡住，**拳交状态保持**
- 提示文案：
  - 小穴：「对方的小穴猛地一阵绞紧，想把你的**左手整只拳头**挤出来，但你的拳头牢牢卡在对方的小穴里，纹丝不动。」
  - 肛门：「对方的肠道猛地一阵收缩，想把你的**右手整只拳头**挤出来，但你的拳头牢牢卡在对方的肛门里，纹丝不动。」
- 只有玩家自己换动作 / 结束战斗时才会退出拳交（换动作会有明确的抽出提示）
- 手指阶段仍保留原先的判定（被夹出时会把手指挤出，文字写明部位）

实测（headless Chrome 真实运行时）：把 `combatSkillCheck` 强制为失败、连打 5 回合，小穴/肛门拳交状态都保持不被挤出，46/46 通过。

## v0.9.4：手部链条修复 + 明确显示插入部位## v0.9.4：手部链条修复 + 明确显示插入部位

**修复「拳交」永远失败**：以前每回合开头清理插入状态时只放行「继续指奸」，没有放行「拳交」那一步，
导致手指状态在拳交动作执行前就被清掉 → 拳交前置条件永远不满足。现在 `$leftaction isnot "caeHandFist"` /
`"caeHandVagFist"` 也放行（左右手都修）。

**动作名写明部位**（左右手同时插不同洞时不再混淆）：

| 环节 | 小穴链 | 肛门链 |
|---|---|---|
| 插入 | 手指插入小穴 | 手指插入肛门 |
| 继续 | 继续指奸（小穴） | 继续指奸（肛门） |
| 拳交 | 拳交（小穴） | 拳交（肛门） |
| 继续拳交 | 继续拳交（小穴） | 继续拳交（肛门） |

**文案写明「哪只手 + 什么部位 + 哪个洞」**：所有插入/继续/拳交/被挤出/换动作抽出的提示都写清
「左手/右手」「两根手指/整只手/拳头」「小穴/肛门」（不再用「体内」「那里」这类模糊说法）。
每回合结尾还会显示一行当前状态，例如：

> 现在：左手的拳头插在对方小穴里；右手的两根手指插在对方肛门里。

**实测**（headless Chrome 真实 SugarCube 运行时，42/42 通过）：
左右手注册标签、小穴链 4 步、肛门链 4 步、双手双洞同时进行、换动作后的明确抽出提示都正常。

## 嘴自由时也能咬（v0.5.0 新增，v0.6.0 归类与判定调整）

原版的「Bite」只在特定情况出现：敌人的手捂住你的嘴（`handbite`）、嘴里有阴茎/私处/胸部等。
嘴自由时普通战斗里没有咬的攻击选项。

本 mod 在嘴部动作列表里加了「**咬**」：

- 出现条件：战斗中、嘴自由（`$mouthuse is 0`）、脸没有被 `face_covering`/`gag` 遮住、
  非 stalk 位置（人类和野兽敌人都可用）
- **v0.6.0 起判定参考原版 `handbite`：必定咬到，没有失败判定**
  - 尖牙：`<<defiance 8>>`、`<<control 12>>`
  - 普通：`<<defiance 4>>`、`<<control 8>>`
  - 另有 1/4 概率追加一次重咬（再 +`defiance 8/4`、`control 5`）
  - `<<attackstat>>`、`$enemyanger +20`、`$enemytrust −8`
- **动作分类**：v0.6.0 把 `caeMouthBite` 补进了原版 `window.combatActionColours` 的
  `def`（反抗）分类，所以 UI 里会像原版 Bite 一样显示成**反抗行动**的红色，而不是白色。
  顺带把「扯掉上衣/下衣」归到 `brat`、「胸部/插入/拳交」归到 `sub`，与原版同类动作一致。
- 挂点：`<<widget "mouthActions">>` 的 `_mouthaction` 重置之后 → `<<combatActionsExtRegister "mouth">>`；
  结算在 effectsman 的 `<<combatActionsExt>>` 里消费 `$mouthaction`

## 战斗里脱对方的衣服（v0.4.0 新增，v0.8.0 改为原版 Undress 机制）

原版普通战斗里敌人是穿着衣服的，所以本 mod 的性行为动作原本只能在「对方已经裸露」时出现。
v0.8.0 起脱衣动作改为**参考原版性行为里的 `Undress:` 动作**（`leftUndressOther` / `rightUndressOther`）：

- 「**脱掉上衣**」：对方 `chest is "clothed"` 时出现
- 「**脱掉下衣**」：对方 `penis is "clothed"` 或 `vagina is "clothed"` 时出现
- 判定同原版：`combatSkillCheck("hand", 目标, 描述, 1000, 目标衣物.integrity)`（衣物越破越好脱）
- 成功：upper → `$_npc.chest = 0`；lower → `penis`/`vagina` 置 0；
  文本用原版的 `<<npcUndressText>>` / `<<npcRevealText>>` / `<<npcGenitalReaction>>` / `<<namedNpcReaction>>`
- 失败：目标衣物 `integrity -= floor(handskill/100)`（和原版一样，越脱越松）
- 不会改动对方的 `clothes` 记录（战利品「扒衣服」逻辑不受影响）

## 插入状态（v0.2.0 新增，v0.3.0 扩展拳交）

原版对 NPC 肛门**没有独立状态字段**——`$NPCList[i].anus` 的初始化处写着
`/* is not actually used anywhere */`，原版是用 NPC 的 `vagina` / `penis` 字段记录
「插进去的部件」（例如 `"leftDildoAnus"`）。本 mod 按同样的语义实现：

- **插入**：技能判定成功 → 记录 `$caeLeftAnus` / `$caeRightAnus` / `$caeFeetAnus`（记录插在哪个 NPC），
  动作列表变成「继续指奸」/「继续踩弄」
- **入口占用**：对方 `vagina`/`penis` 已被别的部件占着 → 插不进去（文本同原版
  “but the entrance is already occupied”）
- **继续**：每回合追加 `$enemyarousal`、技能成长与 `<<submission>>`
- **拳交**：手指插入后可继续把整只手塞进去（`$caeLeftFist` / `$caeRightFist`），成功后动作变「继续拳交」；失败只会卡在手腕、不会进入状态；被挤出来或换动作即退出
- **抽出**：判定失败被挤出来，或选择别的动作 → 自动清除状态并提示
- **战斗结束**：`endcombat` 钩子 `<<combatActionsExtClear>>` 清空，避免手/脚被永久占用
- 状态是 mod 自有变量，**不写 NPC 的 `vagina`/`penis` 字段**，避免与其它 mod / 原版状态机互相干扰

## 敌人高潮选择（v0.3.0 新增）

用过本 mod 动作的战斗里，把对方逼到高潮（`$enemyarousal gte $enemyarousalmax`）时**不再直接结束战斗**：

- 在 `<<widget "actionsman">>` 开头拦截（必须早于原版计算 `_combatend` 的那句）
- 把 `$enemyarousal` 降到一半（与原版 `setupMidOrgasm` 的「多次高潮」算法一致）
- 显示高潮提示，并在动作列表给出两个选项：
  - 「继续缠着」→ 清掉选项，战斗继续
  - 「结束战斗」→ 把 `$enemyhealth` 置 0，下一回合走原版胜利结算（战利品等照常）
- 只在「本场战斗用过本 mod 动作」时生效（`$caeFightUsed`），不影响纯净战斗和其它 mod 的战斗流程

所有动作还要求：战斗中（`$combat is 1`）、对方是人类（`$enemytype is "man"`）、非 stalk 位置、对应手/脚空闲、目标不是自己。

## 结算（参考原版）

- 用游戏自己的技能判定：`combatSkillCheck("hand"/"feet", 目标)`
- 成功：`<<submission>>`、`$enemyarousal` 上升、玩家 `<<arousal>>`、
  `<<handskilluse>>`/`<<feetskilluse>>`（涨对应性技能）、`<<handstat>>`/`<<feetstat>>`
- 自愿（`$consensual is 1`）：`$enemytrust +2`、`$enemyanger −5`，文案温和
- 非自愿：`$enemyanger +12~18`、`$enemytrust −5~8`，失败时会吃少量疼痛
- 失败：按自愿/非自愿给不同文本（被挡开 / 被拍开）

## 安装

1. 游戏内 ModLoader → 添加 zip → 选 `CombatActionsExt_v0.9.6.zip`
2. 刷新页面
3. 前置：ModLoader（0.5.x 自带）+ TweeReplacer

**卸载**：ModLoader 里移除即可；不影响 `CombatSkills` 主 mod。

## 已知边界

- 只做了人类敌人；野兽没有「胸部/肛门裸露」这组状态，未纳入
- 不做「持续按住/插入状态」（如原版 `vaginagrabrub` 那种 keep 动作），每次行动单独结算
- 肛门动作按「外部刺激 + 浅探」处理，没有引入原版的插入状态机（避免与其它 mod 的状态冲突）
- 肛门外露用的是「对方下衣已脱」的近似判断（游戏没有单独的 NPC 肛门暴露字段）

## 构建

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
Set-Location ..\      # modsrc 目录（含 build-actions.ps1 与 CombatActionsExt\）
pwsh -File .\build-actions.ps1
```

脚本会断言 7 个锚点唯一、校验 twee 语法与必需片段，生成 `boot.json`、打包 zip，
并把 `./CombatActionsExt_v<版本>.zip` 合并进 `modList.json`（保留其它条目），
最后校验 `Degrees of Lewdity.html` 与 `boot.json` 的 SHA256 未变。

## 声明

- 非官方模组，《Degrees of Lewdity》版权归 **Vrelnir** 所有，请支持正版
- 本 mod 只含自写代码与文本，不含任何游戏资源；免费发布、禁止商用
- 反馈：附 mod 版本号 + F12 控制台 `[CombatActionsExt]` 或报错原文
