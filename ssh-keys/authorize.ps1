param(
    [string]$PublicKeyDirectory = $PSScriptRoot,
    [string]$AuthorizedKeysPath
)

$ErrorActionPreference = "Stop"

$publicKeys = @(Get-ChildItem -LiteralPath $PublicKeyDirectory -Filter "*.pub" -File | Sort-Object Name | ForEach-Object {
    Get-Content -LiteralPath $_.FullName | ForEach-Object {
        $key = $_.Trim()
        if ($key -and -not $key.StartsWith("#")) {
            $key
        }
    }
})
if ($publicKeys.Count -eq 0) {
    return
}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$administrators = [System.Security.Principal.SecurityIdentifier]::new("S-1-5-32-544")
$system = [System.Security.Principal.SecurityIdentifier]::new("S-1-5-18")
$isAdministrator = $identity.Groups.Contains($administrators)

if (-not $AuthorizedKeysPath) {
    $AuthorizedKeysPath = if ($isAdministrator) {
        Join-Path $env:ProgramData "ssh\administrators_authorized_keys"
    } else {
        Join-Path $HOME ".ssh\authorized_keys"
    }
}

$targetDirectory = Split-Path -Parent $AuthorizedKeysPath
[System.IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
if (-not (Test-Path -LiteralPath $AuthorizedKeysPath)) {
    [System.IO.File]::WriteAllText($AuthorizedKeysPath, "")
}

$owner = if ($isAdministrator) { $administrators } else { $identity.User }
$allowedPrincipals = @($administrators, $system, $owner) | Select-Object -Unique
$acl = [System.Security.AccessControl.FileSecurity]::new()
$acl.SetOwner($owner)
$acl.SetAccessRuleProtection($true, $false)
foreach ($principal in $allowedPrincipals) {
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($principal, "FullControl", "Allow"))
}
Set-Acl -LiteralPath $AuthorizedKeysPath -AclObject $acl

$existingContent = [System.IO.File]::ReadAllText($AuthorizedKeysPath)
$knownKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($line in ($existingContent -split '\r?\n')) {
    [void]$knownKeys.Add($line.Trim())
}
$utf8 = [System.Text.UTF8Encoding]::new($false)
foreach ($key in $publicKeys) {
    if ($knownKeys.Add($key)) {
        $separator = if ($existingContent.Length -gt 0 -and -not $existingContent.EndsWith("`n")) { "`n" } else { "" }
        [System.IO.File]::AppendAllText($AuthorizedKeysPath, "$separator$key`n", $utf8)
        $existingContent = "$key`n"
        Write-Host "Authorized public key -> $AuthorizedKeysPath"
    }
}
