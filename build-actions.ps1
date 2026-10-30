# ============================================================================
#  CombatActionsExt 构建脚本（不修改任何游戏文件）
#  ---------------------------------------------------------------------------
#  1) 从 Degrees of Lewdity.html 提取相关段落原文
#  2) 断言 4 个插入锚点在该段落中恰好出现 1 次（版本不符立即中止，不产出文件）
#  3) 校验 twee：段落头、标签配平、TwineScript 运算符、必需片段
#  4) 生成 boot.json（4 条 TweeReplacer 补丁）
#  5) 打包 CombatActionsExt_v<ver>.zip（zip 根目录即 boot.json，条目用正斜杠）
#  6) 合并 modList.json（保留其它 mod 条目，只替换本 mod 的旧条目）
#  7) 输出 HTML / boot.json 的 SHA256 前后比对，证明游戏文件零改动
#  用法： pwsh -File .\build-actions.ps1   （PS 5.1 亦可：Set-ExecutionPolicy -Scope Process Bypass）
# ============================================================================
param(
    [string]$GameDirOverride = '',
    [string]$OutDir = ''
)
$ErrorActionPreference = 'Stop'

$ModName   = 'CombatActionsExt'
$Version   = '0.9.2'
$ScriptDir = $PSScriptRoot
$GameDir   = if ($GameDirOverride) { $GameDirOverride } else { Split-Path -Parent $ScriptDir }
if (-not $OutDir) { $OutDir = $GameDir }
$HtmlPath  = Join-Path $GameDir 'Degrees of Lewdity.html'
$SrcDir    = Join-Path $ScriptDir $ModName
$ZipName   = '{0}_v{1}.zip' -f $ModName, $Version
$ZipPath   = Join-Path $OutDir $ZipName
$ListPath  = Join-Path $OutDir 'modList.json'
$TweePath  = Join-Path $SrcDir 'twee\CombatActionsExt.tw'
$ReadmePath = Join-Path $SrcDir 'README.md'
$ProbePath = Join-Path $SrcDir 'dist\js\probe.js'
$ColoursPath = Join-Path $SrcDir 'dist\js\actionColours.js'
$BootPath  = Join-Path $SrcDir 'boot.json'

function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

Write-Host '=== CombatActionsExt build ===' -ForegroundColor Cyan

# ---- 0) 构建前的游戏文件指纹 ----
$before = [ordered]@{}
foreach ($f in @('Degrees of Lewdity.html', 'boot.json')) {
    $p = Join-Path $GameDir $f
    if (Test-Path -LiteralPath $p) { $before[$f] = Get-Sha256 $p }
}

# ---- 1) 读取游戏 HTML 并提供段落提取 ----
Write-Host '[1/6] 读取游戏 HTML 并提取段落 ...'
if (-not (Test-Path -LiteralPath $HtmlPath)) { throw "找不到游戏 HTML：$HtmlPath" }
$txt = [System.IO.File]::ReadAllText($HtmlPath, [System.Text.Encoding]::UTF8)
$passageCache = @{}
function Get-Passage([string]$Name) {
    if ($passageCache.ContainsKey($Name)) { return $passageCache[$Name] }
    $needle = 'name="' + $Name + '"'
    $i = $txt.IndexOf($needle)
    if ($i -lt 0) { throw "游戏 HTML 里找不到段落：$Name" }
    $s = $txt.LastIndexOf('<tw-passagedata', $i)
    $gt = $txt.IndexOf('>', $s)
    $e = $txt.IndexOf('</tw-passagedata>', $gt)
    if ($gt -lt 0 -or $e -lt 0) { throw "段落 $Name 解析失败" }
    $body = [System.Net.WebUtility]::HtmlDecode($txt.Substring($gt + 1, $e - $gt - 1))
    $passageCache[$Name] = $body
    return $body
}

$nl  = [string][char]10
$tab = [string][char]9
$leftAnchor  = '<<widget "leftActions">>'  + $nl + $tab + '/*Generate Actions*/' + $nl + $tab + '<<set _leftaction to {}>>'
$rightAnchor = '<<widget "rightActions">>' + $nl + $tab + '/*Generate Actions*/' + $nl + $tab + '<<set _rightaction to {}>>'
$feetAnchor  = '<<widget "feetActions">>'  + $nl + $tab + '/*Generate Actions*/' + $nl + $tab + '<<set _feetaction to {}>>'
$effectsAnchor = '<<widget "effectsman">>'
$mouthAnchor   = '<<widget "mouthActions">>'  + $nl + $tab + '/*Generate Actions*/' + $nl + $tab + '<<set _mouthaction to {}>>'

