# MaixCAM 开发助手 —— 安装脚本
#
# 双击仓库根目录的 `setup.cmd` 就会跑到这里。
#
# 它做五件事：
#   1. 检查 Node / pnpm 是否具备（缺了就说清楚怎么装，不静默失败）
#   2. 装依赖、构建（首次约 5~15 分钟，取决于网速）
#   3. 建立应用自己的 home（`%USERPROFILE%\.dsh-maixcam`）
#   4. 从图标生成 .ico，并在**桌面**与**开始菜单**各放一个启动器
#   5. 打印下一步该做什么
#
# 可以重复跑：每一步都先检查再动手，不会重复装、不会叠快捷方式。

[CmdletBinding()]
param(
    # 跳过构建（已经构建过，只想重建快捷方式时用）
    [switch]$SkipBuild,
    # 只装快捷方式，别的都不做
    [switch]$ShortcutsOnly
)

$ErrorActionPreference = 'Stop'
$AppName = 'MaixCAM 开发助手'

function Say([string]$msg) { Write-Host "  $msg" }
function Head([string]$msg) { Write-Host ''; Write-Host "== $msg" -ForegroundColor Cyan }

# ── 路径 ────────────────────────────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path   # <根>\maixcam
$AppRoot   = Split-Path -Parent $ScriptDir                     # <根>
$Home_     = Join-Path $env:USERPROFILE '.dsh-maixcam'
$Launcher  = Join-Path $ScriptDir 'launch.ps1'
$IconHash  = (Get-FileHash (Join-Path $AppRoot 'apps\web\public\favicon.svg') -Algorithm SHA256).Hash.Substring(0,8).ToLower()
$Icon      = Join-Path $ScriptDir "maixcam-$IconHash.ico"
$Entry     = Join-Path $AppRoot 'apps\cli\lib\bin.js'

Write-Host ''
Write-Host "  $AppName —— 安装" -ForegroundColor White
Say "项目目录 : $AppRoot"
Say "应用 home : $Home_"

# ── 1. 环境检查 ─────────────────────────────────────────────────────────────
Head '检查运行环境'

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-Host '  没有找到 Node.js。' -ForegroundColor Red
    Write-Host '  请先安装 Node.js 22 或更高版本：https://nodejs.org/' -ForegroundColor Yellow
    exit 1
}
$nodeVer = (& node -v).TrimStart('v')
Say "Node.js   : v$nodeVer  ($($node.Source))"

$pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpm) {
    Write-Host '  没有找到 pnpm。' -ForegroundColor Red
    Write-Host '  两个办法，任选其一：' -ForegroundColor Yellow
    Write-Host '    corepack enable pnpm        （Node 自带的 corepack，推荐）'
    Write-Host '    npm install -g pnpm'
    exit 1
}
Say "pnpm      : $(& pnpm -v)"

# ── 2. 装依赖并构建 ─────────────────────────────────────────────────────────
if (-not $SkipBuild -and -not $ShortcutsOnly) {
    Head '安装依赖（首次较慢）'
    Push-Location $AppRoot
    try {
        & pnpm install --frozen-lockfile
        if ($LASTEXITCODE -ne 0) { throw "pnpm install 失败（exit $LASTEXITCODE）" }

        Head '构建（宿主 + 客户端 + Web 前端）'
        & pnpm run build
        if ($LASTEXITCODE -ne 0) { throw "构建失败（exit $LASTEXITCODE）" }
    } finally {
        Pop-Location
    }
} else {
    Head '跳过依赖与构建（按参数要求）'
}

if (-not (Test-Path $Entry)) {
    Write-Host "  构建产物不在这里：$Entry" -ForegroundColor Red
    Write-Host '  不要跳过构建，除非你确定已经构建过。' -ForegroundColor Yellow
    exit 1
}
Say "构建产物  : 已就位"

# ── 3. 应用自己的 home ──────────────────────────────────────────────────────
Head '准备应用 home'
New-Item -ItemType Directory -Force -Path $Home_ | Out-Null

$settings = Join-Path $Home_ 'settings.yaml'
if (-not (Test-Path $settings)) {
    @"
locale:
  preference: zh
agent-presets:
  default: maixcam-assistant
ui-onboarding:
  welcomeNoticeVersion: 2026-08-13.1
"@ | Set-Content -LiteralPath $settings -Encoding utf8
    Say '已写入 settings.yaml（中文界面 + 默认用 MaixCAM 助手）'
} else {
    Say 'settings.yaml 已存在，保留不动'
}

# 凭据：能从别处的 dsh home 借一份就借，借不到就让用户自己在设置页填。
$cred = Join-Path $Home_ '.credentials.yaml'
if (-not (Test-Path $cred)) {
    $donor = Join-Path $env:USERPROFILE '.dsh\.credentials.yaml'
    if (Test-Path $donor) {
        Copy-Item $donor $cred -Force
        Say '已从 ~/.dsh 复制一份凭据（省得你重填 API Key）'
    } else {
        Write-Host '  还没有凭据文件 —— 首次启动后在 设置 → 模型 里填 API Key。' -ForegroundColor Yellow
    }
} else {
    Say '凭据已存在，保留不动'
}

