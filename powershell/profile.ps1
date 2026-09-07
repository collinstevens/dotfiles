$env:STARSHIP_CONFIG = Join-Path $HOME ".config\starship-windows.toml"
$starshipExe = (Get-Command starship -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $starshipExe) {
    $starshipExe = Join-Path $env:ProgramFiles "starship\bin\starship.exe"
}
Invoke-Expression (& $starshipExe init powershell)

Import-Module posh-git

$gitInstallDirectory = Split-Path (Split-Path (Get-Command git.exe -CommandType Application | Select-Object -First 1).Source -Parent) -Parent
Set-Alias -Name gbash -Value (Join-Path $gitInstallDirectory "bin\bash.exe")

$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Set-PSReadLineOption -BellStyle None
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
}
