# LocationsExt（旅店 & 公寓房间）

《Degrees of Lewdity》ModLoader 模组：在现有地图上增加**旅店**，并给**公寓楼（Barb Street 公寓）**增加一个**可购买的房间**。

> 适配 **DoL 0.5.12.13** · 需要 ModLoader + **TweeReplacer** · 不修改任何游戏文件

## 新增内容

| 地点 | 位置 | 功能 |
|---|---|---|
| **旅店** | High Street（商业街）的 **Alternate routes（快捷路线）** 区块，和商业小巷/公园/下水道并列 | £40 租**当天**的单间（`Inn Room` 二楼房间），房间结构与**孤儿院卧室/浴室**一致：睡下（原版 `<<sleep>>`）、**浴室 (0:01)**、**下楼 (0:01)**；**当天可自由进出**（前台直接「上楼回房间」），**隔天失效需重新付钱**；前台另有共用淋浴间（当天租客免费，否则 £5） |
| 旅店楼梯（拦路） | 前台「试着直接上楼」 | 没交当天房钱时走楼梯会被店员拦住要钱（贝利式）：付 £40 才能上楼；掏不出钱会被赶回前台并 +压力 |
| 旅店浴室 | 房间 → 浴室 (0:01) | **泡个澡 (0:30)**（原版 `<<strip>>` + 压力 −6 + 清洁）、**冲个澡 (0:10)**（`<<wash>>`）、原版 `<<personalUpkeep>>`（刷牙/修眉/染发等）、妊娠检测；**卧室 (0:01)**、**楼下 (0:01)** 返回 |
| **待售的房间** | Flats（Barb Street 的公寓楼，入口新增链接） | £62000 一次付清买下；买下后入口链接变成「回到自己的房间」 |
| **自己的房间** | 公寓楼走廊尽头 | 睡觉（同原版睡眠流程）、**衣柜**（自定义退出：关上衣柜回房间）、离开 |
| 房间升级 | 自己房间 → 「看看能添置什么」 | 舒适床垫 £300（睡觉额外 −100 压力、−1 trauma）／加装淋浴间 £200（解锁「洗个澡」）／二手书架 £150（每天可看书放松 −200 压力，0:30） |
| **森林快速旅行** | Forest（森林，林间页面底部新增链接） | 按原版数据列出各方向目的地与耗时，一键前往 |


## 旅店入住规则（v1.7.0）

- 前台租房时记录 **当天日期**：`$caeInnPaidDate = Time.date.year + "-" + Time.date.month + "-" + Time.date.day`
- **当天**：前台显示「上楼回房间（0:01）」，可自由进出、淋浴免费
- **隔天**：日期不匹配 → 不能免费上楼，前台重新显示租房按钮；走「试着直接上楼」会被店员拦下要 £40（参考贝利拦路），钱不够则被赶回前台（+5 压力）
- 睡在旅店跨夜后，第二天想再进房间需要重新付当天的房钱
- 状态变量：`$caeInnPaidDate`（当天的日期字符串）、`$caeInnPaidToday`（本次渲染时是否已付当天房钱）

## 森林快速旅行（v1.5.1：只限森林内 + 单一快速出林；修掉空标题）

在 **Forest**（森林）林间页面底部加「**快速旅行**」链接。旅行时间不再照抄固定的 0:10，而是按
原版森林的移动机制计算：

- 原版「快速前进」= 一次前进 **5 点森林深度**、耗时基础 **5 分钟**（穿高跟鞋时是「Hobble」，基础 **30 分钟**一次）
- **v1.4.0 起运动技能影响每步耗时**（参考原版海岸步道 Jog/Run 用 athletics 门槛分档的思路）：
  - 普通：`每步分钟 = max(2, 5 − floor(athletics / 250))`
    → 技能 0–249：5 分钟／250–499：4 分钟／500–749：3 分钟／750 以上：2 分钟
  - 高跟鞋（Hobble）：`每步分钟 = max(20, 30 − 2 × floor(athletics / 250))`
  - 页面顶部会显示当前运动技能值和实际每步耗时
- 快速旅行会显示：**当前位置深度**、每个目的地的**需要几次快速前进**、**总分钟数**
- 点击后直接按步数扣时间：`次数 = ceil(|目标深度 − 当前深度| / 5)`，`时间 = 次数 × 5`（高跟鞋 ×30）
- 同时在原版逻辑允许时更新 `$foresthunt`（每步 +0.5，照抄原版）、`$forestmove`、`$forestmod`

