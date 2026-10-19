# ============================================================================
#  CombatSkills mod 构建脚本（不修改任何游戏文件）
#  ---------------------------------------------------------------------------
#  1) 从 Degrees of Lewdity.html 提取相关段落原文
#  2) 断言每个插入锚点在该段落中恰好出现 1 次（游戏版本不符则中止，不产出文件）
#  3) 生成 mod 的 boot.json（1 处界面插入 + 13 处战斗/地点补丁，全部走 TweeReplacer）
#     另校验 mod 自带的两个 JS 补丁（防御力减伤 / 敏捷接入 currentSkillValue）与 CSS 面板样式
#  4) 打包 CombatSkills_v<ver>.zip（zip 根目录即 boot.json，条目路径用正斜杠）
#  5) 生成/合并服务器自动加载清单 modList.json
#  6) 输出 HTML / boot.json 的 SHA256 前后比对，证明游戏文件零改动
#  用法： pwsh -File .\build.ps1   （PS 5.1 亦可：Set-ExecutionPolicy -Scope Process Bypass）
# ============================================================================
$ErrorActionPreference = 'Stop'

$ModName = 'CombatSkills'
$Version = '1.12.1'
$ScriptDir = $PSScriptRoot
$GameDir   = Split-Path -Parent $ScriptDir
$HtmlPath  = Join-Path $GameDir 'Degrees of Lewdity.html'
$SrcDir    = Join-Path $ScriptDir $ModName
$ZipName   = '{0}_v{1}.zip' -f $ModName, $Version
$ZipPath   = Join-Path $GameDir $ZipName
$ListPath  = Join-Path $GameDir 'modList.json'

function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

Write-Host '=== CombatSkills build ===' -ForegroundColor Cyan

# ---- 0) 构建前的游戏文件指纹 ----
$before = [ordered]@{}
foreach ($f in @('Degrees of Lewdity.html', 'boot.json')) {
    $p = Join-Path $GameDir $f
    if (Test-Path -LiteralPath $p) { $before[$f] = Get-Sha256 $p }
}

# ---- 读取游戏 HTML 并提供段落提取 ----
Write-Host '[1/6] 读取游戏 HTML 并提取段落 ...'
$txt = [System.IO.File]::ReadAllText($HtmlPath, [System.Text.Encoding]::UTF8)
$passageCache = @{}
function Get-Passage([string]$Name) {
    if ($passageCache.ContainsKey($Name)) { return $passageCache[$Name] }
    $nameIdx = $txt.IndexOf('name="' + $Name + '"')
    if ($nameIdx -lt 0) { throw "未找到段落 $Name，游戏版本可能不是 0.5.11.9" }
    $s = $txt.LastIndexOf('<tw-passagedata', $nameIdx)
    $gt = $txt.IndexOf('>', $s)
    $e = $txt.IndexOf('</tw-passagedata>', $gt)
    if ($s -lt 0 -or $gt -lt 0 -or $e -lt 0) { throw "段落 $Name 标签解析失败" }
    $body = [System.Net.WebUtility]::HtmlDecode($txt.Substring($gt + 1, $e - $gt - 1))
    $passageCache[$Name] = $body
    return $body
}

# ---- 1) 特征面板：插入「战斗技能」区块（锚点从段落里提取，避免手抄出错）----
$passage = Get-Passage 'Characteristics'
if ($passage -notmatch '<div id="prof"') { throw 'Characteristics 段落里没有 #prof（武器技能）区块，已中止' }
$anchorStartMarker = '<<if $prof.pickaxe isnot undefined>>'      # 单引号：$prof 不做变量展开
$anchorEndMarker   = "<</if>>*/`n`t`t</div>`n`t</div>"
$anchorStart = $passage.IndexOf($anchorStartMarker)
if ($anchorStart -lt 0) { throw "锚点起始未找到：$anchorStartMarker" }
$anchorEnd = $passage.IndexOf($anchorEndMarker, $anchorStart)
if ($anchorEnd -lt 0) { throw '锚点结束标记未找到（#prof 与 #characteristics-display 的闭合标签）' }
$anchorEnd += $anchorEndMarker.Length
$anchor = $passage.Substring($anchorStart, $anchorEnd - $anchorStart)
if (([regex]::Matches($passage, [regex]::Escape($anchor))).Count -ne 1) { throw '界面插入锚点在 Characteristics 段落中不唯一，已中止' }

$insert = [System.IO.File]::ReadAllText((Join-Path $ScriptDir 'insert.fragment.tw'), [System.Text.Encoding]::UTF8)
$insert = ($insert -replace "`r`n", "`n")
if ($insert.StartsWith("`n")) { $insert = $insert.Substring(1) }
Write-Host ("      Characteristics 段落 {0} 字符；界面锚点 {1} 字符，唯一 ✓" -f $passage.Length, $anchor.Length)

