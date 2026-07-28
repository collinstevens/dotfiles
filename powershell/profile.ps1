# Silence PSReadLine's beep (e.g. backspace at the start of the prompt).
# This plays via Console.Beep, so Windows Terminal's bellStyle can't suppress it.
Set-PSReadLineOption -BellStyle None

Import-Module posh-git

(&mise activate pwsh) | Out-String | Invoke-Expression

function mktemp {
    param([string]$Prefix)
    [System.IO.Directory]::CreateTempSubdirectory($Prefix).FullName
}

function cdtemp {
    param([string]$Prefix)
    Set-Location -Path (mktemp $Prefix)
}
