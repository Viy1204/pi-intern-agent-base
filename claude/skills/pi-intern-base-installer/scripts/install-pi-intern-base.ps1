param(
  [string]$Workspace = (Get-Location).Path,
  [string]$HomePath = $HOME,
  [switch]$Yes,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Test-Tool {
  param([string]$Name, [bool]$Required)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  [ordered]@{
    name = $Name
    required = $Required
    available = $null -ne $cmd
    path = if ($cmd) { $cmd.Source } else { $null }
  }
}

function Invoke-Native {
  param([string]$File, [string[]]$Arguments)
  $output = & $File @Arguments 2>&1
  [ordered]@{
    exitCode = $LASTEXITCODE
    output = @($output | ForEach-Object { $_.ToString() })
  }
}

function Find-PiSetupScript {
  param([string]$HomePath)
  $root = Join-Path $HomePath ".pi\agent"
  if (-not (Test-Path -LiteralPath $root)) {
    return $null
  }
  $script = Get-ChildItem -Path $root -Recurse -Filter "install-agents.ps1" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -like "*pi-intern-setup*scripts*" } |
    Select-Object -First 1
  if ($script) { $script.FullName } else { $null }
}

$result = [ordered]@{
  ok = $false
  dryRun = [bool]$DryRun
  workspace = (Resolve-Path -LiteralPath $Workspace).Path
  checks = @()
  missingRequired = @()
  missingOptional = @()
  githubAccess = $null
  install = $null
  agents = $null
  lark = $null
}

$checks = @(
  (Test-Tool "git" $true),
  (Test-Tool "node" $true),
  (Test-Tool "npm" $true),
  (Test-Tool "bash" $false),
  (Test-Tool "pi" $true),
  (Test-Tool "lark-cli" $false)
)

$result.checks = $checks
$result.missingRequired = @($checks | Where-Object { $_.required -and -not $_.available } | ForEach-Object { $_.name })
$result.missingOptional = @($checks | Where-Object { -not $_.required -and -not $_.available } | ForEach-Object { $_.name })

if ($result.missingRequired.Count -gt 0) {
  $result.ok = $false
  $result.status = "missing-required-tools"
  $result | ConvertTo-Json -Depth 8 -Compress
  exit 3
}

$repoCheck = Invoke-Native "git" @("ls-remote", "https://github.com/Viy1204/pi-intern-agent-base.git", "HEAD")
$result.githubAccess = [ordered]@{
  repo = "Viy1204/pi-intern-agent-base"
  ok = $repoCheck.exitCode -eq 0
}

if (-not $result.githubAccess.ok) {
  $result.ok = $false
  $result.status = "github-access-failed"
  $result | ConvertTo-Json -Depth 8 -Compress
  exit 4
}

if ($DryRun) {
  $result.ok = $true
  $result.status = "ready"
  $result | ConvertTo-Json -Depth 8 -Compress
  exit 0
}

if (-not $Yes) {
  $result.ok = $false
  $result.status = "confirmation-required"
  $result.message = "Re-run with -Yes after the user confirms installation."
  $result | ConvertTo-Json -Depth 8 -Compress
  exit 10
}

$install = Invoke-Native "pi" @("install", "git:github.com/Viy1204/pi-intern-agent-base@v0.1.0")
$result.install = [ordered]@{
  package = "pi-intern-agent-base"
  exitCode = $install.exitCode
  ok = $install.exitCode -eq 0
}

if (-not $result.install.ok) {
  $result.ok = $false
  $result.status = "pi-install-failed"
  $result | ConvertTo-Json -Depth 8 -Compress
  exit 5
}

$setupScript = Find-PiSetupScript -HomePath $HomePath
if ($setupScript) {
  $agents = Invoke-Native "powershell" @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $setupScript,
    "-Scope",
    "project",
    "-Workspace",
    $result.workspace
  )
  $result.agents = [ordered]@{
    script = $setupScript
    exitCode = $agents.exitCode
    ok = ($agents.exitCode -eq 0 -or $agents.exitCode -eq 2)
    status = if ($agents.exitCode -eq 0) { "installed" } elseif ($agents.exitCode -eq 2) { "exists" } else { "failed" }
  }
} else {
  $result.agents = [ordered]@{
    ok = $false
    status = "setup-script-not-found"
  }
}

if ((Get-Command "lark-cli" -ErrorAction SilentlyContinue)) {
  $lark = Invoke-Native "lark-cli" @("auth", "status")
  $result.lark = [ordered]@{
    available = $true
    ok = $lark.exitCode -eq 0
    status = if ($lark.exitCode -eq 0) { "ready-or-check-output-in-terminal" } else { "needs-login-or-permission" }
  }
} else {
  $result.lark = [ordered]@{
    available = $false
    ok = $false
    status = "lark-cli-missing"
  }
}

$result.ok = $true
$result.status = "completed"
$result | ConvertTo-Json -Depth 8 -Compress
