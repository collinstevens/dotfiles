$env:STARSHIP_CONFIG = Join-Path $HOME ".config\starship-windows.toml"
$starshipExe = (Get-Command starship -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $starshipExe) {
    $starshipExe = Join-Path $env:ProgramFiles "starship\bin\starship.exe"
}
Invoke-Expression (& $starshipExe init powershell)

Import-Module posh-git

$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Set-PSReadLineOption -BellStyle None
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
