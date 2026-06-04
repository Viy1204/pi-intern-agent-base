param(
  [switch]$FixGitBashPath
)

$ErrorActionPreference = "Stop"

function Test-Command {
  param([string]$Name)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  [pscustomobject]@{
    name = $Name
    ok = [bool]$cmd
    path = if ($cmd) { $cmd.Source } else { "" }
  }
}

function Find-GitBashPath {
  $configured = @($env:FEISHU_BRIDGE_BASH, $env:PI_FEISHU_BASH) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -First 1
  if ($configured) { return $configured }

  $cmd = Get-Command "bash" -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $candidates = @(
    "C:\Program Files\Git\usr\bin\bash.exe",
    "C:\Program Files\Git\bin\bash.exe"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }
  return ""
}

function Add-GitBashToUserPath {
  param([string]$BashPath)
  if (-not $BashPath) { return $false }
  $dirs = @(
    (Split-Path -Parent $BashPath),
    "C:\Program Files\Git\mingw64\bin"
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = @($current -split ";" | Where-Object { $_ })
  $changed = $false
  foreach ($dir in $dirs) {
    if (-not ($parts | Where-Object { $_.TrimEnd("\") -ieq $dir.TrimEnd("\") })) {
      $parts += $dir
      $changed = $true
    }
  }
  if ($changed) {
    [Environment]::SetEnvironmentVariable("Path", ($parts -join ";"), "User")
  }
  return $changed
}

function Test-NodeCanSpawnBash {
  param([string]$BashPath)
  $node = Get-Command "node" -ErrorAction SilentlyContinue
  if (-not $node -or -not $BashPath) { return $false }
  $script = "const {spawnSync}=require('node:child_process'); const r=spawnSync(process.argv[1], ['--version'], {encoding:'utf8'}); process.exit(r.status===0 ? 0 : 1);"
  & $node.Source -e $script $BashPath *> $null
  return $LASTEXITCODE -eq 0
}

$bashPath = Find-GitBashPath
$pathFixed = $false
if ($FixGitBashPath) {
  $pathFixed = Add-GitBashToUserPath -BashPath $bashPath
  $bashPath = Find-GitBashPath
}

$nodeCanSpawnBash = Test-NodeCanSpawnBash -BashPath $bashPath
$recommendedFixes = @()
if (-not $bashPath) {
  $recommendedFixes += "Install Git for Windows, or set FEISHU_BRIDGE_BASH to bash.exe."
} elseif (-not $nodeCanSpawnBash) {
  $bashDir = Split-Path -Parent $bashPath
  $recommendedFixes += "Add ${bashDir} to User PATH, then reopen the terminal."
}
if (-not (Get-Command "pi" -ErrorAction SilentlyContinue)) {
  $recommendedFixes += "Install Pi: npm install -g @earendil-works/pi-coding-agent."
}
if (-not (Get-Command "lark-cli" -ErrorAction SilentlyContinue)) {
  $recommendedFixes += "Install lark-cli if Feishu API access is needed: npx @larksuite/cli@latest install."
}

$checks = @(
  (Test-Command "pi"),
  (Test-Command "node"),
  (Test-Command "npm"),
  (Test-Command "git"),
  (Test-Command "bash"),
  (Test-Command "lark-cli")
)

$settingsPath = Join-Path $HOME ".pi\agent\settings.json"
$settings = $null
if (Test-Path -LiteralPath $settingsPath) {
  try {
    $settings = Get-Content -Raw -Encoding UTF8 -LiteralPath $settingsPath | ConvertFrom-Json
  } catch {
    $settings = $null
  }
}

[pscustomobject]@{
  ok = -not ($checks | Where-Object { -not $_.ok })
  checks = $checks
  piSettingsPath = $settingsPath
  shellPath = if ($settings -and $settings.shellPath) { $settings.shellPath } else { "" }
  hasShellPath = [bool]($settings -and $settings.shellPath)
  bashPath = $bashPath
  nodeCanSpawnBash = $nodeCanSpawnBash
  bridgeReady = [bool]($bashPath -and $nodeCanSpawnBash)
  pathFixed = $pathFixed
  recommendedFixes = $recommendedFixes
} | ConvertTo-Json -Depth 4
