# 把 3rd/BekUI/resources 的增量同步进 Belive 自己的 resources/。
#
# Belive 全量接管了资源树（构建只拷仓库根的 resources/，不再拷三方库的那份），
# 所以 BekUI 以后新增/更新的素材（新字体、新主题文件、新音效）需要手动拉一次。
# 这个脚本只做"比较 + 按需拷贝"，永远不会删除 Belive 独有的文件。
#
# 用法（在仓库根或任意目录）：
#   powershell -NoProfile -File scripts/sync-resources.ps1                # 只看差异，不动文件
#   powershell -NoProfile -File scripts/sync-resources.ps1 -Apply         # 拷贝"库里有、我们没有"的文件
#   powershell -NoProfile -File scripts/sync-resources.ps1 -Apply -Force  # 再说把内容不同的也覆盖成库里的版本
#
# 注意到 -Force 会覆盖你改过的文件：先不加 -Force 跑一遍，看 "内容不同" 列表里有没有你不想覆盖的。

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Force,
    [string]$Library = "",
    [string]$Target = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Library)) { $Library = Join-Path $repoRoot "3rd/BekUI/resources" }
if ([string]::IsNullOrWhiteSpace($Target))  { $Target  = Join-Path $repoRoot "resources" }

if (-not (Test-Path $Library)) { throw "找不到库的资源目录：$Library（子模块拉了吗？git submodule update --init --recursive）" }
if (-not (Test-Path $Target))  { throw "找不到 Belive 的资源目录：$Target" }

$Library = (Resolve-Path $Library).Path
$Target  = (Resolve-Path $Target).Path

function Get-RelativeFiles([string]$root)
{
    Get-ChildItem -Path $root -Recurse -File | ForEach-Object {
        $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    }
}

$libFiles = Get-RelativeFiles $Library
$ownFiles = Get-RelativeFiles $Target

$newFiles     = @($libFiles | Where-Object { $ownFiles -notcontains $_ })
$localOnly    = @($ownFiles | Where-Object { $libFiles -notcontains $_ })
$changedFiles = @(foreach ($rel in $libFiles) {
    if ($ownFiles -contains $rel) {
        $a = (Get-FileHash (Join-Path $Library $rel) -Algorithm SHA256).Hash
        $b = (Get-FileHash (Join-Path $Target $rel) -Algorithm SHA256).Hash
        if ($a -ne $b) { $rel }
    }
})

Write-Host "库  ：$Library"
Write-Host "目标：$Target"
Write-Host ""
Write-Host ("库有 / 我们有 : {0} / {1} 个文件" -f $libFiles.Count, $ownFiles.Count)
Write-Host ("库里有、我们没有（可拉取）: {0}" -f $newFiles.Count)
foreach ($f in $newFiles) { Write-Host "  + $f" }
Write-Host ("两边都有、内容不同（需 -Force 才覆盖）: {0}" -f $changedFiles.Count)
foreach ($f in $changedFiles) { Write-Host "  ~ $f" }
Write-Host ("只在 Belive 有（自己加的，脚本不动）: {0}" -f $localOnly.Count)
foreach ($f in $localOnly) { Write-Host "  ! $f" }

if (-not $Apply)
{
    Write-Host ""
    Write-Host "只看了差异，没动文件。加 -Apply 拉取新文件，加 -Apply -Force 连内容不同的也覆盖。"
    return
}

$copied = 0
foreach ($rel in $newFiles)
{
    $dst = Join-Path $Target $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item (Join-Path $Library $rel) $dst -Force
    $copied++
}

if ($Force)
{
    foreach ($rel in $changedFiles)
    {
        $dst = Join-Path $Target $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item (Join-Path $Library $rel) $dst -Force
        $copied++
    }
}

Write-Host ""
Write-Host ("已拷贝 {0} 个文件。" -f $copied)
if (-not $Force -and $changedFiles.Count -gt 0)
{
    Write-Host ("还有 {0} 个文件内容不同，没覆盖（要的话加 -Force）。" -f $changedFiles.Count)
}