# ── 4. 图标与快捷方式 ───────────────────────────────────────────────────────
Head '建立启动器'

# 4a. 从 favicon.svg 生成 .ico（用无头 Chrome/Edge 渲染成 PNG，再套 ICO 容器）
if (-not (Test-Path $Icon)) {
    $svg = Join-Path $AppRoot 'apps\web\public\favicon.svg'
    $browser = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($browser -and (Test-Path $svg)) {
        $png = Join-Path $env:TEMP 'maixcam-icon.png'
        try {
            # 不能直接把 .svg 交给 Chrome 截图：favicon.svg 的根元素写着
            # width="24" height="24"，Chrome 就按 24px 画，而画布是 256 ——
            # 结果是左上角一个小点、其余全空，Windows 画出来就是「图标对不上」。
            # 所以先拼一个 HTML，把 svg 的固定尺寸去掉、用 CSS 撑满画布。
            $inline = (Get-Content $svg -Raw) `
                -replace '(?s)<!--.*?-->', '' `
                -replace '<svg([^>]*?)\swidth="[^"]*"', '<svg$1' `
                -replace '<svg([^>]*?)\sheight="[^"]*"', '<svg$1'
            $html = Join-Path $env:TEMP 'maixcam-icon.html'
            @"
<!doctype html><meta charset="utf-8">
<style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}
svg{width:256px;height:256px;display:block}</style>
$inline
"@ | Set-Content -LiteralPath $html -Encoding utf8

            & $browser --headless --disable-gpu --no-sandbox --hide-scrollbars `
                --default-background-color=00000000 --window-size=256,256 `
                --screenshot="$png" "file:///$($html -replace '\\','/')" 2>$null | Out-Null
            if (Test-Path $png) {
                # ICO 允许直接内嵌 PNG（Windows Vista+）。结构：6 字节头 + 16 字节目录项 + PNG。
                $bytes = [System.IO.File]::ReadAllBytes($png)
                $ms = New-Object System.IO.MemoryStream
                $bw = New-Object System.IO.BinaryWriter($ms)
                $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)
                $bw.Write([byte]0); $bw.Write([byte]0)          # 宽高 0 = 256
                $bw.Write([byte]0); $bw.Write([byte]0)          # 调色板 / 保留
                $bw.Write([uint16]1); $bw.Write([uint16]32)     # 色彩平面 / 位深
                $bw.Write([uint32]$bytes.Length)
                $bw.Write([uint32]22)                           # 数据偏移
                $bw.Write($bytes)
                $bw.Flush()
                [System.IO.File]::WriteAllBytes($Icon, $ms.ToArray())
                $bw.Dispose(); $ms.Dispose()
                Say '已生成 maixcam.ico'
            }
        } catch { Say "图标生成失败（不影响使用）：$($_.Exception.Message)" }
        Remove-Item $png -ErrorAction SilentlyContinue
    } else {
        Say '没找到 Chrome/Edge 或 favicon.svg，快捷方式将用系统默认图标'
    }
} else {
    Say 'maixcam.ico 已存在'
}

# 4b. 快捷方式。目标指向 pwsh + launch.ps1，并由 launch.ps1 自己决定「该不该启动」——
#     这里不用 VBS：要查端口、读日志、等就绪，VBS 干这些很别扭。
$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { (Get-Command pwsh).Source } else { Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
$targets = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) "$AppName.lnk"),
    (Join-Path ([Environment]::GetFolderPath('Programs')) "$AppName.lnk")
)

$shell = New-Object -ComObject WScript.Shell
foreach ($lnk in $targets) {
    $dir = Split-Path -Parent $lnk
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $sc = $shell.CreateShortcut($lnk)
    $sc.TargetPath       = $psExe
    $sc.Arguments        = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $Launcher + '"'
    $sc.WorkingDirectory = $AppRoot
    $sc.Description      = "$AppName —— 本地 MaixPy 知识库助手"
    if (Test-Path $Icon) { $sc.IconLocation = "$Icon,0" }
    $sc.Save()
    Say "已创建 $lnk"
}

# ── 5. 完事 ─────────────────────────────────────────────────────────────────
Head '装好了'
Write-Host "  桌面上和开始菜单里都有「$AppName」，双击即可。" -ForegroundColor Green
Write-Host ''
Write-Host '  访问地址是 http://127.0.0.1:8890 —— 启动器会自动打开浏览器。'
Write-Host '  （token 每次启动都会变，所以别存 URL，用那个快捷方式。）'
Write-Host ''
Write-Host '  关掉应用：任务管理器里结束 node.exe。'
Write-Host ''
