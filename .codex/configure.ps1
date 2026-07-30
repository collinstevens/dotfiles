param(
    [string]$ConfigPath = (Join-Path $HOME ".codex\config.toml"),
    [string]$GitIgnorePath = (Join-Path $HOME ".config\git\ignore")
)

$ErrorActionPreference = "Stop"

$managedConfigPath = Join-Path $PSScriptRoot "managed-config.toml"
$permissionsPath = Join-Path $PSScriptRoot "permissions.toml"
$configDirectory = Split-Path -Parent $ConfigPath
$mergeExpression = '((select(fileIndex == 0) // {}) | del(.sandbox_workspace_write, .permissions.workspace_gitignore)) * (select(fileIndex == 1)) * (select(fileIndex == 2) | .permissions.workspace_gitignore.filesystem = {(strenv(GIT_IGNORE_PATH)): "read"})'

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    throw "mise is required to update $ConfigPath"
}
foreach ($fragmentPath in @($managedConfigPath, $permissionsPath)) {
    if (-not (Test-Path -LiteralPath $fragmentPath)) {
        throw "Codex configuration fragment not found: $fragmentPath"
    }
}

& mise install yq@latest
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install yq@latest with mise"
}
$yqPath = & mise which yq --tool yq@latest
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $yqPath)) {
    throw "Unable to resolve yq@latest with mise"
}

New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $ConfigPath)) {
    [System.IO.File]::WriteAllText($ConfigPath, "", [System.Text.UTF8Encoding]::new($false))
}

$temporaryPath = Join-Path $configDirectory ".config.toml.$PID.tmp"
$previousGitIgnorePath = $env:GIT_IGNORE_PATH
try {
    $env:GIT_IGNORE_PATH = $GitIgnorePath
    $mergedLines = @(& $yqPath eval-all --input-format toml --output-format toml $mergeExpression $ConfigPath $managedConfigPath $permissionsPath)
    if ($LASTEXITCODE -ne 0 -or $mergedLines.Count -eq 0) {
        throw "Unable to merge Codex settings with yq"
    }
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($temporaryPath, ($mergedLines -join [Environment]::NewLine) + [Environment]::NewLine, $encoding)
    Move-Item -LiteralPath $temporaryPath -Destination $ConfigPath -Force
} finally {
    $env:GIT_IGNORE_PATH = $previousGitIgnorePath
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
}

Write-Host "Updated Codex configuration: $ConfigPath"
