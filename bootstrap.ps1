& {
    $ErrorActionPreference = "Stop"
    $ProgressPreference = "SilentlyContinue"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $repository = if ($env:DOTFILES_REPOSITORY) { $env:DOTFILES_REPOSITORY } else { "https://github.com/collinstevens/dotfiles.git" }
    $directory = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME "projects\collinstevens\dotfiles" }

    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run the dotfiles bootstrap from an elevated PowerShell session"
    }

    function Update-ProcessPath {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ";"
    }

    function Test-Application([string]$Command) {
        [bool](Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue)
    }

    function Install-WingetPackage([string]$Id, [string]$Command) {
        if (Test-Application $Command) {
            return
        }

        & winget.exe install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to install $Id with winget"
        }

        Update-ProcessPath
        if (-not (Test-Application $Command)) {
            throw "$Id was installed but $Command is not available"
        }
    }

    Update-ProcessPath

    if (-not (Test-Application "winget.exe")) {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        Update-ProcessPath
        if (-not (Test-Application "winget.exe")) {
            throw "winget is not available; update App Installer from the Microsoft Store and rerun the bootstrap"
        }
    }

    $sshKeyPath = Join-Path $HOME ".ssh\id_ed25519"
    if (-not (Test-Path -LiteralPath $sshKeyPath)) {
        if (-not (Test-Application "ssh-keygen.exe")) {
            Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
            Update-ProcessPath
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $sshKeyPath) -Force | Out-Null
        $sshKeyComment = "$env:USERNAME-$env:COMPUTERNAME".ToLowerInvariant()
        & ssh-keygen.exe -t ed25519 -f $sshKeyPath -C $sshKeyComment
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to create $sshKeyPath"
        }
        Write-Host "Created SSH key: $sshKeyPath.pub"
    }

    Install-WingetPackage -Id "Git.Git" -Command "git.exe"
    Install-WingetPackage -Id "Microsoft.PowerShell" -Command "pwsh.exe"

    if (Test-Path -LiteralPath (Join-Path $directory ".git")) {
        & git.exe -C $directory pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to update $directory"
        }
    } elseif (Test-Path -LiteralPath $directory) {
        throw "$directory already exists and is not a Git checkout"
    } else {
        & git.exe clone $repository $directory
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to clone $repository into $directory"
        }
    }

    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $directory "init-windows.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "init-windows.ps1 failed"
    }
}
