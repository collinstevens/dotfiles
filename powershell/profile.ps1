$miseExe = (Get-Command mise -CommandType Application -ErrorAction SilentlyContinue).Source
if ($miseExe) {
    $miseCache = Join-Path $env:LOCALAPPDATA "mise-activate.cached.ps1"
    if (-not (Test-Path $miseCache) -or
        (Get-Item $miseCache).LastWriteTime -lt (Get-Item $miseExe).LastWriteTime) {
        & $miseExe activate pwsh | Where-Object { $_ -ne '_mise_hook' } | Set-Content $miseCache
    }
    . $miseCache
}

$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Set-PSReadLineOption -BellStyle None

    if (Test-Path Function:\_mise_hook) {
        _mise_hook
    }

    Import-Module posh-git -Global
    function global:prompt { & $global:GitPromptScriptBlock }
}

function mktemp {
    param([string]$Prefix)
    [System.IO.Directory]::CreateTempSubdirectory($Prefix).FullName
}

function cdtemp {
    param([string]$Prefix)
    Set-Location -Path (mktemp $Prefix)
}
