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
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $File @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  } catch {
    $output = @($_.Exception.Message)
    $exitCode = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 1 }
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  [ordered]@{
    exitCode = $exitCode
    output = @($output | ForEach-Object { $_.ToString() })
  }
}

function Get-OutputSummary {
  param([string[]]$Output)
  @($Output | Select-Object -First 12)
}

function Get-FailureStatus {
  param([string[]]$Output, [string]$DefaultStatus)
  $text = ($Output -join "`n")
  if ($text -match "User cancelled dialog|Authentication failed|could not read Username|terminal prompts disabled") {
    return "github-auth-cancelled"
  }
  if ($text -match "Repository not found|not found") {
    return "github-repo-not-found"
  }
  if ($text -match "not a git repository|git fetch origin .* failed with code 128") {
    return "pi-cache-corrupt"
  }
  if ($text -match "No models available") {
    return "model-not-configured"
  }
  if ($text -match "spawn bash ENOENT") {
    return "bridge-bash-not-ready"
  }
  return $DefaultStatus
}

function Find-GitBashPath {
  $configured = @($env:FEISHU_BRIDGE_BASH, $env:PI_FEISHU_BASH) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -First 1
  if ($configured) { return $configured }
  foreach ($candidate in @("C:\Program Files\Git\usr\bin\bash.exe", "C:\Program Files\Git\bin\bash.exe")) {
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }
  $cmd = Get-Command "bash" -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return ""
}

function Test-NodeCanSpawn {
  param([string]$File)
  $node = Get-Command "node" -ErrorAction SilentlyContinue
  if (-not $node -or -not $File) { return $false }
  $script = "const {spawnSync}=require('node:child_process'); const r=spawnSync(process.argv[1], ['--version'], {encoding:'utf8'}); process.exit(r.status===0 ? 0 : 1);"
  & $node.Source -e $script $File *> $null
  return $LASTEXITCODE -eq 0
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
  bridge = $null
  piCache = $null
  firstLaunchSteps = @(
    "Start pi, then run /login to configure API key, OAuth, or model provider.",
    "Run /feishu setup to configure the Feishu bridge.",
    "Run /feishu status; if the bridge does not respond, run /feishu restart."
  )
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

$bashPath = Find-GitBashPath
$result.bridge = [ordered]@{
  bashPath = $bashPath
  nodeCanSpawnBash = Test-NodeCanSpawn -File $bashPath
  ok = [bool]($bashPath -and (Test-NodeCanSpawn -File $bashPath))
  status = if ($bashPath) { "ready-or-fix-path-after-install" } else { "git-bash-missing" }
}

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
  exitCode = $repoCheck.exitCode
  output = Get-OutputSummary -Output $repoCheck.output
}

if (-not $result.githubAccess.ok) {
  $result.ok = $false
  $result.status = Get-FailureStatus -Output $repoCheck.output -DefaultStatus "github-access-failed"
  $result | ConvertTo-Json -Depth 8 -Compress
  exit 4
}

$cachePath = Join-Path $HomePath ".pi\agent\git\github.com\Viy1204\pi-intern-agent-base"
if ((Test-Path -LiteralPath $cachePath) -and -not (Test-Path -LiteralPath (Join-Path $cachePath ".git\HEAD"))) {
  $result.piCache = [ordered]@{
    ok = $false
    status = "pi-cache-corrupt"
    path = $cachePath
    fix = "After user confirmation, close pi/git processes, delete or rename this directory, then rerun installation."
  }
  $result.ok = $false
  $result.status = "pi-cache-corrupt"
  $result | ConvertTo-Json -Depth 8 -Compress
  exit 6
}
$result.piCache = [ordered]@{ ok = $true; status = "clean-or-absent"; path = $cachePath }

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

$install = Invoke-Native "pi" @("install", "git:github.com/Viy1204/pi-intern-agent-base@v0.1.1")
$result.install = [ordered]@{
  package = "pi-intern-agent-base"
  exitCode = $install.exitCode
  ok = $install.exitCode -eq 0
  output = Get-OutputSummary -Output $install.output
}

if (-not $result.install.ok) {
  $result.ok = $false
  $result.status = Get-FailureStatus -Output $install.output -DefaultStatus "pi-install-failed"
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
    output = Get-OutputSummary -Output $agents.output
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
    output = Get-OutputSummary -Output $lark.output
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
