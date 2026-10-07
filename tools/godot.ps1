#Requires -Version 5.1
<#
    Star Game · Godot 启动器（内部脚本）

    一般不需要直接调用它 —— 双击仓库根目录的：
        run.bat      运行游戏
        editor.bat   打开 Godot 编辑器
        test.bat     跑单元测试

    手动调用示例：
        powershell -ExecutionPolicy Bypass -File tools\godot.ps1 -Action test
        powershell -ExecutionPolicy Bypass -File tools\godot.ps1 -Action play --headless

    查找 Godot 的顺序（先命中者优先）：
        1. -GodotPath 参数
        2. 环境变量 SG_GODOT
        3. 仓库根目录的 .godot-path 文件（里面写一行绝对路径）
        4. 常见安装目录 + PATH
        都没找到时，会询问是否自动下载官方 4.7.2 标准版。
#>
[CmdletBinding()]
param(
    [ValidateSet('play', 'editor', 'test', 'import', 'check', 'where')]
    [string]$Action = 'play',

    # 手动指定 Godot 可执行文件（优先级最高）
    [string]$GodotPath = '',

    # 无头模式：不开窗口，适合远程 / CI
    [switch]$Headless,

    # 其余参数原样透传给 Godot
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ── 常量 ────────────────────────────────────────────────
$ProjectRoot   = Split-Path -Parent $PSScriptRoot
$ProjectFile   = Join-Path $ProjectRoot 'project.godot'
$ImportMarker  = Join-Path $ProjectRoot '.godot\global_script_class_cache.cfg'
$PinFile       = Join-Path $ProjectRoot '.godot-path'
$PinnedVersion = '4.7.2'
$DownloadUrl   = "https://github.com/godotengine/godot/releases/download/$PinnedVersion-stable/Godot_v$PinnedVersion-stable_win64.exe.zip"

# ── 输出小工具 ──────────────────────────────────────────
function Say      { param([string]$Text) Write-Host $Text -ForegroundColor Gray }
function SayHead  { param([string]$Text) Write-Host $Text -ForegroundColor Cyan }
function SayOk    { param([string]$Text) Write-Host $Text -ForegroundColor Green }
function SayWarn  { param([string]$Text) Write-Host $Text -ForegroundColor Yellow }
function SayFail  { param([string]$Text) Write-Host $Text -ForegroundColor Red }
function SayRule  { Write-Host ('─' * 58) -ForegroundColor DarkGray }

# ── 预检：仓库里的 .bat 必须是纯 ASCII ─────────────────
# 原因：cmd.exe 按「字节」跟踪自己在批处理文件中的读取位置，却按「代码页」
# 解码字符。文件里只要出现多字节字符（中文即 UTF-8 三字节），两者就错位，
# 结果是后续行被腰斩、rem 注释被当作命令执行（报一堆"不是内部或外部命令"）。
# 所以 .bat 一律保持纯 ASCII，所有中文提示写在 tools\godot.ps1 里
# （本文件是 UTF-8 带 BOM，PowerShell 能正确解码）。
function Get-NonAsciiBat {
    $bad = New-Object System.Collections.Generic.List[string]
    $bats = Get-ChildItem -LiteralPath $ProjectRoot -Filter '*.bat' -File -ErrorAction SilentlyContinue
    foreach ($f in $bats) {
        $count = 0
        foreach ($b in [System.IO.File]::ReadAllBytes($f.FullName)) {
            if ($b -gt 127) { $count++ }
        }
        if ($count -gt 0) { $bad.Add("$($f.Name)（$count 个非 ASCII 字节）") }
    }
    # 直接返回 ToArray()：PowerShell 会把单元素数组展开成标量，
    # 调用方用 @(...) 再包回数组即可。这里千万不要加前置逗号 ——
    # 那会把空数组包成「含一个空数组的数组」，导致 Count=1 误报。
    return $bad.ToArray()
}

# ── 版本解析：Godot_v4.7.2-stable_win64.exe → 4.7.2 ────
function Get-GodotVersion {
    param([string]$Path)
    $m = [regex]::Match($Path, 'Godot[_\-]?v?(\d+)\.(\d+)(?:\.(\d+))?')
    if (-not $m.Success) { return [version]'0.0.0' }
    $patch = '0'
    if ($m.Groups[3].Success) { $patch = $m.Groups[3].Value }
    return [version]("$($m.Groups[1].Value).$($m.Groups[2].Value).$patch")
}

# ── 扫描常见目录，挑出最合适的 Godot ────────────────────
function Find-GodotInDirs {
    $dirs = New-Object System.Collections.Generic.List[string]
    foreach ($d in @(
        'D:\Godot',
        'C:\Godot',
        (Join-Path $env:ProgramFiles 'Godot'),
        (Join-Path ${env:ProgramFiles(x86)} 'Godot'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Godot'),
        (Join-Path $env:USERPROFILE 'Godot'),
        (Join-Path $env:USERPROFILE 'Downloads\Godot'),
        (Join-Path $env:USERPROFILE 'scoop\apps\godot\current'),
        $env:SG_GODOT_DIR
    )) {
        if (-not [string]::IsNullOrWhiteSpace($d)) { $dirs.Add($d) }
    }

    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($dir in $dirs) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        try {
            Get-ChildItem -LiteralPath $dir -Filter 'Godot*.exe' -File -Recurse -Depth 1 -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'Godot' -and $_.Name -notmatch '\.tmp$' } |
                ForEach-Object { $hits.Add($_.FullName) }
        } catch { }
    }

    # PATH 里可能也有一份
    foreach ($name in @('godot', 'godot4')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { $hits.Add($cmd.Source) }
    }

    if ($hits.Count -eq 0) { return @() }

    # 版本高的优先；同版本时 console 版优先（stdout 可见，便于排错）
    return $hits |
        Select-Object -Unique |
        Sort-Object -Property `
            @{ Expression = { Get-GodotVersion $_ }; Descending = $true },
            @{ Expression = { if ($_ -match 'console') { 1 } else { 0 } }; Descending = $true }
}

# ── 统一的解析入口 ──────────────────────────────────────
function Resolve-Godot {
    # 1) 显式参数
    if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
        if (-not (Test-Path -LiteralPath $GodotPath)) {
            throw "指定的 Godot 路径不存在：$GodotPath"
        }
        return (Resolve-Path -LiteralPath $GodotPath).Path
    }

    # 2) 环境变量
    if (-not [string]::IsNullOrWhiteSpace($env:SG_GODOT) -and (Test-Path -LiteralPath $env:SG_GODOT)) {
        return (Resolve-Path -LiteralPath $env:SG_GODOT).Path
    }

    # 3) 仓库内的 .godot-path 固定文件
    if (Test-Path -LiteralPath $PinFile) {
        $pinned = (Get-Content -LiteralPath $PinFile -TotalCount 1)
        if ($pinned) {
            $pinned = $pinned.Trim().Trim('"')
            if ($pinned -and -not $pinned.StartsWith('#')) {
                if (-not [System.IO.Path]::IsPathRooted($pinned)) {
                    $pinned = Join-Path $ProjectRoot $pinned
                }
                if (Test-Path -LiteralPath $pinned) {
                    return (Resolve-Path -LiteralPath $pinned).Path
                }
                SayWarn ".godot-path 里写的路径找不到，已忽略：$pinned"
            }
        }
    }

    # 4) 常见目录扫描
    $found = @(Find-GodotInDirs)
    if ($found.Count -gt 0) { return $found[0] }

    return $null
}

# ── 自动下载官方标准版 ──────────────────────────────────
function Install-Godot {
    $dest = 'D:\Godot'
    if (-not (Test-Path -LiteralPath 'D:\')) {
        $dest = Join-Path $env:USERPROFILE 'Godot'
    }

    SayHead "准备下载 Godot $PinnedVersion 标准版（约 120 MB）"
    Say "  下载地址：$DownloadUrl"
    Say "  解压到　：$dest"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch { }

    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $zip = Join-Path $env:TEMP "Godot_v$PinnedVersion-stable_win64.exe.zip"

    try {
        Say '正在下载，请稍候…'
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $zip -UseBasicParsing
        Say '下载完成，正在解压…'
        Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    } catch {
        SayFail "自动下载失败：$($_.Exception.Message)"
        Say '请手动下载后解压，再重试本脚本：'
        Say '  https://godotengine.org/download/windows/'
        return $null
    }

    $exe = Get-ChildItem -LiteralPath $dest -Filter 'Godot_v*_win64*.exe' -File -ErrorAction SilentlyContinue |
        Sort-Object -Property @{ Expression = { if ($_ -match 'console') { 1 } else { 0 } }; Descending = $true } |
        Select-Object -First 1
    if ($exe) { return $exe.FullName }
    return $null
}

# ── 首次运行：自动导入资源 ──────────────────────────────
function Ensure-Imported {
    param([string]$GodotExe)

    if (Test-Path -LiteralPath $ImportMarker) { return }
    if ($Action -eq 'editor') { return }   # 编辑器会自己导入

    SayWarn '检测到项目尚未导入（全新克隆后首次运行）'
    Say '正在导入资源，约 10～40 秒…'
    & $GodotExe '--headless' '--path' $ProjectRoot '--import' 2>&1 | Out-Null
    if (Test-Path -LiteralPath $ImportMarker) {
        SayOk '资源导入完成'
    } else {
        SayWarn '导入未生成标记文件，继续尝试启动（Godot 会在启动时自行导入）'
    }
    Write-Host ''
}

# ════════════════════════════════════════════════════════
#  主流程
# ════════════════════════════════════════════════════════
SayRule
SayHead '  Star Game · Godot 启动器'
SayRule

if (-not (Test-Path -LiteralPath $ProjectFile)) {
    SayFail "当前目录看起来不是 Godot 项目（找不到 project.godot）："
    Say "  $ProjectRoot"
    exit 2
}

# ── 预检：批处理文件编码 ────────────────────────────────
$badBats = @(Get-NonAsciiBat)
if ($badBats.Count -gt 0) {
    SayWarn '⚠ 以下 .bat 文件含非 ASCII 字符，cmd.exe 解析会错乱：'
    foreach ($b in $badBats) { Say "    $b" }
    Say '  这些文件必须保持纯 ASCII；中文提示请写进 tools\godot.ps1。'
    Write-Host ''
}

# ── 找引擎 ──────────────────────────────────────────────
try {
    $godot = Resolve-Godot
} catch {
    SayFail $_.Exception.Message
    exit 3
}

if (-not $godot) {
    SayFail '没有在本机找到 Godot。'
    Write-Host ''
    Say '请从官网下载「Godot Engine」标准版（不要下 .NET 版，本项目用不到）：'
    Say '  https://godotengine.org/download/windows/'
    Write-Host ''
    Say '下载解压后，任意一种方式告诉脚本它在哪：'
    Say '  a) 解压到 D:\Godot'
    Say '  b) 设置环境变量 SG_GODOT = 完整 exe 路径'
    Say '  c) 在仓库根目录建 .godot-path 文件，写一行 exe 绝对路径'
    Write-Host ''

    if ($Action -eq 'where') { exit 1 }

    # 非交互场景（CI / 无控制台）不要卡住，直接给出指引退出
    if ($env:SG_NO_DOWNLOAD -or -not [Environment]::UserInteractive) {
        SayWarn '当前为非交互环境，跳过自动下载。装好 Godot 后再运行。'
        exit 1
    }

    $ans = ''
    try {
        $ans = Read-Host '是否现在自动下载 Godot 4.7.2 到本机？(Y/N)'
    } catch {
        $ans = ''
    }
    if ($ans -notmatch '^[Yy]') {
        SayWarn '已取消。装好 Godot 之后再运行本脚本即可。'
        exit 1
    }
    $godot = Install-Godot
    if (-not $godot) {
        SayFail '自动下载没有成功，请按上面的方式手动安装。'
        exit 1
    }
    SayOk "已安装：$godot"
    Write-Host ''
}

$godotVer = Get-GodotVersion $godot
Say "引擎：$godot"
Say "版本：$godotVer"

if ($godotVer -lt [version]'4.0.0') {
    SayFail '本项目需要 Godot 4.x，当前版本过旧。'
    exit 3
}
if ($godotVer -lt [version]$PinnedVersion) {
    SayWarn "提示：官方当前稳定版是 $PinnedVersion，你这份是 $godotVer，建议升级（补丁版可直接替换）。"
}

# ── where：只报告，不启动 ───────────────────────────────
if ($Action -eq 'where') {
    SayOk 'Godot 定位正常。'
    exit 0
}

Ensure-Imported -GodotExe $godot

# ── 组装参数 ────────────────────────────────────────────
$gArgs = New-Object System.Collections.Generic.List[string]

switch ($Action) {
    'play' {
        $gArgs.Add('--path'); $gArgs.Add($ProjectRoot)
    }
    'editor' {
        $gArgs.Add('-e'); $gArgs.Add('--path'); $gArgs.Add($ProjectRoot)
    }
    'import' {
        $gArgs.Add('--headless'); $gArgs.Add('--path'); $gArgs.Add($ProjectRoot); $gArgs.Add('--import')
    }
    'test' {
        $gArgs.Add('--headless'); $gArgs.Add('--path'); $gArgs.Add($ProjectRoot)
        $gArgs.Add('-s'); $gArgs.Add('addons/gut/gut_cmdln.gd'); $gArgs.Add('-gexit')
    }
    'check' {
        # 静态导入检查 + 全量测试
        $gArgs.Add('--headless'); $gArgs.Add('--path'); $gArgs.Add($ProjectRoot)
        $gArgs.Add('-s'); $gArgs.Add('addons/gut/gut_cmdln.gd'); $gArgs.Add('-gexit')
    }
}

if ($Headless -and -not $gArgs.Contains('--headless')) {
    $gArgs.Insert(0, '--headless')
}
if ($ExtraArgs) {
    foreach ($a in $ExtraArgs) { $gArgs.Add($a) }
}

# ── 分支（check 先做一次导入检查）───────────────────────
$failed = $false

if ($Action -eq 'check') {
    Say '① 导入 / 解析检查…'
    & $godot '--headless' '--path' $ProjectRoot '--import' 2>&1 | Out-Null
    SayOk '   完成（若下方测试全绿，即表示脚本零解析错误）'
    Write-Host ''
    Say '② 单元 + 集成测试…'
    $gArgs.Clear()
    $gArgs.Add('--headless'); $gArgs.Add('--path'); $gArgs.Add($ProjectRoot)
    $gArgs.Add('-s'); $gArgs.Add('addons/gut/gut_cmdln.gd'); $gArgs.Add('-gexit')
}

Say "启动：godot $($gArgs -join ' ')"

# 操作提示放在启动之前 —— 双击运行且正常退出时不会有暂停，
# 放在后面会被一闪而过。
if ($Action -eq 'play') {
    Write-Host ''
    Say '操作提示：左键点草地翻地 → 再点播种 → 再点浇水 → F10 过夜（重复 4 次收芜菁）'
    Say '          Q/E 转视角 · 滚轮缩放 · 1-5 换种子 · F5 存档 · F9 读档'
}

SayRule

$sw = [System.Diagnostics.Stopwatch]::StartNew()
& $godot @gArgs
$code = $LASTEXITCODE
$sw.Stop()

SayRule
switch ($Action) {
    'test' {
        if ($code -eq 0) { SayOk '✔ 测试全部通过' }
        else { SayFail "✘ 测试失败（退出码 $code）"; $failed = $true }
    }
    'check' {
        if ($code -eq 0) { SayOk '✔ 导入与测试均通过' }
        else { SayFail "✘ 测试失败（退出码 $code）"; $failed = $true }
    }
    'play' {
        if ($code -eq 0) { SayOk "游戏已退出（正常运行 $([math]::Round($sw.Elapsed.TotalSeconds,1)) 秒）" }
        else { SayFail "游戏异常退出（退出码 $code）"; $failed = $true }
    }
    'editor' {
        if ($code -eq 0) { SayOk '编辑器已关闭' }
        else { SayFail "编辑器异常退出（退出码 $code）"; $failed = $true }
    }
    default {
        if ($code -eq 0) { SayOk '完成' } else { SayFail "异常退出（退出码 $code）"; $failed = $true }
    }
}

if ($failed) { exit $code }
exit 0
