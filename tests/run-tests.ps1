$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$templatePath = Join-Path $repoRoot "templates\AGENTS.pi-intern.md"
$scriptPath = Join-Path $repoRoot "skills\pi-intern-setup\scripts\install-agents.ps1"
$checkScriptPath = Join-Path $repoRoot "skills\pi-intern-setup\scripts\check-environment.ps1"
$claudeBaseSkillPath = Join-Path $repoRoot "claude\skills\pi-intern-base-installer\SKILL.md"
$claudeBaseInstallScriptPath = Join-Path $repoRoot "claude\skills\pi-intern-base-installer\scripts\install-pi-intern-base.ps1"
$piSetupSkillPath = Join-Path $repoRoot "skills\pi-intern-setup\SKILL.md"
$packagePath = Join-Path $repoRoot "package.json"

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-Install {
  param([string[]]$CliArgs)
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @CliArgs
  $code = $LASTEXITCODE
  [pscustomobject]@{
    Code = $code
    Json = ($output | ConvertFrom-Json)
    Raw = $output
  }
}

function From-Utf8Hex {
  param([string]$Hex)
  $bytes = for ($i = 0; $i -lt $Hex.Length; $i += 2) {
    [Convert]::ToByte($Hex.Substring($i, 2), 16)
  }
  [System.Text.Encoding]::UTF8.GetString([byte[]]$bytes)
}

Assert-True (Test-Path -LiteralPath $templatePath) "Missing AGENTS template."
Assert-True (Test-Path -LiteralPath $scriptPath) "Missing install script."
Assert-True (Test-Path -LiteralPath $checkScriptPath) "Missing environment check script."
Assert-True (Test-Path -LiteralPath $claudeBaseSkillPath) "Missing Claude Code base installer skill."
Assert-True (Test-Path -LiteralPath $claudeBaseInstallScriptPath) "Missing Claude Code base installer script."
Assert-True (Test-Path -LiteralPath $piSetupSkillPath) "Missing Pi setup skill."
Assert-True (Test-Path -LiteralPath $packagePath) "Missing package.json."

$pkg = Get-Content -Raw -Encoding UTF8 -LiteralPath $packagePath | ConvertFrom-Json
Assert-True ($pkg.files -contains "claude/") "Package files must include Claude skills directory."
Assert-True ($pkg.pi.extensions -contains "./extensions/pi-intern-feishu-bridge/index.ts") "Missing bridge extension in pi manifest."
Assert-True ($pkg.pi.extensions -contains "node_modules/@juicesharp/rpiv-todo/index.ts") "Missing rpiv-todo extension in pi manifest."
Assert-True ($pkg.pi.extensions -contains "node_modules/@juicesharp/rpiv-ask-user-question/index.ts") "Missing rpiv ask-user extension in pi manifest."
Assert-True ($null -ne $pkg.dependencies."@juicesharp/rpiv-todo") "Missing rpiv-todo dependency."
Assert-True ($null -ne $pkg.dependencies."@juicesharp/rpiv-ask-user-question") "Missing rpiv ask-user dependency."
Assert-True ($null -ne $pkg.dependencies."@larksuiteoapi/node-sdk") "Missing Lark SDK dependency for bridge."

$bridgePath = Join-Path $repoRoot "extensions\pi-intern-feishu-bridge\index.ts"
Assert-True (Test-Path -LiteralPath $bridgePath) "Missing bridge index.ts."
$bridgeSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $bridgePath
Assert-True ($bridgeSource.Contains("resolveBashPath")) "Bridge must resolve bash path before spawning daemon."
Assert-True ($bridgeSource.Contains("FEISHU_BRIDGE_BASH")) "Bridge must support FEISHU_BRIDGE_BASH."
Assert-True ($bridgeSource.Contains("PI_FEISHU_BASH")) "Bridge must support PI_FEISHU_BASH."
Assert-True ($bridgeSource.Contains("FIRST_RUN_PATH")) "Bridge must track first-run onboarding prompt."
Assert-True ($bridgeSource.Contains("/feishu restart")) "Bridge first-run prompt must mention /feishu restart."
Assert-True (-not $bridgeSource.Contains('spawn("bash"')) "Bridge must not spawn bare bash."

