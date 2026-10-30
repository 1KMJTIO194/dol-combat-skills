# ============================================================================
#  LocationsExt 构建脚本（旅店 + 公寓可购买房间；不修改任何游戏文件）
#  ---------------------------------------------------------------------------
#  1) 从 Degrees of Lewdity.html 提取 High Street / Flats 段落原文
#  2) 断言 2 个插入锚点在该段落中恰好出现 1 次（版本不符立即中止，不产出文件）
#  3) 校验 twee：段落名、标签配平、TwineScript 运算符、必需片段
#  4) 生成 boot.json（2 条 TweeReplacer 补丁）
#  5) 打包 LocationsExt_v<ver>.zip（zip 根目录即 boot.json，条目用正斜杠）
#  6) 合并 modList.json（保留其它 mod 条目，只替换本 mod 的旧条目）
#  7) 输出 HTML / boot.json 的 SHA256 前后比对，证明游戏文件零改动
#  用法： pwsh -File .\build-locations.ps1 [-GameDirOverride <游戏目录>] [-OutDir <输出目录>]
# ============================================================================
param(
    [string]$GameDirOverride = '',
    [string]$OutDir = ''
)
$ErrorActionPreference = 'Stop'

$ModName   = 'LocationsExt'
$Version   = '1.7.0'
$ScriptDir = $PSScriptRoot
$GameDir   = if ($GameDirOverride) { $GameDirOverride } else { Split-Path -Parent $ScriptDir }
if (-not $OutDir) { $OutDir = $GameDir }
$HtmlPath  = Join-Path $GameDir 'Degrees of Lewdity.html'
$SrcDir    = Join-Path $ScriptDir $ModName
$TweePath  = Join-Path $SrcDir 'twee\LocationsExt.tw'
$ReadmePath = Join-Path $SrcDir 'README.md'
$BootPath  = Join-Path $SrcDir 'boot.json'
$ZipName   = '{0}_v{1}.zip' -f $ModName, $Version
$ZipPath   = Join-Path $OutDir $ZipName
$ListPath  = Join-Path $OutDir 'modList.json'

function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

Write-Host '=== LocationsExt build ===' -ForegroundColor Cyan

# ---- 0) 构建前的游戏文件指纹 ----
$before = [ordered]@{}
foreach ($f in @('Degrees of Lewdity.html', 'boot.json')) {
    $p = Join-Path $GameDir $f
    if (Test-Path -LiteralPath $p) { $before[$f] = Get-Sha256 $p }
}

# ---- 1) 读取游戏 HTML 并提供段落提取 ----
Write-Host '[1/6] 读取游戏 HTML 并提取段落 ...'
if (-not (Test-Path -LiteralPath $HtmlPath)) { throw "找不到游戏 HTML：$HtmlPath" }
$txtRaw = [System.IO.File]::ReadAllText($HtmlPath, [System.Text.Encoding]::UTF8)
$txt = [System.Net.WebUtility]::HtmlDecode($txtRaw)
$passageCache = @{}
function Get-Passage([string]$Name) {
    if ($passageCache.ContainsKey($Name)) { return $passageCache[$Name] }
    $needle = 'name="' + $Name + '"'
    $i = $txtRaw.IndexOf($needle)
    if ($i -lt 0) { throw "游戏 HTML 里找不到段落：$Name" }
    $s = $txtRaw.LastIndexOf('<tw-passagedata', $i)
    $gt = $txtRaw.IndexOf('>', $s)
    $e = $txtRaw.IndexOf('</tw-passagedata>', $gt)
    if ($gt -lt 0 -or $e -lt 0) { throw "段落 $Name 解析失败" }
    $body = [System.Net.WebUtility]::HtmlDecode($txtRaw.Substring($gt + 1, $e - $gt - 1))
    $passageCache[$Name] = $body
    return $body
}

$nl  = [string][char]10
$tab = [string][char]9