| 目的地 | 目标深度 | 出现条件（照原版） |
|---|---|---|
| **快速返回森林之外** → Danube Street | 0 | 保留的单一出林功能（不再提供其它街道/住宅区快速旅行） |
| 旧教堂墓地 → Churchyard | 12 | 无（原版只在 10~14 出现，快速旅行直接走到该深度） |
| 湖泊：岸边 / 瀑布 / 钓鱼岩 → Lake Shore / Lake Waterfall / Lake Fishing Rock | 25 / 35 / 45 | 无（对应原版按深度选择的三个入口） |
| 伊甸的小屋 → Eden Clearing | 50 | `$edenfreedom gte 1` 或 `$syndromeeden gte 1` |
| 狼洞 → Wolf Cave Clearing | 50 | `$syndromewolves gte 1` |
| 小溪 → Forest Brook | 85 | `$brookIntro gte 1` 且没穿高跟鞋（同原版限制） |
| 秘密小路（往深处 / 穿出森林） | ±50 | `$historytrait gte 3`；原版捷径，固定 10 分钟 |

- **只对森林内部地点提供快速旅行**；森林外的地点（街道、住宅区通道等）不再列出，只保留一个「快速返回森林之外（Danube Street）」\n- 已经在森林边缘（`$forest lte 0`）时不再显示 0 分钟的返程，改为提示直接从林间页面离开\n- 「秘密小路」整段只在 `$historytrait ≥ 3` 解锁后显示，不会出现空标题\n- 到达目的地后，目的地段落看到的 `$forest` 深度就是它原版所在区间的值（不会出现「湖泊在浅林」这类错位）
- 入口本身只在原版旅行界面出现时显示（`$eventskip is 1`），不会插进事件文本

## 实现方式（全部复用原版机制）## 实现方式（全部复用原版机制）

- 睡眠：`<<sleep>>` + `<<effects>>` + `<<wakingEffects $sleepHoursTotal>>`（与游戏里 `Asylum Sleep` 等一致）
- 金钱：`<<money -4000>>`（£40）/ `<<money -6200000>>`（£62000），单位是便士（£1 = 100）
- 购买状态：存档变量 `$caeFlatsRoom`（买下后为 1）
- 旅店住宿次数：`$caeInnStays`（统计用，可为空；也用于判断淋浴是否对租客免费）
- **洗澡**：原版 `<<wash>>` 宏（和拳击俱乐部淋浴同一套清洁逻辑）
- **衣柜**：复制原版 `Wardrobe` 段落的宏组合（`<<wardrobeSelection>>` / `<<wardrobewear>>` / `<<wardrobe>>`），
  只把 `<<wardrobeExits>>` 换成自己的「关上衣柜 → 回房间」链接 + `<<cleanupOnWardrobeExit>>`
- **房间升级**：`$caeFlatsBed` / `$caeFlatsBath` / `$caeFlatsShelf` 三个存档变量；升级一次付清
- **每天一次看书**：`$daily.caeFlatsRead`（游戏每天会重置 `$daily`）

## 接线（2 条 TweeReplacer 补丁）

| 段落 | 锚点 | 插入 |
|---|---|---|
| `High Street` | `<<stormdrain>>`（快捷路线区块内，纯代码） | 用原版 `<<add_link>>` 把「旅店」追加到 Alternate routes 列表 |
| `Flats` | `<<set $eventskip to 0>>`（段落最后一行，纯代码） | 「看看待售的房间」/「回到自己的房间」链接 |

锚点都是**纯代码**（不含英文 UI 文本），汉化 mod 替换文本时不会失效。

## 安装

1. 游戏内 ModLoader → 添加 zip → 选 `LocationsExt_v1.7.0.zip`
2. 刷新页面（或由网站在 `modList.json` 里自动加载）
3. 前置：ModLoader + TweeReplacer

## 卸载

ModLoader 里移除即可；已购买的 `$caeFlatsRoom` 会留在存档里（重装后仍然拥有房间），需要彻底清除可在控制台执行 `<<unset $caeFlatsRoom>>` 对应的 `State.variables.caeFlatsRoom = undefined`。

## 构建

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
Set-Location ..\     # modsrc 目录
pwsh -File .\build-locations.ps1
# 或指定游戏目录：
pwsh -File .\build-locations.ps1 -GameDirOverride '<游戏目录>' -OutDir '<游戏目录>'
```

构建会断言 2 个锚点唯一、校验 twee 段落/标签/运算符，生成 `boot.json` 并打包，
合并进 `modList.json`（保留其它 mod 条目），最后校验游戏 HTML 的 SHA256 未变。

## 声明

- 非官方模组，《Degrees of Lewdity》版权归 **Vrelnir** 所有，请支持正版
- 本 mod 只含自写文本，不含任何游戏资源；免费发布、禁止商用
