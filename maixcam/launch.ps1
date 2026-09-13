# MaixCAM 开发助手 —— 启动器（一个脚本，没别的）
#
# 桌面 / 开始菜单那个快捷方式执行的就是它。只做两件事：
#
#   已经在跑  -> 打开浏览器（地址从上次那份日志里读）
#   没在跑    -> 启动，等它就绪
#
# ## 为什么要自己判断「该不该启动」
#
# 上一版（VBS）没有这个判断，用户双击几次就堆几个带着 --port 8890 的进程，
# 抢不到端口的那些又没干净退出，挂在那儿。实测从 1 个涨到 7 个。
# **启动器必须自己回答「我现在该不该启动」，而不是无脑启动。**
#
# ## 为什么只认日志这一个来源
#
# 上一版还额外写了一份 maixcam-url.txt，结果那条路径出了 bug，反而变成
# 「地址没记下来」。现在只有一份真相：`dsh web` 打到 stdout 的那行日志。
# 日志一直在，所以第二次双击也能从中读到带 token 的地址。
#
# ## 一个踩过的坑
#
# `$ErrorActionPreference = 'Stop'` 配上 `[regex]::Match($null, ...)`
# （日志还没生成时 Get-Content 返回空）会**抛异常直接终止脚本** ——
# 表现是「双击完全没反应，也没有任何提示」。所以下面读日志的地方都包了 try/catch。

$ErrorActionPreference = 'Stop'

$Root    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)  # <repo>
$Home_   = Join-Path $env:USERPROFILE '.dsh-maixcam'
$Port    = 8890
$Entry   = Join-Path $Root 'apps\cli\lib\bin.js'
$LogFile = Join-Path $env:TEMP 'maixcam-app.log'
$ErrFile = Join-Path $env:TEMP 'maixcam-app.err.log'

function Show([string]$msg) { Write-Host "  $msg" }

function Fail([string]$msg) {
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show($msg, 'MaixCAM 开发助手', 'OK', 'Error') | Out-Null
    } catch {
        Write-Host $msg -ForegroundColor Red
    }
    exit 1
}

# 从日志里读带 token 的地址。读不到返回空串，**不抛异常**。
function Get-AppUrl {
    if (-not (Test-Path $LogFile)) { return '' }
    try {
        $text = Get-Content -LiteralPath $LogFile -Raw -ErrorAction Stop
    } catch {
        return ''
    }
    if ([string]::IsNullOrEmpty($text)) { return '' }
    try {
        $m = [regex]::Match($text, 'http://127\.0\.0\.1:\d+/\?token=\S+')
        if ($m.Success) { return $m.Value }
    } catch { }
    return ''
}

$listening = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue).Count -gt 0

# ── 已经在跑 ────────────────────────────────────────────────────────────────
if ($listening) {
    Show "应用已经在运行（端口 $Port），不再启一个。"
    $url = Get-AppUrl
    if ($url -eq '') {
        Fail("应用在运行，但读不到它的访问地址（带 token 的那个）。`n`n" +
             "日志：$LogFile`n`n" +
             "可以手动看一眼那份日志里的 dsh web: 那一行。")
    }
    Start-Process $url
    Show "已打开 $url"
    exit 0
}

# ── 没在跑 ──────────────────────────────────────────────────────────────────
if (-not (Test-Path $Entry)) {
    Fail("没找到已构建的应用：`n$Entry`n`n先运行 setup.cmd 完成安装与构建。")
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Fail('没有找到 Node.js（22 或更高版本）。')
}

Show "正在启动…"
$env:DSH_HOME = $Home_

# 清掉上一轮的日志，这样等一会儿读到的地址一定是这一次的。
Remove-Item $LogFile, $ErrFile -ErrorAction SilentlyContinue

# 不带 --no-open：让 dsh web 自己开浏览器（它本来就会）。
# 上一版绕了一圈自己抓地址再开，反而多了一条会出错的路径。
$nodeArgs = @(
    'apps\cli\lib\bin.js', '--profile', 'maixcam',
    '--patch', 'maixcam\app.patch.yml', '--port', "$Port"
)
$proc = Start-Process -FilePath $node.Source -ArgumentList $nodeArgs `
    -WorkingDirectory $Root -WindowStyle Hidden `
    -RedirectStandardOutput $LogFile -RedirectStandardError $ErrFile -PassThru

# 等端口起来（最多 60 秒）。起来了说明浏览器也已经被 dsh 打开了。
$deadline = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 700
    if (@(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue).Count -gt 0) {
        Show "已就绪：$(Get-AppUrl)"
        exit 0
    }
    if ($proc.HasExited) { break }
}

$tail = ''
foreach ($f in @($ErrFile, $LogFile)) {
    if (Test-Path $f) { $tail += (Get-Content -LiteralPath $f -Tail 15 -ErrorAction SilentlyContinue) -join "`n" }
}
Fail("启动失败。`n`n日志（$LogFile）：`n$tail")