$flatsLink   = '<br><<if $caeFlatsRoom is 1>><<link [[回到自己的房间|Flats Own Room]]>><</link>><<else>><<link [[看看待售的房间|Flats Room Sale]]>><</link>><</if>><br>'

$patchSpecs = @(
    [ordered]@{
        name    = '商业街 → 旅店入口'
        passage = 'High Street'
        find    = '<<stormdrain>>'
        replace = '<<stormdrain>><<add_link "<<dooricon ''open''>><<link [[旅店|Inn]]>><</link>><br>">>'
        check   = '[[旅店|Inn]]'
        checkAll = @('<<add_link "<<dooricon ''open''>><<link [[旅店|Inn]]>><</link>><br>">>')
    },
    [ordered]@{
        name    = '公寓楼 → 待售房间入口'
        passage = 'Flats'
        find    = '<<set $eventskip to 0>>'
        replace = $flatsLink + $highAnchor
        check   = '[[看看待售的房间|Flats Room Sale]]'
        checkAll = @('[[看看待售的房间|Flats Room Sale]]', '[[回到自己的房间|Flats Own Room]]')
    },
    [ordered]@{
        name    = '森林 → 快速旅行入口'
        passage = 'Forest'
        find    = '<<set $eventskip to 0>>'
        replace = '<<if $eventskip is 1>><br><<link [[快速旅行|Forest Fast Travel]]>><</link>><br><</if>><<set $eventskip to 0>>'
        check   = '<<link [[快速旅行|Forest Fast Travel]]>>'
        checkAll = @('[[快速旅行|Forest Fast Travel]]')
    }
)