# ---- 2) 战斗成长补丁（全部为代码/注释锚点，不含英文文本，不受汉化影响）----
#  mode = after            在 findString 之后插入
#  mode = beforeWidgetEnd  在 findString 结尾的 <</widget>> 之前插入
$patchSpecs = @(
    [ordered]@{
        name    = '攻击敌人 → 攻击 +1'
        passage = 'Widgets'
        find    = '<<set _defiance to (_args[0] * (1 + ($sadism / 1000)))>>'
        insert  = '<<combatStatAdd "attack" 1>>'
        mode    = 'after'
        note    = 'defiance 是玩家对敌人造成伤害的统一结算宏（共 78 处调用）'
    }
    [ordered]@{
        name    = '被击中 → 防御 +1、敏捷 +1'
        passage = 'Widgets'
        find    = '<<widget "hitstat">><<if $statFreeze isnot true>><<set $hitstat += 1>><</if>><</widget>>'
        insert  = '<<combatStatAdd "defense" 1>><<combatStatAdd "agility" 1>>'
        mode    = 'beforeWidgetEnd'
        note    = 'hitstat 是玩家被打中的统一计数器（共 133 处调用）'
    }
    [ordered]@{
        name    = '怪物扑袭 → 防御 +1、敏捷 +1'
        passage = 'Widgets Struggle'
        find    = '<!-- lurkers attacc -->'
        insert  = "<<combatStatAdd `"defense`" 1>><<combatStatAdd `"agility`" 1>>"
        mode    = 'after'
        note    = 'struggle 系统里每次怪物发起攻击的入口'
    }
    [ordered]@{
        name    = '敏捷判定成功 → 敏捷 +10'
        passage = 'Widgets Struggle'
        find    = '<<set $dodging -= 1>>'
        insert  = '<<combatStatAdd "agility" 10>>'
        mode    = 'after'
        note    = 'struggle 的 $dodging / _doge_chance 判定成功分支内（闪避与险闪都算）'
    }
    [ordered]@{
        name        = '攻击力 → 造成伤害'
        passage     = 'Widgets'
        find        = '<<set _thedamage to (2 * _defiance * ($physique / 4000))>>'
        insert      = ''
        mode        = 'replaceStatement'
        replace     = '<<combatStatSync>><<set _thedamage to (2 * _defiance * ($physique / 4000) * (1 + ($combatBonus.attack / 100)))>>'
        mustContain = @('<<combatStatSync>>', '$combatBonus.attack')
        note        = 'defiance 的伤害公式；每 1 点攻击力 = +1% 伤害'
    }
    [ordered]@{
        name    = '击败 NPC → 战利品掉落（多敌人）'
        passage = 'Widgets NPC Damage'
        find    = '<span class="blue"><<combatPerson>> staggers back, defeated.</span>'
        insert  = '<<combatLootDrop _i>>'
        mode    = 'after'
        note    = 'defeatnpc 内的掉落（注意：defeatnpc 只在 $enemyno gte 2 时被调用）'
    }
    [ordered]@{
        name    = '战斗胜利 → 战利品掉落（1v1）'
        passage = 'Widgets End Combat'
        find    = '<<widget "endcombat">>'
        insert  = '<<combatLootVictory>>'
        mode    = 'after'
        note    = '单挑不会走 defeatnpc，必须挂在 endcombat 的 $enemyhealth lte 0 分支上'
    }
    [ordered]@{
        name    = '战斗开始 → 清空战利品清单'
        passage = 'Widgets NPCs'
        find    = '<<widget "combatinit">>'
        insert  = '<<combatLootClear>>'
        mode    = 'after'
        note    = '每个战斗初始化 widget 都会调用 combatinit，保证汇总面板不串场'
    }
    [ordered]@{
        name        = '康努达塔斯街 → 拳击俱乐部入口'
        passage     = 'Connudatus Street'
        find        = '<<if $skulduggeryDintro is 1 and $exposed lte 0>>'
        insert      = ''
        mode        = 'replaceStatement'
        keepsFind   = $true
        replace     = '<<exerciseicon>><<link [[拳击俱乐部|Boxing Club]]>><</link>>' + "`n`t`t`t<br>`n`t`t`t" + '<<if $skulduggeryDintro is 1 and $exposed lte 0>>'
        mustContain = @('|Boxing Club]]', '<<exerciseicon>>')
        note        = '插在「偷窃」入口之前；进入俱乐部不耗时（更衣室/淋浴间各 0:01 由段内链接计费）'
    }
    [ordered]@{
        name        = '丰收街酒吧 → 斗殴入口'
        passage     = 'Pub'
        # 锚点必须是纯代码：汉化 mod 会在本 mod 之后替换英文界面文字，
        # 任何含英文文本的 findString 都会被改掉导致补丁静默失效（v1.11.1 修复）
        find        = '<<if C.npc.Gwylan.state is "scorned">>'
        insert      = ''
        mode        = 'replaceStatement'
        keepsFind   = $true
        replace     = '<<exerciseicon>><<link [[斗殴 (0:05)|Pub Brawl]]>><<endevent>><<pass 5>><</link>>' + "`n`t`t`t<br>`n`t`t`t" + '<<if C.npc.Gwylan.state is "scorned">>'
        mustContain = @('|Pub Brawl]]', '<<pass 5>>')
        note        = '纯代码锚点（C.npc.Gwylan.state），插在酒吧常驻链接区里'
    }
    [ordered]@{
        name        = '战斗动作：反剪双臂（左手注册）'
        passage     = 'Widgets Actions Generation'
        find        = '<<widget "leftActions">>' + "`n`t" + '/*Generate Actions*/' + "`n`t" + '<<set _leftaction to {}>>'
        insert      = "`n`t" + '<<combatReversePinRegister "left">>'
        mode        = 'after'
        mustContain = @('combatReversePinRegister "left"')
        note        = '插在 leftActions 的 _leftaction 重置之后'
    }
    [ordered]@{
        name        = '战斗动作：反剪双臂（右手注册）'
        passage     = 'Widgets Actions Generation'
        find        = '<<widget "rightActions">>' + "`n`t" + '/*Generate Actions*/' + "`n`t" + '<<set _rightaction to {}>>'
        insert      = "`n`t" + '<<combatReversePinRegister "right">>'
        mode        = 'after'
        mustContain = @('combatReversePinRegister "right"')
        note        = '插在 rightActions 的 _rightaction 重置之后'
    }
    [ordered]@{
        name        = '战斗动作：反剪双臂（结算挂点）'
        passage     = 'Widgets Effects Man'
        find        = '<<widget "effectsman">>'
        insert      = "`n`t" + '<<combatReversePin>>'
        mode        = 'after'
        mustContain = @('<<combatReversePin>>')
        note        = 'effectsman 开头：每回合维护按住状态并结算选中动作'
    }
)

