$pwshProfileTimer = [System.Diagnostics.Stopwatch]::StartNew()
. (Join-Path $PSScriptRoot 'performance.ps1')
Write-PwshPerformance -Event startup -Stage telemetry -DurationMs $pwshProfileTimer.Elapsed.TotalMilliseconds
$pwshStageTimer = [System.Diagnostics.Stopwatch]::StartNew()

$miseExe = (Get-Command mise -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if ($miseExe) {
    $miseCache = Join-Path $env:LOCALAPPDATA "mise-activate.cached.ps1"
    if (-not (Test-Path $miseCache) -or
        (Get-Item $miseCache).LastWriteTime -lt (Get-Item $miseExe).LastWriteTime) {
        & $miseExe activate pwsh | Where-Object { $_ -ne '_mise_hook' } | Set-Content $miseCache
    }
    . $miseCache
}
Write-PwshPerformance -Event startup -Stage mise -DurationMs $pwshStageTimer.Elapsed.TotalMilliseconds
$pwshStageTimer.Restart()

$gitInstallDirectory = Split-Path (Split-Path (Get-Command git.exe -CommandType Application | Select-Object -First 1).Source -Parent) -Parent
Set-Alias -Name gbash -Value (Join-Path $gitInstallDirectory "bin\bash.exe")
Write-PwshPerformance -Event startup -Stage git-alias -DurationMs $pwshStageTimer.Elapsed.TotalMilliseconds

if ($global:PwshPerformance.Enabled -and (Test-Path Function:\_mise_hook)) {
    $global:PwshPerformance.MiseHook = $function:_mise_hook
    function global:_mise_hook {
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            & $global:PwshPerformance.MiseHook @args
        } finally {
            Write-PwshPerformance -Event hook -Stage mise -DurationMs $timer.Elapsed.TotalMilliseconds
        }
    }
}

$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Set-PSReadLineOption -BellStyle None

        if (Test-Path Function:\_mise_hook) {
            _mise_hook
        }
    } finally {
        Write-PwshPerformance -Event startup -Stage first-idle -DurationMs $timer.Elapsed.TotalMilliseconds
    }
}

function mktemp {
    param([string]$Prefix)
    [System.IO.Directory]::CreateTempSubdirectory($Prefix).FullName
}

function cddir {
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $directoryPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $directory = [System.IO.Directory]::CreateDirectory($directoryPath)
    Set-Location -LiteralPath $directory.FullName
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

Write-PwshPerformance -Event startup -Stage profile-total -DurationMs $pwshProfileTimer.Elapsed.TotalMilliseconds
