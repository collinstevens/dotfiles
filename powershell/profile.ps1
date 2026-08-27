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
