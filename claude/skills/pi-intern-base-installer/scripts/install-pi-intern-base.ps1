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

function Get-InstallGuide {
  param([string]$Name)
  $guides = @{
    "winget" = [ordered]@{
      name = "Windows Package Manager"
      command = $null
      url = "https://learn.microsoft.com/windows/package-manager/winget/"
      note = "Install or repair winget from Microsoft App Installer, then reopen the terminal."
    }
    "git" = [ordered]@{
      name = "Git for Windows"
      command = "winget install --id Git.Git -e --source winget"
      url = "https://git-scm.com/download/win"
      note = "Reopen Claude Code or the terminal after installation."
    }
    "node" = [ordered]@{
      name = "Node.js LTS"
      command = "winget install --id OpenJS.NodeJS.LTS -e --source winget"
      url = "https://nodejs.org/en/download"
      note = "This also installs npm. Reopen Claude Code or the terminal after installation."
    }
    "npm" = [ordered]@{
      name = "npm"
      command = "winget install --id OpenJS.NodeJS.LTS -e --source winget"
      url = "https://nodejs.org/en/download"
      note = "npm is installed with Node.js LTS."
    }
    "claude" = [ordered]@{
      name = "Claude Code"
      command = "npm install -g @anthropic-ai/claude-code"
      url = "https://docs.claude.com/en/docs/claude-code/setup"
      note = "Requires Node.js/npm first."
    }
    "pi" = [ordered]@{
      name = "Pi Coding Agent"
      command = "npm install -g @earendil-works/pi-coding-agent"
      url = "https://www.npmjs.com/package/@earendil-works/pi-coding-agent"
      note = "Requires Node.js/npm first."
    }
    "lark-cli" = [ordered]@{
      name = "Lark/Feishu CLI"
      command = "npx @larksuite/cli@latest install"
      url = "https://github.com/larksuite/cli"
      note = "After install, run: lark-cli config init --new; lark-cli auth login"
    }
  }
  if ($guides.ContainsKey($Name)) {
    $guides[$Name]
  } else {
    [ordered]@{ name = $Name; command = $null; url = $null; note = "Ask the administrator for the installation method." }
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
  installGuides = @()
  install = $null
  agents = $null
  lark = $null
}

$checks = @(
  (Test-Tool "winget" $false),
  (Test-Tool "claude" $false),
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
$missingAll = @($result.missingRequired + $result.missingOptional | Select-Object -Unique)
$result.installGuides = @($missingAll | ForEach-Object { Get-InstallGuide $_ })

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
