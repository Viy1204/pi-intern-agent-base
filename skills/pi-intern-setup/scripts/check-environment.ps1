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
} | ConvertTo-Json -Depth 4