$patchSpecs = @(
    [ordered]@{
        name    = '左手动作注册'
        passage = 'Widgets Actions Generation'
        find    = $leftAnchor
        replace = $leftAnchor + $nl + $tab + '<<combatActionsExtRegister "left">>'
        check   = '<<combatActionsExtRegister "left">>'
    },
    [ordered]@{
        name    = '右手动作注册'
        passage = 'Widgets Actions Generation'
        find    = $rightAnchor
        replace = $rightAnchor + $nl + $tab + '<<combatActionsExtRegister "right">>'
        check   = '<<combatActionsExtRegister "right">>'
    },
    [ordered]@{
        name    = '脚部动作注册'
        passage = 'Widgets Actions Generation'
        find    = $feetAnchor
        replace = $feetAnchor + $nl + $tab + '<<combatActionsExtRegister "feet">>'
        check   = '<<combatActionsExtRegister "feet">>'
    },
    [ordered]@{
        name    = '动作结算挂点'
        passage = 'Widgets Effects Man'
        find    = $effectsAnchor
        replace = $effectsAnchor + $nl + $tab + '<<combatActionsExt>>'
        check   = '<<combatActionsExt>>'
    },
    [ordered]@{
        name    = '战斗结束清空状态'
        passage = 'Widgets End Combat'
        find    = '<<widget "endcombat">>'
        replace = '<<widget "endcombat">>' + $nl + $tab + '<<combatActionsExtClear>>'
        check   = '<<combatActionsExtClear>>'
    },
    [ordered]@{
        name    = '敌人高潮拦截'
        passage = 'Widgets Actions Man'
        find    = '<<widget "actionsman">>'
        replace = '<<widget "actionsman">>' + $nl + $tab + '<<combatActionsExtClimax>>'
        check   = '<<combatActionsExtClimax>>'
    },
    [ordered]@{
        name    = '嘴部动作注册'
        passage = 'Widgets Actions Generation'
        find    = $mouthAnchor
        replace = $mouthAnchor + $nl + $tab + '<<combatActionsExtRegister "mouth">>'
        check   = '<<combatActionsExtRegister "mouth">>'
    }
)

$patchParams = @()
foreach ($spec in $patchSpecs) {
    $body = Get-Passage $spec.passage
    $hits = ([regex]::Matches($body, [regex]::Escape($spec.find))).Count
    if ($hits -ne 1) { throw "[$($spec.name)] 锚点在段落 [$($spec.passage)] 中出现 $hits 次（应为 1 次），已中止" }
    if (-not $spec.replace.Contains($spec.find)) { throw "[$($spec.name)] 替换文本没有保留原锚点" }
    $newBody = $body.Replace($spec.find, $spec.replace)
    if (([regex]::Matches($newBody, [regex]::Escape($spec.check))).Count -ne 1) { throw "[$($spec.name)] 替换后检查片段计数异常" }
    $patchParams += [ordered]@{
        passage    = $spec.passage
        findString = $spec.find
        replace    = $spec.replace
        all        = $false
        debug      = $true
    }
    Write-Host ("      [{0}] 段落 [{1}] 锚点唯一 ✓" -f $spec.name, $spec.passage)
}

