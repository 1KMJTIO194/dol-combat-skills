# DoL 战斗技能 CombatSkills

《Degrees of Lewdity》（DoL）的 **ModLoader 模组**：给游戏加一套「战斗属性 + 战斗内容」扩展，
**不修改任何游戏文件**，全部通过 ModLoader 的段落替换（TweeReplacer）与脚本注入实现。

> 适配版本：**DoL 0.5.11.9**（其它版本锚点可能对不上，构建脚本会拒绝打包）
> 语言：中文（模组自带文案，不走汉化表）· 许可：MIT（代码）

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

1. 从 [Releases](../../releases) 下载 `CombatSkills_v1.12.1.zip`
2. 游戏内 ModLoader → 添加 zip → 选择该文件
3. 刷新页面；打开「特征」面板，最底部显示 `CombatSkills mod v1.12.1` 即成功

**卸载**：ModLoader 里移除即可，游戏文件零改动、完全恢复原状。

## 目录结构

```
build.ps1                    构建脚本（提取段落、断言锚点、打包 zip、生成 modList.json）
CombatSkills/                mod 源（zip 内容）
  boot.json                  ModLoader 清单（tweeFileList / scriptFileList / addonPlugin）
  twee/CombatSkills.tw       全部 widget 与新增段落（拳击俱乐部、酒吧斗殴）
  dist/CombatSkillsPatch.js  JS 补丁：pain 减伤、currentSkillValue 敏捷接入、战利品衣物转换
  dist/CombatSkillsClothes.js NPC 衣物名 → 玩家衣物 别名表（覆盖 92%）
  dist/js/installCombatSkillsPatch.js
  CombatSkills.css           战利品面板样式（选择器全部限定在 #combatLootSummary）
  README.md                  详细文档（中文）
docs/发布说明.md              发布帖草稿（作者/反馈/合规说明）
tools/decode-save.js         调试工具：解压 DoL 存档（lz-string）查看变量
tools/check-clothes-map.js   开发工具：统计 NPC 衣物名→玩家衣物的匹配覆盖率
tools/suggest-clothes-alias.js  开发工具：为未匹配的 NPC 衣物名推荐玩家衣物名
```

## 构建

需要 **DoL 0.5.11.9 的 `Degrees of Lewdity.html`** 与 **Node.js**（用于 `node --check`）：

```powershell
# 目录结构：
#   <game>/Degrees of Lewdity.html
#   <game>/build.ps1
#   <game>/CombatSkills/...
Set-ExecutionPolicy -Scope Process Bypass -Force
pwsh -File .\build.ps1
```

脚本会：从游戏 HTML 提取段落 → **断言 14 个锚点各出现 1 次**（版本不符立即中止）→
校验 JS 与 twee 的档位/系数一致 → 生成 `boot.json` → 打包 zip → 生成 `modList.json` →
输出游戏 HTML 与 `boot.json` 的 SHA256 前后比对，证明**游戏文件零改动**。

## 兼容性

- 与汉化 mod 兼容：所有补丁锚点都是**纯代码**，不依赖英文界面文本
- 遇到别的 mod 引用不存在的 `<<askicon>>` 时提供兼容兜底（v1.11.3+）
- 仅适配 0.5.11.9；其它版本请勿直接使用

## 反馈

- 反馈请附：**mod 版本号**（游戏内「特征」面板最底部）+ **F12 控制台里 `[CombatSkills]` 开头的行 / 红色报错**
- 也可在发布帖回复

## 版权

- 本模组为**非官方**作品，《Degrees of Lewdity》版权归 **Vrelnir** 所有，请支持正版
- 本仓库代码与文案原创，MIT 许可；**禁止商用**，转载/二创请注明作者与仓库地址
- 不包含任何游戏本体资源
