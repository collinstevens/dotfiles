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

$env:STARSHIP_CONFIG = Join-Path $HOME ".config\starship-windows.toml"
$starshipExe = (Get-Command starship -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $starshipExe) {
    $starshipExe = Join-Path $env:ProgramFiles "starship\bin\starship.exe"
}
Invoke-Expression (& $starshipExe init powershell)
Write-PwshPerformance -Event startup -Stage starship -DurationMs $pwshStageTimer.Elapsed.TotalMilliseconds
$pwshStageTimer.Restart()

Import-Module posh-git
Write-PwshPerformance -Event startup -Stage posh-git -DurationMs $pwshStageTimer.Elapsed.TotalMilliseconds
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

if ($global:PwshPerformance.Enabled) {
    $global:PwshPerformance.Prompt = $function:prompt
    function global:prompt {
        $previousSuccess = $?
        $previousExitCode = $global:LASTEXITCODE
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            if (-not $previousSuccess) { Write-Error '' -ErrorAction Ignore }
            & $global:PwshPerformance.Prompt
        } finally {
            $durationMs = $timer.Elapsed.TotalMilliseconds
            $state = $global:PwshPerformance
            $state.PromptCount++
            if ($state.PromptCount -eq 1) {
                Write-PwshPerformance -Event startup -Stage process-to-first-prompt -DurationMs ([DateTime]::Now - $state.Process.StartTime).TotalMilliseconds
            }
            Write-PwshPerformance -Event prompt -Stage render -DurationMs $durationMs -Details @{
                prompt_number = $state.PromptCount
                previous_success = $previousSuccess
                last_exit_code = $previousExitCode
            }
            $global:LASTEXITCODE = $previousExitCode
        }
        if (-not $previousSuccess) { Write-Error '' -ErrorAction Ignore }
    }
}

Write-PwshPerformance -Event startup -Stage profile-total -DurationMs $pwshProfileTimer.Elapsed.TotalMilliseconds