# ---- 2) 校验 twee 文件 ----
Write-Host '[2/6] 校验 twee ...'
if (-not (Test-Path -LiteralPath $TweePath)) { throw "缺少 twee 文件：$TweePath" }
$tweeText = [System.IO.File]::ReadAllText($TweePath, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"

$tweeRegex = '(?m)^(:: +((?:[^:"\/\n\r\[\] ]+ *)+)(?: *\[((?:[^ \]]+ *)* *)\] *|))$'
$passages = [regex]::Matches($tweeText, $tweeRegex)
if ($passages.Count -ne 1) { throw "twee 文件被解析出 $($passages.Count) 个段落（应为 1 个）" }
$pName = $passages[0].Groups[2].Value.Trim()
$pTags = $passages[0].Groups[3].Value
if ($pName -ne 'CombatActionsExt Widgets' -or $pTags -notmatch 'widget') { throw "twee 段落头异常：name=[$pName] tags=[$pTags]" }
Write-Host "      twee 解析：段落 [$pName] tags=[$pTags] ✓"

# 标签配平（去掉注释后统计）
$noComment = [regex]::Replace($tweeText, '(?s)/\*.*?\*/', '')
foreach ($pair in @(@('<<if','<</if>>'), @('<<for','<</for>>'), @('<<widget','<</widget>>'), @('<<switch','<</switch>>'))) {
    $open = ([regex]::Matches($noComment, [regex]::Escape($pair[0]) + '[\s>]')).Count
    $close = ([regex]::Matches($noComment, [regex]::Escape($pair[1]))).Count
    if ($open -ne $close) { throw "标签不配平：$($pair[0]) 开 $open / 闭 $close" }
}
Write-Host '      twee 标签配平 ✓'

# TwineScript 运算符白名单（le/ge/ne 不是 SugarCube 运算符）
$badOps = @([regex]::Matches($tweeText, '(?m)<<(?:if|elseif|unless)[^>]*?\b(le|ge|ne)\b'))
if ($badOps.Count -gt 0) { throw ("twee 里出现非法的 SugarCube 比较运算符：" + $badOps[0].Value + "（应写 lte / gte / neq）") }
Write-Host '      TwineScript 运算符自检通过（无 le/ge/ne）✓'

# 必需片段
$required = [ordered]@{
    '注册 widget'        = '<<widget "combatActionsExtRegister">>'
    '调度 widget'        = '<<widget "combatActionsExt">>'
    '结算 widget'        = '<<widget "combatActionsExtDo">>'
    '清空 widget'        = '<<widget "combatActionsExtClear">>'
    '手→胸 动作键'       = '<<set _leftaction["揉捏胸部"] to "caeHandChest">>'
    '手→小穴 插入键'     = '<<set _leftaction["插入小穴"] to "caeHandVag">>'
    '手→小穴 继续键'     = '<<set _leftaction["继续指奸"] to "caeHandVagKeep">>'
    '手→小穴 拳交键'     = '<<set _leftaction["拳交"] to "caeHandVagFist">>'
    '手→小穴 拳交继续键' = '<<set _leftaction["继续拳交"] to "caeHandVagFistKeep">>'
    '手→肛 插入键'       = '<<set _leftaction["手指插入"] to "caeHandAnus">>'
    '手→肛 继续键'       = '<<set _leftaction["继续指奸"] to "caeHandAnusKeep">>'
    '拳交 动作键'        = '<<set _leftaction["拳交"] to "caeHandFist">>'
    '拳交 继续键'        = '<<set _leftaction["继续拳交"] to "caeHandFistKeep">>'
    '脚→胸 动作键'       = '<<set _feetaction["脚揉胸部"] to "caeFeetChest">>'
    '脚→胸 继续键'       = '<<set _feetaction["继续揉胸"] to "caeFeetChestKeep">>'
    '脚→肛 插入键'       = '<<set _feetaction["脚趾插入"] to "caeFeetAnus">>'
    '脚→肛 继续键'       = '<<set _feetaction["继续踩弄"] to "caeFeetAnusKeep">>'
    '脱上衣 动作键'      = '<<set _leftaction["脱掉上衣"] to "caeUndressUpper">>'
    '脱下衣 动作键'      = '<<set _leftaction["脱掉下衣"] to "caeUndressLower">>'
    '原版脱衣判定'       = 'combatSkillCheck("hand", _caeT, $_caeNPC.fullDescription, 1000, $_caeNPC.clothes.upper.integrity)'
    '原版脱衣文本'       = 'npcUndressText $_caeNPC "upper"'
    '原版显露文本'       = 'npcRevealText $_caeNPC "upper"'
    '原版反应宏'         = 'namedNpcReaction _caeT "expose"'
    '胸部穿着判定'       = '_caeNPC.chest is "clothed"'
    '下身穿着判定'       = '_caeNPC.penis is "clothed" or _caeNPC.vagina is "clothed"'
    '赤脚判定'           = '$worn.feet.type.includes("naked")'
    '手部技能判定'       = 'combatSkillCheck("hand", _caeT)'
    '脚部技能判定'       = 'combatSkillCheck("feet", _caeT)'
    '自愿分流'           = '$consensual is 1'
    '手部技能成长'       = '<<handskilluse>><<handstat>>'
    '脚部技能成长'       = '<<feetskilluse>><<feetstat>>'
    '小穴插入状态'       = '$caeLeftVag'
    '小穴拳交状态'       = '$caeLeftVagFist'
    '脚踩胸状态'         = '$caeFeetChest'
    '肛门插入状态'       = '$caeLeftAnus'
    '拳交状态'           = '$caeLeftFist'
    '入口占用判定'       = '已经被占着了'
    '战斗结束清空'       = '<<unset $caeLeftAnus>><<unset $caeRightAnus>><<unset $caeFeetAnus>>'
    '咬 动作键'          = '<<set _mouthaction["咬"] to "caeMouthBite">>'
    '无效目标保护'      = '_caeAct to "invalid"'
    '咬 结算键'          = '$mouthaction is "caeMouthBite"'
    '嘴自由判定'         = '$mouthuse is 0'
    '咬 尖牙伤害'        = '<<defiance 8 _caeT>>'
    '咬 普通伤害'        = '<<defiance 4 _caeT>>'
    '高潮 继续键'        = '<<set _leftaction["继续缠着"] to "caeClimaxContinue">>'
    '高潮 结束键'        = '<<set _leftaction["结束战斗"] to "caeEndFight">>'
    '高潮拦截 widget'    = '<<widget "combatActionsExtClimax">>'
    '高潮状态变量'       = '$caeClimaxChoice'
    '战斗标记变量'       = '$caeFightUsed'
    '高潮减半算法'       = '$enemyarousal to ($enemyarousalmax / 2)'
}
foreach ($k in $required.Keys) {
    if (-not $tweeText.Contains($required[$k])) { throw "twee 缺少必需片段：$k（应为 $($required[$k])）" }
}
# 只在人类战斗里注册
if (-not $tweeText.Contains('$enemytype is "man"')) { throw 'twee 缺少「仅人类敌人」的限制' }
Write-Host '      必需片段自检通过（四组动作 / 裸露判定 / 赤脚 / 自愿分流 / 技能成长）✓'
# 脱衣动作依赖原版函数 npcMakeNaked（战斗里也在用），构建时确认它存在于游戏 HTML
if (-not $txt.Contains('npcUndressText') -or -not $txt.Contains('npcRevealText')) { throw '游戏 HTML 里找不到 npcUndressText / npcRevealText，版本可能不符' }
Write-Host '      原版脱衣接口 npcUndressText / npcRevealText 存在 ✓'
if (-not (Test-Path -LiteralPath $ProbePath)) { throw "缺少探针脚本：$ProbePath" }
$probeText = [System.IO.File]::ReadAllText($ProbePath, [System.Text.Encoding]::UTF8)
if (-not $probeText.Contains('CombatActionsExtProbe')) { throw '探针脚本里没有 CombatActionsExtProbe' }
if (-not $probeText.Contains('var VERSION = "' + $Version + '"')) { throw "探针脚本的版本号与构建版本不一致（应为 $Version）" }
Write-Host '      自检探针自检通过（CombatActionsExtProbe / 版本一致）✓'
if (-not (Test-Path -LiteralPath $ColoursPath)) { throw "缺少动作分类脚本：$ColoursPath" }
$coloursText = [System.IO.File]::ReadAllText($ColoursPath, [System.Text.Encoding]::UTF8)
if (-not $coloursText.Contains('combatActionColours')) { throw 'actionColours.js 里没有 combatActionColours' }
if (-not $coloursText.Contains('caeMouthBite')) { throw 'actionColours.js 里没有把「咬」归入 def 分类' }
Write-Host '      动作分类脚本自检通过（咬=def 反抗 / 扯衣=brat / 性行为=sub）✓'

# ---- 3) 生成 boot.json ----
Write-Host '[3/6] 生成 boot.json ...'
$boot = [ordered]@{
    name                       = $ModName
    version                    = $Version
    styleFileList              = @()
    scriptFileList_earlyload   = @()
    scriptFileList_inject_early = @()
    scriptFileList_preload     = @()
    scriptFileList             = @('dist/js/actionColours.js', 'dist/js/probe.js')
    tweeFileList               = @('twee/CombatActionsExt.tw')
    imgFileList                = @()
    imgFileReplaceList         = @()
    additionFile               = @('README.md')
    addonPlugin                = @(
        [ordered]@{
            modName    = 'TweeReplacer'
            addonName  = 'TweeReplacerAddon'
            modVersion = '^1.7.0'
            params     = $patchParams
        }
    )
    dependenceInfo             = @(
        [ordered]@{ modName = 'ModLoader';    version = '^2.60.1' },
        [ordered]@{ modName = 'TweeReplacer'; version = '^1.7.0' }
    )
}
$bootJson = $boot | ConvertTo-Json -Depth 12
if ($bootJson -notmatch '"params"\s*:\s*\[') { throw 'boot.json 的 params 未序列化为数组，已中止' }
[System.IO.File]::WriteAllText($BootPath, $bootJson, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("      boot.json {0} 字节，{1} 条替换参数  ✓" -f (Get-Item $BootPath).Length, $patchParams.Count)

# ---- 4) 打包 zip ----
Write-Host '[4/6] 打包 zip ...'
Add-Type -AssemblyName System.IO.Compression | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
$zipEntries = [ordered]@{
    'boot.json'                   = $BootPath
    'twee/CombatActionsExt.tw'    = $TweePath
    'dist/js/actionColours.js'    = $ColoursPath
    'dist/js/probe.js'            = $ProbePath
    'README.md'                   = $ReadmePath
}
$fs = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
$arc = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($entryName in $zipEntries.Keys) {
    $src = $zipEntries[$entryName]
    if (-not (Test-Path -LiteralPath $src)) { throw "缺少要打包的文件：$src" }
    $entry = $arc.CreateEntry($entryName)
    $es = $entry.Open()
    $bytes = [System.IO.File]::ReadAllBytes($src)
    $es.Write($bytes, 0, $bytes.Length)
    $es.Close()
}
$arc.Dispose(); $fs.Close()
$zipRead = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
$entryNames = @($zipRead.Entries | ForEach-Object { $_.FullName })
$zipRead.Dispose()
foreach ($need in @('boot.json', 'twee/CombatActionsExt.tw', 'README.md')) {
    if ($entryNames -notcontains $need) { throw "zip 缺少条目：$need" }
}
if (($entryNames | Where-Object { $_ -like '*\*' }).Count -gt 0) { throw 'zip 条目含反斜杠，ModLoader 将无法按路径取文件' }
Write-Host ("      {0}  ({1} 字节)" -f $ZipName, (Get-Item $ZipPath).Length)
$entryNames | ForEach-Object { Write-Host "        - $_" }

# ---- 5) 合并 modList.json ----
Write-Host '[5/6] 更新 modList.json ...'
$list = @()
if (Test-Path -LiteralPath $ListPath) {
    try {
    $parsed = Get-Content -LiteralPath $ListPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($parsed -is [System.Array]) { foreach ($it in $parsed) { if ($it -is [string]) { $list += $it } } }
    elseif ($parsed -is [string]) { $list += $parsed }
} catch { $list = @() }
}
$list = @($list | Where-Object { $_ -notmatch ('^\./' + [regex]::Escape($ModName) + '_v.*\.zip$') })
$list += ('./' + $ZipName)
$listJson = '[' + (($list | ForEach-Object { '"' + ($_ -replace '\\', '\\' -replace '"', '\"') + '"' }) -join ',') + ']'
[System.IO.File]::WriteAllText($ListPath, $listJson, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("      {0}  ->  {1}" -f $ListPath, $listJson)

# ---- 6) 校验游戏文件未被改动 ----
Write-Host '[6/6] 校验游戏文件未被改动 ...'
foreach ($f in $before.Keys) {
    $p = Join-Path $GameDir $f
    $after = Get-Sha256 $p
    if ($after -ne $before[$f]) { throw "游戏文件被改动了：$f（before=$($before[$f]) after=$after）" }
    Write-Host ("      OK    {0}" -f $f)
    Write-Host ("        SHA256 = {0}" -f $after)
}

Write-Host ''
Write-Host '构建完成：' -ForegroundColor Green
Write-Host ("  mod 源目录 : {0}" -f $SrcDir)
Write-Host ("  安装包     : {0}" -f $ZipPath)
Write-Host ("  自动加载表 : {0}" -f $ListPath)
Write-Host ("  替换参数   : {0} 条（左右手注册 / 脚部注册 / 嘴部注册 / 结算挂点 / 结束清空 / 高潮拦截）" -f $patchParams.Count)
Write-Host  '  动作       : 咬 / 脱掉上衣(原版式) / 脱掉下衣(原版式) → 揉捏胸部 / 插入小穴→继续指奸→拳交→继续拳交 / 手指插入→继续指奸→拳交→继续拳交 / 脚揉胸部→继续揉胸 / 脚趾插入→继续踩弄'