$baseSkillNames = Get-ChildItem -Path (Join-Path $repoRoot "skills") -Directory | Select-Object -ExpandProperty Name
$forbiddenBaseSkills = @(
  "boss-daily-brief-v2",
  "lepro-offer",
  "lepro-bonus",
  "lepro-onboarding",
  "probation-review",
  "work-handover",
  "labor-termination-agreement",
  "cn-payslip-advisor",
  "compensation-design-skill"
)
foreach ($skill in $forbiddenBaseSkills) {
  Assert-True (-not ($baseSkillNames -contains $skill)) "HR skill must not be in base package: $skill"
}

foreach ($skill in $forbiddenBaseSkills) {
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoRoot "packages\pi-intern-hr-pack\skills\$skill\SKILL.md"))) "HR pack must not be inside base repo: $skill"
}

Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoRoot "packages\pi-intern-hr-pack"))) "HR pack directory must not be inside base repo."

$template = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
$required = @(
  (From-Utf8Hex "e9bb98e8aea4e4bdbfe794a8e4b8ade69687e59b9ee5a48d"),
  (From-Utf8Hex "e58588e8afbbe5908ee58699"),
  (From-Utf8Hex "e5b091e5819ae68abde8b1a1"),
  (From-Utf8Hex "e4bc98e58588e4bdbfe794a820606c61726b2d636c6960"),
  (From-Utf8Hex "e4b88de8be93e587bae5af86e992a5"),
  "token",
  "appSecret",
  "cookie",
  (From-Utf8Hex "e6a380e69fa5e6b885e58d95")
)

foreach ($needle in $required) {
  Assert-True ($template.Contains($needle)) "Template missing required text: $needle"
}

$forbidden = @(
  "HR",
  (From-Utf8Hex "e4babae58a9be8b584e6ba90"),
  "zhuyifan",
  (From-Utf8Hex "e69cb1e680a1e5b886"),
  (From-Utf8Hex "e69e97e58588e7949f"),
  "MiniMax",
  "GitHub MCP",
  "Viy"
)

foreach ($needle in $forbidden) {
  Assert-True (-not $template.Contains($needle)) "Template contains forbidden text: $needle"
}

$claudeBaseSkill = Get-Content -Raw -Encoding UTF8 -LiteralPath $claudeBaseSkillPath
Assert-True ($claudeBaseSkill.Contains("name: pi-intern-base-installer")) "Claude base installer skill has wrong name."
Assert-True ($claudeBaseSkill.Contains("pi install git:github.com/Viy1204/pi-intern-agent-base@v0.1.0")) "Claude base installer skill missing base install command."
Assert-True ($claudeBaseSkill.Contains((From-Utf8Hex "e4b88de8a681e4bb8ee69cac20736b696c6c20e5ae89e8a38520485220e58c85"))) "Claude base installer skill missing HR guard."
Assert-True ($claudeBaseSkill.Contains("/login")) "Claude base installer skill must mention /login."
Assert-True ($claudeBaseSkill.Contains("/feishu setup")) "Claude base installer skill must mention /feishu setup."
Assert-True ($claudeBaseSkill.Contains("/feishu restart")) "Claude base installer skill must mention /feishu restart."
Assert-True ($claudeBaseSkill.Contains("spawn bash ENOENT")) "Claude base installer skill must mention spawn bash ENOENT."

$piSetupSkill = Get-Content -Raw -Encoding UTF8 -LiteralPath $piSetupSkillPath
Assert-True ($piSetupSkill.Contains("/login")) "Pi setup skill must mention /login."
Assert-True ($piSetupSkill.Contains("/feishu setup")) "Pi setup skill must mention /feishu setup."
Assert-True ($piSetupSkill.Contains("/feishu restart")) "Pi setup skill must mention /feishu restart."

$checkOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $checkScriptPath
$checkJson = $checkOutput | ConvertFrom-Json
$checkFields = @($checkJson.PSObject.Properties.Name)
Assert-True ($checkFields -contains "bashPath") "Environment check must report bashPath."
Assert-True ($checkFields -contains "nodeCanSpawnBash") "Environment check must report nodeCanSpawnBash."
Assert-True ($checkFields -contains "bridgeReady") "Environment check must report bridgeReady."
Assert-True ($checkFields -contains "recommendedFixes") "Environment check must report recommendedFixes."

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pi-intern-agent-base-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

try {
  $emptyWorkspace = Join-Path $tmpRoot "empty"
  New-Item -ItemType Directory -Path $emptyWorkspace | Out-Null
  $created = Invoke-Install -CliArgs @("-Scope", "project", "-Workspace", $emptyWorkspace)
  Assert-True ($created.Code -eq 0) "Expected project install to succeed. Output: $($created.Raw)"
  $projectAgents = Join-Path $emptyWorkspace ".pi\AGENTS.md"
  Assert-True (Test-Path -LiteralPath $projectAgents) "Project AGENTS.md was not created."
  Assert-True ((Get-Content -Raw -Encoding UTF8 -LiteralPath $projectAgents) -eq $template) "Project AGENTS.md content mismatch."

  $exists = Invoke-Install -CliArgs @("-Scope", "project", "-Workspace", $emptyWorkspace)
  Assert-True ($exists.Code -eq 2) "Expected existing project install to exit 2."
  Assert-True ($exists.Json.status -eq "exists") "Expected existing status."

  "old content" | Set-Content -LiteralPath $projectAgents -Encoding UTF8
  $forced = Invoke-Install -CliArgs @("-Scope", "project", "-Workspace", $emptyWorkspace, "-Force")
  Assert-True ($forced.Code -eq 0) "Expected forced project install to succeed."
  Assert-True ($forced.Json.status -eq "installed-with-backup") "Expected backup on forced overwrite."
  Assert-True (Test-Path -LiteralPath $forced.Json.backup) "Backup file was not created."

  $dryWorkspace = Join-Path $tmpRoot "dry"
  New-Item -ItemType Directory -Path $dryWorkspace | Out-Null
  $dry = Invoke-Install -CliArgs @("-Scope", "project", "-Workspace", $dryWorkspace, "-DryRun")
  Assert-True ($dry.Code -eq 0) "Expected dry run to succeed."
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $dryWorkspace ".pi\AGENTS.md"))) "Dry run should not create AGENTS.md."

  $fakeHome = Join-Path $tmpRoot "home"
  $globalDir = Join-Path $fakeHome ".pi\agent"
  New-Item -ItemType Directory -Path $globalDir -Force | Out-Null
  $globalAgents = Join-Path $globalDir "AGENTS.md"
  "global old content" | Set-Content -LiteralPath $globalAgents -Encoding UTF8
  $globalForced = Invoke-Install -CliArgs @("-Scope", "global", "-HomePath", $fakeHome, "-Force")
  Assert-True ($globalForced.Code -eq 0) "Expected forced global install to succeed."
  Assert-True ($globalForced.Json.status -eq "installed-with-backup") "Expected global install to create backup."
  Assert-True (Test-Path -LiteralPath $globalForced.Json.backup) "Global backup file was not created."
  Assert-True ((Get-Content -Raw -Encoding UTF8 -LiteralPath $globalAgents) -eq $template) "Global AGENTS.md content mismatch."

  $dryBase = & powershell -NoProfile -ExecutionPolicy Bypass -File $claudeBaseInstallScriptPath -Workspace $emptyWorkspace -DryRun
  $dryBaseJson = $dryBase | ConvertFrom-Json
  Assert-True ($null -ne $dryBaseJson.checks) "Expected base installer dry run to report checks."
  Assert-True ($null -ne $dryBaseJson.bridge) "Expected base installer dry run to report bridge check."
  Assert-True ($null -ne $dryBaseJson.firstLaunchSteps) "Expected base installer dry run to report first launch steps."
} finally {
  Remove-Item -Recurse -Force -LiteralPath $tmpRoot
}

Write-Output "All tests passed."
