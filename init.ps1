$ErrorActionPreference = "Stop"

function Set-CodexPermissions {
    param(
        [string]$ConfigPath = (Join-Path $HOME ".codex\config.toml"),
        [string]$GitIgnorePath = (Join-Path $HOME ".config\git\ignore")
    )

    $fragmentPath = Join-Path $PSScriptRoot ".codex\permissions.toml"
    $configDirectory = Split-Path -Parent $configPath
    $mergeExpression = '((select(fileIndex == 0) // {}) | del(.sandbox_workspace_write, .permissions.workspace_gitignore)) * (select(fileIndex == 1) | .permissions.workspace_gitignore.filesystem = {(strenv(GIT_IGNORE_PATH)): "read"})'

    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        throw "mise is required to update $configPath"
    }
    if (-not (Test-Path $fragmentPath)) {
        throw "Codex permissions fragment not found: $fragmentPath"
    }
    & mise install yq@latest
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to install yq@latest with mise"
    }
    $yqPath = & mise which yq --tool yq@latest
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $yqPath)) {
        throw "Unable to resolve yq@latest with mise"
    }

    New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
    if (-not (Test-Path $configPath)) {
        [System.IO.File]::WriteAllText($configPath, "", [System.Text.UTF8Encoding]::new($false))
    }

    $temporaryPath = Join-Path $configDirectory ".config.toml.$PID.tmp"
    $previousGitIgnorePath = $env:GIT_IGNORE_PATH
    try {
        $env:GIT_IGNORE_PATH = $gitIgnorePath
        $mergedLines = @(& $yqPath eval-all --input-format toml --output-format toml $mergeExpression $configPath $fragmentPath)
        if ($LASTEXITCODE -ne 0 -or $mergedLines.Count -eq 0) {
            throw "Unable to merge Codex settings with yq"
        }
        $encoding = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($temporaryPath, ($mergedLines -join [Environment]::NewLine) + [Environment]::NewLine, $encoding)
        Move-Item -LiteralPath $temporaryPath -Destination $configPath -Force
    } finally {
        $env:GIT_IGNORE_PATH = $previousGitIgnorePath
        if (Test-Path $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }

    Write-Host "Updated Codex permissions: $configPath"
}

$links = @(
    @{ Source = ".gitconfig"; Target = "$HOME\.gitconfig" },
    @{ Source = ".gitconfig-windows"; Target = "$HOME\.gitconfig-windows" },
    @{ Source = "mise-global-config.toml"; Target = "$HOME\.config\mise\config.toml" },
    @{ Source = ".wslconfig"; Target = "$HOME\.wslconfig" },
    @{ Source = ".claude\settings.json"; Target = "$HOME\.claude\settings.json" },
    @{ Source = ".claude\CLAUDE.md"; Target = "$HOME\.claude\CLAUDE.md" },
    @{ Source = ".codex\AGENTS.md"; Target = "$HOME\.codex\AGENTS.md" },
    @{ Source = ".codex\rules\default.rules"; Target = "$HOME\.codex\rules\default.rules" },
    @{ Source = ".grok\config.toml"; Target = "$HOME\.grok\config.toml" },
    @{ Source = ".codex\AGENTS.md"; Target = "$HOME\.grok\AGENTS.md" },
    @{ Source = ".config\opencode\opencode.jsonc"; Target = "$HOME\.config\opencode\opencode.jsonc" },
    @{ Source = ".claude\keybindings.json"; Target = "$HOME\.claude\keybindings.json" },
    @{ Source = "powershell\profile.ps1"; Target = $PROFILE.AllUsersAllHosts }
)

$pkg = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
if ($pkg) {
    $wtSettingsTarget = Join-Path $env:LOCALAPPDATA "Packages\$($pkg.PackageFamilyName)\LocalState\settings.json"
} else {
    $wtSettingsTarget = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"
}
$links += @{ Source = "windows-terminal\settings.json"; Target = $wtSettingsTarget }

foreach ($link in $links) {
    $sourceFile = Join-Path $PSScriptRoot $link.Source
    $target = $link.Target

    if (-not (Test-Path $sourceFile)) {
        Write-Error "Error: Source file not found: $sourceFile"
        exit 1
    }

    if (Test-Path $target) {
        Remove-Item $target -Force
        Write-Host "Removed existing: $target"
    }

    $targetDir = Split-Path -Parent $target
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    Copy-Item -Path $sourceFile -Destination $target
    Write-Host "Copied: $sourceFile -> $target"
}

Set-CodexPermissions

Write-Host "Done."