$patchParams = @()
foreach ($spec in $patchSpecs) {
    $body = Get-Passage $spec.passage
    $hits = ([regex]::Matches($body, [regex]::Escape($spec.find))).Count
    if ($hits -ne 1) { throw "[$($spec.name)] 锚点在段落 [$($spec.passage)] 中出现 $hits 次（应为 1 次），已中止" }
    switch ($spec.mode) {
        'after'            { $replace = $spec.find + $spec.insert }
        'beforeWidgetEnd'  { $replace = $spec.find -replace '<<\/widget>>$', ($spec.insert + '<</widget>>') }
        'replaceStatement' { $replace = $spec.replace }
        default            { throw "未知 mode：$($spec.mode)" }
    }
    if ($replace -eq $spec.find) { throw "[$($spec.name)] 生成的替换文本与锚点相同，mode 可能写错" }
    if ($spec.mode -eq 'replaceStatement') {
        if (-not $replace.EndsWith('>>')) { throw "[$($spec.name)] 替换语句不是完整的宏语句" }
        if ($spec.Contains('keepsFind') -and $spec.keepsFind -and -not $replace.Contains($spec.find)) {
            throw "[$($spec.name)] 替换文本没有保留原语句，原逻辑会丢失"
        }
    } else {
        $prefixLen = [Math]::Min(24, $spec.find.Length)
        if ($replace.Substring(0, $prefixLen) -cne $spec.find.Substring(0, $prefixLen)) { throw "[$($spec.name)] 替换文本丢失了原语句开头，已中止" }
    }
    if ($spec.Contains('mustContain')) {
        foreach ($need in $spec.mustContain) {
            if (-not $replace.Contains($need)) { throw "[$($spec.name)] 替换文本缺少必需内容：$need" }
        }
    }
    $newBody = $body.Replace($spec.find, $replace)
    $keepsFind = ($spec.Contains('keepsFind') -and $spec.keepsFind)
    if ($spec.insert) {
        $after = ([regex]::Matches($newBody, [regex]::Escape($spec.insert))).Count
        $beforeCnt = ([regex]::Matches($body, [regex]::Escape($spec.insert))).Count
        if ($after -ne ($beforeCnt + 1)) { throw "[$($spec.name)] 插入后计数异常（before=$beforeCnt after=$after）" }
    } elseif (-not $keepsFind -and ([regex]::Matches($newBody, [regex]::Escape($spec.find))).Count -ne 0) {
        throw "[$($spec.name)] 替换后原语句仍存在，替换未生效"
    }
    $patchParams += [ordered]@{
        passage    = $spec.passage
        findString = $spec.find
        replace    = $replace
        all        = $false
        debug      = $true
    }
    Write-Host ("      [{0}] 段落 [{1}] 锚点唯一 ✓  {2}" -f $spec.name, $spec.passage, $spec.note)
}

# 界面插入作为第一条替换参数
$allParams = @([ordered]@{
    passage    = 'Characteristics'
    findString = $anchor
    replace    = ($anchor + "`n" + $insert)
    all        = $false
    debug      = $true
}) + $patchParams

