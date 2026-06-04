param(
  [string]$HomePath = $HOME,
  [switch]$Force,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$source = Join-Path $repoRoot "claude\commands\pi-intern-setup.md"
$destDir = Join-Path $HomePath ".claude\commands"
$dest = Join-Path $destDir "pi-intern-setup.md"

if (-not (Test-Path -LiteralPath $source)) {
  throw "Missing Claude Code command source: $source"
}

$result = [ordered]@{
  command = "pi-intern-setup"
  source = $source
  target = $dest
  status = $null
  backup = $null
}

if ((Test-Path -LiteralPath $dest) -and -not $Force) {
  $result.status = "exists"
  $result | ConvertTo-Json -Compress
  exit 2
}

if ($DryRun) {
  $result.status = "dry-run"
  $result | ConvertTo-Json -Compress
  exit 0
}

New-Item -ItemType Directory -Path $destDir -Force | Out-Null

if (Test-Path -LiteralPath $dest) {
  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backup = "$dest.bak-$timestamp"
  Copy-Item -LiteralPath $dest -Destination $backup -Force
  $result.backup = $backup
  $result.status = "installed-with-backup"
} else {
  $result.status = "installed"
}

Copy-Item -LiteralPath $source -Destination $dest -Force

$result | ConvertTo-Json -Compress