$patchParams = @()
foreach ($spec in $patchSpecs) {
    $body = Get-Passage $spec.passage
    $hits = ([regex]::Matches($body, [regex]::Escape($spec.find))).Count
    if ($hits -ne 1) { throw "[$($spec.name)] 锚点在段落 [$($spec.passage)] 中出现 $hits 次（应为 1 次），已中止" }
    $newBody = $body.Replace($spec.find, $spec.replace)
    if (-not $newBody.Contains($spec.check)) { throw "[$($spec.name)] 替换后缺少检查片段：$($spec.check)" }
    if ($spec.Contains('checkAll')) {
        foreach ($needle in $spec.checkAll) {
            if (-not $newBody.Contains($needle)) { throw "[$($spec.name)] 替换后缺少片段：$needle" }
        }
    }
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
$parsed = [regex]::Matches($tweeText, $tweeRegex)
$expectPassages = @('Inn', 'Inn Stairs', 'Inn Sleep', 'Inn Shower', 'Inn Room', 'Inn Bathroom', 'Inn Bath', 'Flats Room Sale', 'Flats Own Room', 'Flats Own Room Sleep', 'Flats Own Shower', 'Flats Own Wardrobe', 'Flats Own Read', 'Flats Own Upgrade', 'Forest Fast Travel')
if ($parsed.Count -ne $expectPassages.Count) { throw "twee 被解析出 $($parsed.Count) 个段落（应为 $($expectPassages.Count) 个）" }
$gotNames = @($parsed | ForEach-Object { $_.Groups[2].Value.Trim() })
foreach ($need in $expectPassages) {
    if ($gotNames -notcontains $need) { throw "twee 缺少段落：$need（实际：$($gotNames -join ' / ')）" }
}
Write-Host ("      twee 解析：{0} 个段落（{1}）✓" -f $gotNames.Count, ($gotNames -join ' / '))

$noComment = [regex]::Replace($tweeText, '(?s)/\*.*?\*/', '')
foreach ($pair in @(@('<<if','<</if>>'), @('<<for','<</for>>'), @('<<widget','<</widget>>'))) {
    $open = ([regex]::Matches($noComment, [regex]::Escape($pair[0]) + '[\s>]')).Count
    $close = ([regex]::Matches($noComment, [regex]::Escape($pair[1]))).Count
    if ($open -ne $close) { throw "标签不配平：$($pair[0]) 开 $open / 闭 $close" }
}
Write-Host '      twee 标签配平 ✓'

$badOps = @([regex]::Matches($tweeText, '(?m)<<(?:if|elseif|unless)[^>]*?\b(le|ge|ne)\b'))
if ($badOps.Count -gt 0) { throw ("twee 里出现非法的 SugarCube 比较运算符：" + $badOps[0].Value + "（应写 lte / gte / neq）") }
Write-Host '      TwineScript 运算符自检通过（无 le/ge/ne）✓'

$required = [ordered]@{
    '旅店段落'          = ':: Inn'
    '旅店睡眠段落'      = ':: Inn Sleep'
    '房间出售段落'      = ':: Flats Room Sale'
    '自己房间段落'      = ':: Flats Own Room'
    '自己房间睡眠段落'  = ':: Flats Own Room Sleep'
    '原版睡眠宏'        = '<<sleep>>'
    '原版醒来效果'      = '<<wakingEffects $sleepHoursTotal>>'
    '旅店房价'          = '<<money -4000>>'
    '公寓房价'          = '<<money -6200000>>'
    '房间购买状态'      = '$caeFlatsRoom'
    '旅店淋浴段落'      = ':: Inn Shower'
    '旅店房间段落'      = ':: Inn Room'
    '旅店楼梯段落'      = ':: Inn Stairs'
    '当天房钱标记'      = '$caeInnPaidDate'
    '当天日期变量'      = '$caeInnToday'
    '日期比较来源'      = 'Time.date.year'
    '自由进出链接'      = '[[上楼回房间（0:01）|Inn Room]]'
    '试着直接上楼'      = '[[试着直接上楼|Inn Stairs]]'
    '拦路付费上楼'      = '[[交 £40 上楼|Inn Room]]'
    '被赶回前台'        = '[[被赶回前台|Inn]]'
    '旅店浴室段落'      = ':: Inn Bathroom'
    '旅店泡澡段落'      = ':: Inn Bath'
    '卧室时间链接'      = '[[卧室 (0:01)|Inn Room]]'
    '浴室时间链接'      = '[[浴室 (0:01)|Inn Bathroom]]'
    '下楼时间链接'      = '[[下楼 (0:01)|Inn]]'
    '泡澡选项'          = '[[泡个澡 (0:30)|Inn Bath]]'
    '冲澡选项'          = '[[冲个澡 (0:10)|Inn Bathroom]]'
    '浴室梳妆台'        = '<<personalUpkeep>>'
    '妊娠检测'          = '<<pregnancyTest "Inn Bathroom">>'
    '原版脱衣宏'        = '<<strip>>'
    '浴室图标'          = '<<bathroomicon'
    '公寓淋浴段落'      = ':: Flats Own Shower'
    '公寓衣柜段落'      = ':: Flats Own Wardrobe'
    '书架放松段落'      = ':: Flats Own Read'
    '房间升级段落'      = ':: Flats Own Upgrade'
    '洗澡宏'            = '<<wash>>'
    '衣柜选择宏'        = '<<wardrobeSelection>>'
    '衣柜穿戴宏'        = '<<wardrobewear>>'
    '衣柜退出清理'      = '<<cleanupOnWardrobeExit>>'
    '衣柜位置变量'      = '$wardrobe_location to "wardrobe"'
    '床垫升级状态'      = '$caeFlatsBed'
    '淋浴升级状态'      = '$caeFlatsBath'
    '书架升级状态'      = '$caeFlatsShelf'
    '床垫价格'          = '<<money -30000>>'
    '淋浴价格'          = '<<money -20000>>'
    '书架价格'          = '<<money -15000>>'
    '旅店淋浴价格'      = '<<money -500>>'
    '每日读书标记'      = '$daily.caeFlatsRead'
    '森林快速旅行段落'  = ':: Forest Fast Travel'
    '快速返回森林之外'  = '[[快速返回森林之外（Danube Street）|Danube Street]]'
    '森林边缘判断'      = '$forest gt 0'
    '边缘提示'          = '你已经在森林边缘'
    '秘密小路条件'      = '($historytrait or 0) gte 3'
    '森林内-湖泊'       = '[[湖泊：岸边|Lake Shore]]'
    '森林内-教堂墓地'   = '[[旧教堂墓地|Churchyard]]'
    '森林内-伊甸'       = '[[伊甸的小屋|Eden Clearing]]'
    '森林内-狼洞'       = '[[狼洞|Wolf Cave Clearing]]'
    '森林内-小溪'       = '[[小溪|Forest Brook]]'
    '湖泊分支'          = '[[湖泊：岸边|Lake Shore]]'
    '教堂墓地'          = '[[旧教堂墓地|Churchyard]]'
    '伊甸小屋'          = '[[伊甸的小屋|Eden Clearing]]'
    '狼洞'              = '[[狼洞|Wolf Cave Clearing]]'
    '小溪'              = '[[小溪|Forest Brook]]'
    '快速旅行回到森林'  = '[[继续在林间探索|Forest]]'
    '森林朝向变量'      = '"secretin"'
    '原版森林深度'      = '$forest'
    '步数算法'          = 'Math.ceil(Math.abs('
    '每步耗时'          = '_steps * _perStep'
    '森林深度显示'      = '森林深度'
    '前进次数显示'      = '次快速前进 / '
    '快速前进耗时'      = '快速前进'
    '运动技能读取'      = 'currentSkillValue("athletics")'
    '运动技能加成'      = 'Math.max(2, 5 - Math.floor(_ath / 250))'
    '高跟鞋步长'        = 'Math.max(20, 30 - (2 * Math.floor(_ath / 250)))'
}
foreach ($k in $required.Keys) {
    if (-not $tweeText.Contains($required[$k])) { throw "twee 缺少必需片段：$k（应为 $($required[$k])）" }
if ($tweeText.Contains('<<br>>')) { throw 'twee 里使用了不存在的 <<br>> 宏，应写 HTML <br>' }
}
Write-Host '      必需片段自检通过（5 段落 / 睡眠 / 房价 / 购买状态 / 入口链接）✓'

# 原版依赖接口存在性
foreach ($need in @('<<widget "sleep">>', '<<widget "wakingEffects">>', '<<widget "wash">>', 'wardrobeSelection', 'wardrobewear', 'cleanupOnWardrobeExit')) {
    if (-not $txt.Contains($need)) { throw "游戏 HTML 里找不到 $need，版本可能不符" }
}
Write-Host '      原版接口存在（sleep / wakingEffects / wash / wardrobe 宏）✓'

# ---- 3) 生成 boot.json ----
Write-Host '[3/6] 生成 boot.json ...'
$boot = [ordered]@{
    name                       = $ModName
    version                    = $Version
    styleFileList              = @()
    scriptFileList_earlyload   = @()
    scriptFileList_inject_early = @()
    scriptFileList_preload     = @()
    scriptFileList             = @()
    tweeFileList               = @('twee/LocationsExt.tw')
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
    'boot.json'                = $BootPath
    'twee/LocationsExt.tw'     = $TweePath
    'README.md'                = $ReadmePath
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
foreach ($need in @('boot.json', 'twee/LocationsExt.tw', 'README.md')) {
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
        $parsedList = Get-Content -LiteralPath $ListPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($parsedList -is [System.Array]) { foreach ($it in $parsedList) { if ($it -is [string]) { $list += $it } } }
        elseif ($parsedList -is [string]) { $list += $parsedList }
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
Write-Host ("  替换参数   : {0} 条（商业街旅店入口 / 公寓楼房间入口）" -f $patchParams.Count)
Write-Host  '  新地点     : High Street「旅店」（£40/天：当天自由进出，隔天需重新付钱，贝利式拦路） ／ Flats「待售房间」（£62000 买断 + 衣柜/淋浴/书架升级） ／ 森林「快速旅行」'
