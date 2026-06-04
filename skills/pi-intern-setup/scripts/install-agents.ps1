param(
  [ValidateSet("project", "global")]
  [string]$Scope = "project",

  [string]$Workspace = (Get-Location).Path,

  [string]$HomePath = $HOME,

  [switch]$Force,

  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function New-Result {
  param(
    [bool]$Ok,
    [string]$Status,
    [string]$Target,
    [string]$Message,
    [string]$Backup = ""
  )

  [pscustomobject]@{
    ok = $Ok
    status = $Status
    target = $Target
    backup = $Backup
    message = $Message
  } | ConvertTo-Json -Compress
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$templatePath = Join-Path $repoRoot "templates\AGENTS.pi-intern.md"

if (-not (Test-Path -LiteralPath $templatePath)) {
  throw "Template not found: $templatePath"
}

if ($Scope -eq "global") {
  $targetPath = Join-Path $HomePath ".pi\agent\AGENTS.md"
} else {
  $workspacePath = Resolve-Path -LiteralPath $Workspace
  $targetPath = Join-Path $workspacePath ".pi\AGENTS.md"
}

$targetDir = Split-Path -Parent $targetPath

if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
  New-Result -Ok $false -Status "exists" -Target $targetPath -Message "Target exists. Re-run with -Force only after explicit user confirmation."
  exit 2
}

if ($DryRun) {
  New-Result -Ok $true -Status "dry-run" -Target $targetPath -Message "Dry run only. No files changed."
  exit 0
}

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

$backupPath = ""
if (Test-Path -LiteralPath $targetPath) {
  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backupPath = "$targetPath.bak-$timestamp"
  Copy-Item -LiteralPath $targetPath -Destination $backupPath
}

Copy-Item -LiteralPath $templatePath -Destination $targetPath -Force

$status = if ($backupPath) { "installed-with-backup" } else { "installed" }
New-Result -Ok $true -Status $status -Target $targetPath -Backup $backupPath -Message "AGENTS.md installed."
