$miseExe = (Get-Command mise -CommandType Application -ErrorAction SilentlyContinue).Source
if ($miseExe) {
    $miseCache = Join-Path $env:LOCALAPPDATA "mise-activate.cached.ps1"
    if (-not (Test-Path $miseCache) -or
        (Get-Item $miseCache).LastWriteTime -lt (Get-Item $miseExe).LastWriteTime) {
        & $miseExe activate pwsh | Where-Object { $_ -ne '_mise_hook' } | Set-Content $miseCache
    }
    . $miseCache
}

Import-Module posh-git -Global
$global:GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true
function global:prompt { & $global:GitPromptScriptBlock }

$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Set-PSReadLineOption -BellStyle None

    if (Test-Path Function:\_mise_hook) {
        _mise_hook
    }
}

function mktemp {
    param([string]$Prefix)
    [System.IO.Directory]::CreateTempSubdirectory($Prefix).FullName
}

function cdtemp {
    param([string]$Prefix)
    Set-Location -Path (mktemp $Prefix)
}

function reloadenv {
    $machineEnvironment = [Environment]::GetEnvironmentVariables("Machine")
    $userEnvironment = [Environment]::GetEnvironmentVariables("User")

    foreach ($variable in $machineEnvironment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($variable.Key, $variable.Value, "Process")
    }

    foreach ($variable in $userEnvironment.GetEnumerator()) {
        if ($variable.Key -ne "Path") {
            [Environment]::SetEnvironmentVariable($variable.Key, $variable.Value, "Process")
        }
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ";"

    if (Test-Path Function:\_mise_hook) {
        _mise_hook
    }
}