# ---- 校验 mod 的 twee 文件能被 ModLoader 解析 ----
$tweePath = Join-Path $SrcDir 'twee\CombatSkills.tw'
$tweeText = [System.IO.File]::ReadAllText($tweePath, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
$tweeRegex = '(?m)^(:: +((?:[^:"\/\n\r\[\] ]+ *)+)(?: *\[((?:[^ \]]+ *)* *)\] *|))$'
$tweePassages = [regex]::Matches($tweeText, $tweeRegex)
$tweeNames = @($tweePassages | ForEach-Object { $_.Groups[2].Value.Trim() })
$expectPassages = @('CombatSkills Widgets', 'Boxing Club', 'Boxing Club Spar', 'Boxing Club Training', 'Boxing Club Changing Room', 'Boxing Club Shower', 'Pub Brawl', 'Pub Brawl Fight', 'Pub Brawl Finish')
if ($tweePassages.Count -ne $expectPassages.Count) { throw "twee 文件被解析出 $($tweePassages.Count) 个段落（应为 $($expectPassages.Count) 个：$($expectPassages -join ' / ')）" }
foreach ($exp in $expectPassages) {
    if ($tweeNames -notcontains $exp) { throw "twee 文件缺少段落：$exp" }
}
$widgetPassage = $tweePassages | Where-Object { $_.Groups[2].Value.Trim() -eq 'CombatSkills Widgets' }
if ($widgetPassage.Groups[3].Value -notmatch 'widget') { throw "段落 CombatSkills Widgets 缺少 [widget] 标签（widget 不会被定义）" }
Write-Host ("      twee 解析：{0} 个段落 {1}，其中 [CombatSkills Widgets] 带 widget 标签  ✓" -f $tweePassages.Count, ($tweeNames -join ' / '))

# ---- 校验等级档位表（自检，防止改表时写错）----
$lvls = @([regex]::Matches($tweeText, '\{ value:\s*(\d+),\s*level:\s*"([^"]+)"'))
if ($lvls.Count -lt 2) { throw '未从 twee 文件解析到等级档位表' }
$vals  = @($lvls | ForEach-Object { [int]$_.Groups[1].Value })
$names = @($lvls | ForEach-Object { $_.Groups[2].Value })
for ($i = 1; $i -lt $vals.Count; $i++) { if ($vals[$i] -le $vals[$i - 1]) { throw "等级档位表数值未递增：$($vals -join ',')" } }
if ($vals[0] -ne 0 -or $vals[-1] -ne 1000) { throw "等级档位表首尾应为 0 / 1000，实际 $($vals[0]) / $($vals[-1])" }
if ($names[0] -ne 'F-' -or $names[-1] -ne 'S') { throw "等级档位表首尾档位应为 F- / S，实际 $($names[0]) / $($names[-1])" }
Write-Host ("      等级档位自检：{0} 档 → {1}" -f $vals.Count, ($names -join ' '))

# ---- 校验所有成长接口/触发点在 twee 里都有定义 ----
foreach ($tok in @('combatStatAdd', 'combatStatExp', 'combatStatBoxes', 'combatStatSet', 'combatStatTable', 'combatStatInit', 'combatStatSync', 'combatLootDrop', 'combatLootHuman', 'combatLootCreature', 'combatLootItem', 'combatLootVictory', 'combatLootLogAdd', 'combatLootSummary', 'combatLootClear')) {
    if ($tweeText -notmatch ('<<widget "' + $tok + '"')) { throw "twee 文件里缺少 widget 定义：$tok" }
}
Write-Host '      成长接口 / 战利品 widget 齐备 ✓'

# ---- 战利品逻辑自检：只允许使用游戏里真实存在的接口 ----
$lootChecks = [ordered]@{
    '掉钱走游戏 money 接口'   = '<<money _clCash "thievery">>'
    '避孕套用 $condoms'       = '$condoms += _clAmount'
    '喷雾用 <<spray 1>>'      = '<<spray 1>>'
    '零钱用 $blackmoney'      = '$blackmoney += _clAmount'
    '按 NPC 类型分流'         = '$NPCList[_clIndex].type is "man"'
    '按 NPC 幂等（.looted）'  = '!$NPCList[_clIndex].looted'
    '1v1 胜利补发的胜利判定'  = '$enemyhealth lte 0'
    '战斗结束汇总面板'        = 'id="combatLootSummary"'
    '掉落写入战斗清单'        = '$combatLootLog.push'
    '汇总后清空清单'          = '$combatLootLog to []'
    '可在击败瞬间关闭绿字'    = '$combatLootInline isnot false'
}
foreach ($k in $lootChecks.Keys) {
    if (-not $tweeText.Contains($lootChecks[$k])) { throw "战利品逻辑缺少：$k（应为 $($lootChecks[$k])）" }
}
Write-Host '      战利品接口自检通过（money / condoms / spray / blackmoney / type 分流 / 汇总面板）✓'

# ---- 拳击俱乐部自检：段落内容、属性成长、时间与洗澡/更衣柜接口 ----
$clubChecks = [ordered]@{
    '陪练：攻击+1/防御+2/敏捷+1' = '<<combatStatAdd "attack" 1>><<combatStatAdd "defense" 2>><<combatStatAdd "agility" 1>>'
    '陪练：意志经验 +1' = '<<gwillpower>><<willpower 1>>'
    '训练：攻击+2/敏捷+1'        = '<<combatStatAdd "attack" 2>><<combatStatAdd "agility" 1>>'
    '陪练：疼痛（临时变量 + 指示器）' = '<<pain _clPain>><<gpain>>'
    '陪练：宽容模式提示'         = '$gamemode is "soft"'
    '训练：运动技能经验'         = '<<gathletics>><<athletics 5>>'
    '陪练：收入走 money 接口'    = '<<money _pay "boxingClub">>'
    '更衣室 0:01'                = '更衣室 (0:01)'
    '浴室和淋浴间 0:01'          = '浴室和淋浴间 (0:01)'
    '淋浴：<<wash>>'             = '<<wash>>'
    '更衣室：衣柜返回本段落'     = '$wardrobeExit to "Boxing Club Changing Room"'
    '陪练 0:30'                  = '当陪练挣钱 (0:30)'
    '训练 0:20 £20'              = '拳击训练 (0:20 £20)'
    '训练收费 £20（2000 便士）'  = '<<money -2000 "boxingClub">>'
    '钱不够时只给提示'           = '$money gte 2000'
    '陪练收入 £20~40（便士单位）' = '<<set _pay to 2000 + (random(0, 20) * 100)>>'
    '掉落现金 £10~30（便士单位）' = '<<set _clCash to 1000 + (random(0, 20) * 100)>>'
    '赃款 £5~15（便士单位）'     = '<<set _clAmount to 500 + (random(0, 10) * 100)>>'
    '战利品：NPCList 类型保护'   = 'typeof $NPCList is "object"'
    '战利品：人类判定含 human'   = '$NPCList[_clIndex].type is "human"'
    '战利品：清单类型保护'       = 'typeof $combatLootLog.push isnot "function"'
    '战利品：冷却/状态保护'       = '$enemyhealth isnot undefined and $enemyhealth lte 0'
}
foreach ($k in $clubChecks.Keys) {
    if (-not $tweeText.Contains($clubChecks[$k])) { throw "拳击俱乐部缺少：$k（应为 $($clubChecks[$k])）" }
}
# 进入俱乐部不耗时（与设定的 0:01 房间区分开）
$clubEntry = ($patchParams | Where-Object { $_.findString -eq '<<if $skulduggeryDintro is 1 and $exposed lte 0>>' }).replace
if ($clubEntry -match '<<pass') { throw '拳击俱乐部入口被计费了时间（按要求：只有更衣室与淋浴间各 0:01）' }
Write-Host '      拳击俱乐部自检通过（成长 / 收入 / 疼痛 / 更衣室·淋浴 0:01 / 入口不计时）✓'

# ---- 丰收街酒吧斗殴：入口、战斗接线、输赢分支 ----
$brawlChecks = [ordered]@{
    '斗殴：生成对手'          = '<<generate1>><<person1>>'
    '斗殴：战斗初始化'        = '<<maninit>>'
    '斗殴：结束判定（含被打倒）' = '<<if _combatend or ($pain gte 100 and $willpowerpain is 0)>>'
    '斗殴：赢 → 彩头（money 接口）' = '<<money (500 + random(0, 10) * 100) "pubBrawl">>'
    '斗殴：赢 → 不计战利品'   = '<<set $NPCList[0].looted to true>>'
    '斗殴：输 → 被丢出酒吧'   = '<<link [[从地上爬起来|Harvest Street]]>>'
    '斗殴：输 → 压力/创伤/疼痛' = '<<gstress>><<stress 12>><<gtrauma>><<trauma 6>><<gpain>><<pain 10>>'
}
foreach ($k in $brawlChecks.Keys) {
    if (-not $tweeText.Contains($brawlChecks[$k])) { throw "酒吧斗殴缺少：$k（应为 $($brawlChecks[$k])）" }
}
$brawlEntry = ($patchParams | Where-Object { $_.findString -eq '<<if C.npc.Gwylan.state is "scorned">>' }).replace
if (-not $brawlEntry) { throw '找不到酒吧斗殴入口补丁' }
if ($brawlEntry -notmatch '\|Pub Brawl\]\]') { throw '酒吧斗殴入口没有指向 Pub Brawl 段落' }
if ($brawlEntry -notmatch '<<pass 5>>') { throw '酒吧斗殴入口没有计 0:05 时间' }
# 入口锚点必须是纯代码（不能是含界面文字的链接），否则汉化在本 mod 之后替换英文文本会让补丁静默失效
$brawlFind = ($patchParams | Where-Object { $_.findString -eq '<<if C.npc.Gwylan.state is "scorned">>' }).findString
if ($brawlFind -match '\]\]' -or $brawlFind -match '<<link') { throw "酒吧斗殴入口锚点含界面文字，可能被汉化破坏：$brawlFind" }
Write-Host '      酒吧斗殴自检通过（纯代码锚点 / maninit 接线 / 赢-彩头 / 输-被丢出到丰收街）✓'

# ---- 版本一致性：面板页脚 + 安装脚本控制台日志都必须带上当前版本号（排错时用来确认浏览器加载的是哪一版）----
if (-not $tweeText.Contains("CombatSkills mod v$Version")) { throw "特征面板缺少版本标记 v$Version（面板页脚）" }
$jsInstallText = [System.IO.File]::ReadAllText((Join-Path $SrcDir 'dist\js\installCombatSkillsPatch.js'), [System.Text.Encoding]::UTF8)
if (-not $jsInstallText.Contains("CS_VERSION = " + [char]34 + $Version + [char]34)) { throw "安装脚本里的 CS_VERSION 与 $Version 不一致" }
Write-Host "      版本一致性自检通过（面板 / 安装脚本 = v$Version）✓"

# ---- TwineScript 运算符校验：SugarCube 只认 lt/lte/gt/gte/eq/neq，写 le/ge/ne 会在运行时抛 SyntaxError ----
$badOps = @([regex]::Matches($tweeText, '(?m)<<(?:if|elseif|unless)[^>]*?\b(le|ge|ne)\b'))
if ($badOps.Count -gt 0) { throw ("twee 里出现非法的 SugarCube 比较运算符：" + $badOps[0].Value + "（应写 lte / gte / neq）") }
Write-Host '      TwineScript 运算符自检通过（无 le/ge/ne 等非法写法）✓'

# ---- 兼容 shim：别的 mod 段落会调用 0.5.11.9 不存在的 <<askicon>>，本 mod 必须兜底 ----
if (-not $tweeText.Contains('<<widget "askicon">>')) { throw '缺少 askicon 兼容 shim（别的 mod 调用该宏会整段报错）' }
if (-not $tweeText.Contains('<<icon "ask.png">>')) { throw 'askicon shim 没有渲染 ask.png' }
Write-Host '      兼容 shim 自检通过（askicon → ask.png）✓'
$pinChecks = [ordered]@{
    '反剪双臂：注册 widget'   = '<<widget "combatReversePinRegister">>'
    '反剪双臂：主调度 widget' = '<<widget "combatReversePin">>'
    '反剪双臂：结算 widget'   = '<<widget "combatReversePinDo">>'
    '反剪双臂：动作键'        = '<<set _leftaction["反剪双臂"] to "reversePinArms">>'
    '反剪双臂：继续压制键'    = '<<set _leftaction["继续压制"] to "reversePinPress">>'
    '反剪双臂：力量判定'      = "currentSkillValue('physique')"
    '反剪双臂：按住回合数'    = '<<set $reversePinTurns to 2>>'
    '反剪双臂：锁住对方双手'  = '<<set $NPCList[_rpT].lefthand to "handhold">>'
    '反剪双臂：到期放开'      = '<<set $NPCList[0].lefthand to 0>>'
    '反剪双臂：失败反制'      = '<<pain 4>>'
}
foreach ($k in $pinChecks.Keys) {
    if (-not $tweeText.Contains($pinChecks[$k])) { throw "反剪双臂缺少：$k（应为 $($pinChecks[$k])）" }
}
$pinLeft  = ($patchParams | Where-Object { $_.replace -match 'combatReversePinRegister "left"' })
$pinRight = ($patchParams | Where-Object { $_.replace -match 'combatReversePinRegister "right"' })
$pinExec  = ($patchParams | Where-Object { $_.replace -match '<<combatReversePin>>' })
if (-not $pinLeft -or -not $pinRight -or -not $pinExec) { throw '反剪双臂的补丁没有全部写入（左/右注册或结算挂点缺失）' }
if ($pinLeft.passage -ne 'Widgets Actions Generation' -or $pinRight.passage -ne 'Widgets Actions Generation') { throw '反剪双臂注册补丁段落不对' }
if ($pinExec.passage -ne 'Widgets Effects Man') { throw '反剪双臂结算补丁段落不对' }
Write-Host '      反剪双臂自检通过（左右手注册 / effectsman 结算 / 力量判定 / 锁手与到期放开）✓'

# ---- 校验战利品面板的 CSS：必须只作用于 #combatLootSummary，避免污染游戏样式 ----
$cssPath = Join-Path $SrcDir 'CombatSkills.css'
if (-not (Test-Path -LiteralPath $cssPath)) { throw "缺少样式文件：$cssPath" }
$cssText = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
if ($cssText -notmatch '#combatLootSummary') { throw 'CombatSkills.css 里找不到 #combatLootSummary 选择器' }
$cssNoComment = [regex]::Replace($cssText, '(?s)/\*.*?\*/', '')
$otherSelectors = @([regex]::Matches($cssNoComment, '(?m)^\s*([^@/\s][^{\n]*?)\s*\{') | ForEach-Object { $_.Groups[1].Value.Trim() } | Where-Object { $_ -notmatch '^#combatLootSummary' })
if ($otherSelectors.Count -gt 0) { throw "CombatSkills.css 里有不作用于本 mod 面板的选择器：$($otherSelectors -join ' | ')" }
foreach ($needle in @('var(--300)', 'var(--900)')) {
    if (-not $cssText.Contains($needle)) { throw "CombatSkills.css 缺少游戏调色板变量：$needle" }
}
Write-Host '      面板 CSS 自检通过（选择器全部限定在 #combatLootSummary，使用游戏调色板）✓'

# ---- 校验 JS 补丁：语法 + 档位表与 twee 一致 ----
$jsPatchPath = Join-Path $SrcDir 'dist\CombatSkillsPatch.js'
$jsInstallPath = Join-Path $SrcDir 'dist\js\installCombatSkillsPatch.js'
foreach ($f in @($jsPatchPath, $jsInstallPath)) {
    if (-not (Test-Path -LiteralPath $f)) { throw "缺少脚本文件：$f" }
}
$nodeExe = $null
foreach ($cand in @('node', 'C:\Program Files\nodejs\node.exe', 'nodejs\node.exe')) {
    $cmd = Get-Command $cand -ErrorAction SilentlyContinue
    if ($cmd) { $nodeExe = $cmd.Source; break }
    if (Test-Path -LiteralPath $cand) { $nodeExe = $cand; break }
}
if ($nodeExe) {
    foreach ($f in @($jsPatchPath, $jsInstallPath)) {
        & $nodeExe --check $f
        if ($LASTEXITCODE -ne 0) { throw "JS 语法检查失败：$f" }
    }
    Write-Host '      JS 语法检查（node --check）通过 ✓'
} else {
    Write-Host '      [警告] 未找到 node，跳过 JS 语法检查' -ForegroundColor Yellow
}
$jsText = [System.IO.File]::ReadAllText($jsPatchPath, [System.Text.Encoding]::UTF8)
$mTiers = [regex]::Match($jsText, 'var TIERS = \[([^\]]+)\]')
if (-not $mTiers.Success) { throw 'CombatSkillsPatch.js 里找不到 TIERS 档位表' }
$jsTiers = @(($mTiers.Groups[1].Value -split ',') | ForEach-Object { [int]$_.Trim() })
if (($jsTiers -join ',') -ne ($vals -join ',')) { throw "JS 的 TIERS 与 twee 档位表不一致：JS=[$($jsTiers -join ',')] twee=[$($vals -join ',')]" }
Write-Host ("      JS/Twee 档位表一致（{0} 档）✓" -f $jsTiers.Count)
if ($jsText -notmatch 'Macro\.delete\("pain"\)' -or $jsText -notmatch 'Macro\.add\("pain"') { throw 'CombatSkillsPatch.js 未按预期替换 pain 宏' }

# ---- 校验敏捷：包装 currentSkillValue，且加成的档位系数与 twee 一致 ----
if ($jsText -notmatch 'window\.currentSkillValue\s*=\s*wrapper') { throw 'CombatSkillsPatch.js 未包装 window.currentSkillValue（敏捷未接入判定）' }
$mAg = [regex]::Match($jsText, 'var AGILITY_SKILLS = \[([^\]]+)\]')
if (-not $mAg.Success) { throw 'CombatSkillsPatch.js 里找不到 AGILITY_SKILLS 列表' }
$agSkills = @(($mAg.Groups[1].Value -split ',') | ForEach-Object { $_.Trim().Trim('"').Trim("'") })
if ($agSkills.Count -lt 1) { throw 'AGILITY_SKILLS 为空' }
foreach ($sk in $agSkills) {
    if ($txt -notmatch ('"' + [regex]::Escape($sk) + '"') -and $txt -notmatch ('V\.' + [regex]::Escape($sk) + '\b')) {
        throw "敏捷技能名 [$sk] 在游戏里找不到，可能是拼写错误"
    }
}
if ($txt -notmatch 'window\.currentSkillValue = currentSkillValue') { throw '游戏 HTML 里找不到 window.currentSkillValue 赋值，包装点失效' }

# JS 的 RATE 与 twee 每档系数必须一致（从 twee 的描述里解析 _csI * N）
$mRate = [regex]::Match($jsText, 'var RATE = \{([^}]+)\}')
if (-not $mRate.Success) { throw 'CombatSkillsPatch.js 里找不到 RATE' }
$jsRate = @{}
foreach ($pair in ($mRate.Groups[1].Value -split ',')) {
    $kv = $pair -split ':'
    if ($kv.Count -eq 2) { $jsRate[$kv[0].Trim()] = [int]$kv[1].Trim() }
}
$tweeRate = [ordered]@{}
foreach ($m in [regex]::Matches($tweeText, 'description:\s*"([^"]+)\s*\+"\s*\+\s*\(_csI \* (\d+)\)')) {
    $tweeRate[$m.Groups[1].Value.Trim()] = [int]$m.Groups[2].Value
}
# twee 描述里的键名是中文（攻击力/防御力/敏捷），映射回 JS 的键
$map = [ordered]@{ '攻击力' = 'attack'; '防御力' = 'defense'; '敏捷' = 'agility' }
foreach ($cn in $map.Keys) {
    if (-not $tweeRate.Contains($cn)) { throw "twee 里找不到「$cn」的每档系数" }
    $en = $map[$cn]
    if ($jsRate[$en] -ne $tweeRate[$cn]) { throw "每档系数不一致：$cn JS=$($jsRate[$en]) twee=$($tweeRate[$cn])" }
}
Write-Host ("      敏捷接入 OK：{0}；每档系数 JS/Twee 一致（攻击 {1} / 防御 {2} / 敏捷 {3}）✓" -f ($agSkills -join '/'), $jsRate['attack'], $jsRate['defense'], $jsRate['agility'])

# ---- 3) 生成 boot.json ----
Write-Host '[3/6] 生成 boot.json ...'
$boot = [ordered]@{
    name                        = $ModName
    version                     = $Version
    styleFileList               = @('CombatSkills.css')
    scriptFileList_earlyload    = @()
    scriptFileList_inject_early = @('dist/CombatSkillsPatch.js')
    scriptFileList_preload      = @()
    scriptFileList              = @('dist/js/installCombatSkillsPatch.js')
    tweeFileList                = @('twee/CombatSkills.tw')
    imgFileList                 = @()
    imgFileReplaceList          = @()
    additionFile                = @('README.md')
    addonPlugin                 = @(
        [ordered]@{
            modName    = 'TweeReplacer'
            addonName  = 'TweeReplacerAddon'
            modVersion = '^1.7.0'
            params     = $allParams
        }
    )
    dependenceInfo              = @(
        [ordered]@{ modName = 'ModLoader';    version = '^2.60.1' },
        [ordered]@{ modName = 'TweeReplacer'; version = '^1.7.0' }
    )
}
$bootJson = $boot | ConvertTo-Json -Depth 12
if ($bootJson -notmatch '"params"\s*:\s*\[') { throw 'boot.json 的 params 未序列化为数组，已中止' }
if ($bootJson -notmatch '"tweeFileList"\s*:\s*\[') { throw 'boot.json 的 tweeFileList 未序列化为数组，已中止' }
$bootPath = Join-Path $SrcDir 'boot.json'
[System.IO.File]::WriteAllText($bootPath, $bootJson, (New-Object System.Text.UTF8Encoding($false)))
$chk = Get-Content -LiteralPath $bootPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($chk.name -ne $ModName -or $chk.addonPlugin[0].params.Count -ne $allParams.Count) { throw 'boot.json 回读校验失败' }
if ($chk.addonPlugin[0].params[0].findString -ne $anchor) { throw 'boot.json 中的界面锚点与提取结果不一致' }
Write-Host ("      boot.json {0} 字节，{1} 条替换参数  ✓" -f (Get-Item $bootPath).Length, $allParams.Count)

# ---- 4) 打包 zip ----
# 注意：不能用 ZipFile.CreateFromDirectory —— .NET Framework 会写入反斜杠条目名，
#       而 ModLoader 是按 'twee/CombatSkills.tw' 这种正斜杠路径在 zip 里取文件的。
Write-Host '[4/6] 打包 zip ...'
Add-Type -AssemblyName System.IO.Compression | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
$zipStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
$archive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($f in (Get-ChildItem -LiteralPath $SrcDir -Recurse -File | Sort-Object FullName)) {
    $rel = ($f.FullName.Substring($SrcDir.Length + 1)) -replace '\\', '/'
    $entry = $archive.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
    $es = $entry.Open()
    $fs = [System.IO.File]::OpenRead($f.FullName)
    $fs.CopyTo($es)
    $fs.Close(); $es.Close()
}
$archive.Dispose(); $zipStream.Close()
$zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
$entryNames = @($zip.Entries | ForEach-Object { $_.FullName })
$zip.Dispose()
if ($entryNames -notcontains 'boot.json') { throw 'zip 根目录缺少 boot.json（ModLoader 无法识别）' }
if ($entryNames -notcontains 'twee/CombatSkills.tw') { throw 'zip 中缺少 twee/CombatSkills.tw（路径必须为正斜杠）' }
foreach ($need in @('dist/CombatSkillsPatch.js', 'dist/js/installCombatSkillsPatch.js', 'CombatSkills.css')) {
    if ($entryNames -notcontains $need) { throw "zip 中缺少 $need（boot.json 引用了它）" }
}
if (($entryNames | Where-Object { $_ -like '*\*' }).Count -gt 0) { throw 'zip 条目含反斜杠，ModLoader 将无法按路径取文件' }
Write-Host ("      {0}  ({1} 字节)" -f $ZipName, (Get-Item $ZipPath).Length)
$entryNames | ForEach-Object { Write-Host "        - $_" }

# ---- 5) modList.json（服务器自动加载清单）----
# 升级时先清掉本 mod 的旧条目与旧安装包，避免 modList.json 越堆越多
Write-Host '[5/6] 更新 modList.json ...'
$entry = './' + $ZipName
foreach ($old in (Get-ChildItem -LiteralPath $GameDir -File -Filter ($ModName + '_v*.zip') -ErrorAction SilentlyContinue)) {
    if ($old.Name -ne $ZipName) { Remove-Item -LiteralPath $old.FullName -Force; Write-Host ("      清理旧安装包：{0}" -f $old.Name) }
}
$list = @()
if (Test-Path -LiteralPath $ListPath) {
    try { $list = @(Get-Content -LiteralPath $ListPath -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $list = @() }
    $list = @($list | Where-Object { $_ -is [string] })
}
$list = @($list | Where-Object { $_ -notmatch ('^\./' + [regex]::Escape($ModName) + '_v.*\.zip$') })
$list += $entry
$listJson = '[' + (($list | ForEach-Object { '"' + ($_ -replace '\\', '\\' -replace '"', '\"') + '"' }) -join ',') + ']'
[System.IO.File]::WriteAllText($ListPath, $listJson, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("      {0}  ->  {1}" -f $ListPath, $listJson)

# ---- 6) 游戏文件指纹复核 ----
Write-Host '[6/6] 校验游戏文件未被改动 ...'
$failed = $false
foreach ($f in $before.Keys) {
    $now = Get-Sha256 (Join-Path $GameDir $f)
    $ok = ($now -eq $before[$f])
    if (-not $ok) { $failed = $true }
    Write-Host ("      {0}  {1}" -f $(if ($ok) { 'OK  ' } else { 'CHANGED' }), $f) -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
    Write-Host ("        SHA256 = {0}" -f $now)
}
if ($failed) { throw '检测到游戏文件被改动！' }

Write-Host ''
Write-Host '构建完成：' -ForegroundColor Green
Write-Host ("  mod 源目录 : {0}" -f $SrcDir)
Write-Host ("  安装包     : {0}" -f $ZipPath)
Write-Host ("  自动加载表 : {0}" -f $ListPath)
Write-Host ("  替换参数   : {0} 条（1 界面 + {1} 战斗/成长）" -f $allParams.Count, $patchSpecs.Count)
Write-Host '  数值效果   : 攻击力 每点 +1% 伤害 ／ 防御力 每点 -1% 受伤（上限 -90%）／ 敏捷 直接计入 舞蹈·运动·游泳·足部 判定'
Write-Host '  战利品     : 人类 NPC 65% 掉钱(£10~30) + 30% 掉物品 ／ 非人类 NPC 45% 掉身上的物品'
Write-Host '               战斗结束界面显示「战利品」汇总面板（含现金/赃款合计）'
Write-Host '  新地点     : 康努达塔斯街「拳击俱乐部」（陪练挣钱 / 拳击训练 / 更衣室 0:01 / 浴室淋浴间 0:01）'; Write-Host '               丰收街酒吧「斗殴」（赢：彩头；输：被丢出酒吧到丰收街）'
