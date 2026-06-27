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

$links = @(
    @{ Source = ".gitconfig"; Target = "$HOME\.gitconfig" },
    @{ Source = ".gitconfig-windows"; Target = "$HOME\.gitconfig-windows" },
    @{ Source = ".gitignore-global"; Target = "$HOME\.gitignore-global" },
    @{ Source = ".wslconfig"; Target = "$HOME\.wslconfig" },
    @{ Source = "powershell\profile.ps1"; Target = $PROFILE.AllUsersAllHosts }
)

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

Copy-WslSystemFile -Source "wsl.conf" -Target "/etc/wsl.conf"

Write-Host "Done."
