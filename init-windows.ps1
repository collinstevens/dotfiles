$ErrorActionPreference = "Stop"

function Copy-WslSystemFile {
    param(
        [string]$Source,
        [string]$Target
    )

    $sourceFile = Join-Path $PSScriptRoot $Source

    if (-not (Test-Path $sourceFile)) {
        Write-Error "Error: Source file not found: $sourceFile"
        exit 1
    }

    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Write-Host "Skipped: wsl.exe not found, cannot write $Target"
        return
    }

    $distributions = @(& wsl.exe --list --quiet) -replace "`0", "" | Where-Object { $_.Trim() }
    if ($LASTEXITCODE -ne 0 -or $distributions.Count -eq 0) {
        Write-Host "Skipped: no WSL distribution registered, cannot write $Target"
        return
    }

    $wslSource = & wsl.exe -u root wslpath -a ($sourceFile -replace '\\', '/')
    if ($LASTEXITCODE -ne 0 -or -not $wslSource) {
        Write-Error "Error: unable to translate $sourceFile to a WSL path"
        exit 1
    }

    & wsl.exe -u root sh -c "tr -d '\r' < '$wslSource' > '$Target'"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: unable to write $Target inside WSL"
        exit 1
    }

    Write-Host "Copied: $sourceFile -> wsl:$Target"
}

if (-not (Get-Module -ListAvailable -Name posh-git)) {
    Install-Module -Name posh-git -Scope CurrentUser -Force
}

$links = @(
    @{ Source = ".gitconfig"; Target = "$HOME\.gitconfig" },
    @{ Source = ".gitconfig-windows"; Target = "$HOME\.gitconfig-windows" },
    @{ Source = ".gitignore-global"; Target = "$HOME\.gitignore-global" },
    @{ Source = ".wslconfig"; Target = "$HOME\.wslconfig" },
    @{ Source = ".claude\settings-windows.json"; Target = "$HOME\.claude\settings.json" },
    @{ Source = ".claude\statusline-command.ps1"; Target = "$HOME\.claude\statusline-command.ps1" },
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

& (Join-Path $PSScriptRoot ".codex\configure.ps1")

Copy-WslSystemFile -Source "wsl.conf" -Target "/etc/wsl.conf"

Write-Host "Done."
