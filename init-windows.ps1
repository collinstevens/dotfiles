$ErrorActionPreference = "Stop"

function Update-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ";"
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Command,
        [string]$Name
    )

    if (Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue) {
        return
    }

    if (-not (Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error "Error: winget.exe is required to install $Name"
        exit 1
    }

    & winget.exe install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: unable to install $Name"
        exit 1
    }

    Update-ProcessPath
    if (-not (Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error "Error: $Name was installed but $Command is not available"
        exit 1
    }
}

Update-ProcessPath

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

Install-WingetPackage -Id "Starship.Starship" -Command "starship" -Name "Starship"
Install-WingetPackage -Id "MikeFarah.yq" -Command "yq" -Name "yq"

if (-not (Get-Module -ListAvailable -Name posh-git)) {
    Install-PSResource -Name posh-git -Scope CurrentUser -TrustRepository
}

$hackInstalled = $false
$hackFontRegistryName = "HackNerdFont-Regular (TrueType)"
$fontRegistryPaths = @(
    "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts",
    "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
)

foreach ($fontRegistryPath in $fontRegistryPaths) {
    if ((Test-Path $fontRegistryPath) -and
        ((Get-Item $fontRegistryPath).GetValueNames() -contains $hackFontRegistryName)) {
        $hackInstalled = $true
        break
    }
}

if (-not $hackInstalled) {
    if (-not (Get-Module -ListAvailable -Name NerdFonts)) {
        Install-PSResource -Name NerdFonts -Scope CurrentUser -TrustRepository
    }

    Import-Module NerdFonts
    Install-NerdFont -Name Hack -Variant Standard

    $userFontDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $hackFontFiles = @(Get-ChildItem $userFontDirectory -Filter "HackNerdFont-*.ttf" -File)
    if ($hackFontFiles.Count -eq 0) {
        Write-Error "Error: Hack Nerd Font files were not installed"
        exit 1
    }

    if (-not (Test-Path $fontRegistryPaths[0])) {
        New-Item -Path $fontRegistryPaths[0] -Force | Out-Null
    }

    foreach ($hackFontFile in $hackFontFiles) {
        New-ItemProperty `
            -Path $fontRegistryPaths[0] `
            -Name "$($hackFontFile.BaseName) (TrueType)" `
            -Value $hackFontFile.FullName `
            -PropertyType String `
            -Force | Out-Null
    }
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
    @{ Source = ".config\starship-windows.toml"; Target = "$HOME\.config\starship.toml" },
    @{ Source = ".claude\keybindings.json"; Target = "$HOME\.claude\keybindings.json" },
    @{ Source = "powershell\profile.ps1"; Target = $PROFILE.AllUsersAllHosts }
)

$skillLinks = @(
    @{ Source = "vendor\humanlayer-skills\plugins\show-me\skills\show-me"; Target = "$HOME\.claude\skills\show-me" },
    @{ Source = "vendor\humanlayer-skills\plugins\show-me\skills\show-me"; Target = "$HOME\.codex\skills\show-me" },
    @{ Source = "vendor\humanlayer-skills\plugins\show-me\skills\show-me"; Target = "$HOME\.grok\skills\show-me" },
    @{ Source = "vendor\mattpocock-skills\skills\engineering\domain-modeling"; Target = "$HOME\.claude\skills\domain-modeling" },
    @{ Source = "vendor\mattpocock-skills\skills\engineering\domain-modeling"; Target = "$HOME\.codex\skills\domain-modeling" },
    @{ Source = "vendor\mattpocock-skills\skills\engineering\domain-modeling"; Target = "$HOME\.grok\skills\domain-modeling" },
    @{ Source = "vendor\mattpocock-skills\skills\engineering\grill-with-docs"; Target = "$HOME\.claude\skills\grill-with-docs" },
    @{ Source = "vendor\mattpocock-skills\skills\engineering\grill-with-docs"; Target = "$HOME\.codex\skills\grill-with-docs" },
    @{ Source = "vendor\mattpocock-skills\skills\engineering\grill-with-docs"; Target = "$HOME\.grok\skills\grill-with-docs" },
    @{ Source = "vendor\mattpocock-skills\skills\productivity\grill-me"; Target = "$HOME\.claude\skills\grill-me" },
    @{ Source = "vendor\mattpocock-skills\skills\productivity\grill-me"; Target = "$HOME\.codex\skills\grill-me" },
    @{ Source = "vendor\mattpocock-skills\skills\productivity\grill-me"; Target = "$HOME\.grok\skills\grill-me" },
    @{ Source = "vendor\mattpocock-skills\skills\productivity\grilling"; Target = "$HOME\.claude\skills\grilling" },
    @{ Source = "vendor\mattpocock-skills\skills\productivity\grilling"; Target = "$HOME\.codex\skills\grilling" },
    @{ Source = "vendor\mattpocock-skills\skills\productivity\grilling"; Target = "$HOME\.grok\skills\grilling" }
)

& git -C $PSScriptRoot submodule update --init --recursive -- vendor/humanlayer-skills vendor/mattpocock-skills
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: unable to initialize skill submodules"
    exit 1
}

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

foreach ($link in $skillLinks) {
    $sourceDirectory = Join-Path $PSScriptRoot $link.Source
    $target = $link.Target

    if (-not (Test-Path -PathType Container $sourceDirectory)) {
        Write-Error "Error: Source directory not found: $sourceDirectory"
        exit 1
    }

    if (Test-Path $target) {
        Remove-Item $target -Recurse -Force
        Write-Host "Removed existing: $target"
    }

    $targetDir = Split-Path -Parent $target
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    Copy-Item -Path $sourceDirectory -Destination $target -Recurse
    Write-Host "Copied: $sourceDirectory -> $target"
}

& (Join-Path $PSScriptRoot ".codex\configure.ps1")

Copy-WslSystemFile -Source "wsl.conf" -Target "/etc/wsl.conf"

Write-Host "Done."
