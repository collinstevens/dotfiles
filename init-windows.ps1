& {
    $ErrorActionPreference = "Stop"
    $ProgressPreference = "SilentlyContinue"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run init-windows.ps1 from an elevated PowerShell session"
    }

    function Update-ProcessPath {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ";"
    }

    function Test-Application([string]$Command) {
        [bool](Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue)
    }

    Update-ProcessPath

    if (-not (Test-Application "winget.exe")) {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        Update-ProcessPath
        if (-not (Test-Application "winget.exe")) {
            throw "winget is not available; update App Installer from the Microsoft Store and rerun init-windows.ps1"
        }
    }

    if (-not (Test-Application "git.exe")) {
        & winget.exe install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to install Git with winget"
        }
        Update-ProcessPath
        if (-not (Test-Application "git.exe")) {
            throw "Git was installed but git.exe is not available"
        }
    }

    if (-not (Test-Application "pwsh.exe")) {
        $metadata = Invoke-RestMethod https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json
        $release = @($metadata.LTSReleaseTag)[0] -replace '^v'
        $architecture = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }
        $packageName = "PowerShell-$release-win-$architecture.msi"
        $downloadDirectory = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $downloadDirectory | Out-Null
        try {
            $packagePath = Join-Path $downloadDirectory $packageName
            Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/PowerShell/PowerShell/releases/download/v$release/$packageName" -OutFile $packagePath
            $msiArguments = "/i `"$packagePath`" /quiet /norestart ADD_PATH=1 USE_MU=1 ENABLE_MU=1"
            $process = Start-Process msiexec.exe -ArgumentList $msiArguments -Wait -PassThru
            if ($process.ExitCode -notin 0, 3010) {
                throw "Unable to install PowerShell $release (msiexec exit code $($process.ExitCode))"
            }
        } finally {
            Remove-Item -LiteralPath $downloadDirectory -Recurse -Force
        }

        Update-ProcessPath
        if (-not (Test-Application "pwsh.exe")) {
            throw "PowerShell $release was installed but pwsh.exe is not available"
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
        $PSNativeCommandArgumentPassing = "Legacy"
        & ssh-keygen.exe -t ed25519 -f $sshKeyPath -C $sshKeyComment -N '""'
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to create $sshKeyPath"
        }
        Write-Host "Created SSH key: $sshKeyPath.pub"
    }
}

if (-not $PSScriptRoot) {
    & {
        $ErrorActionPreference = "Stop"
        $repository = if ($env:DOTFILES_REPOSITORY) { $env:DOTFILES_REPOSITORY } else { "https://github.com/collinstevens/dotfiles.git" }
        $directory = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME "projects\collinstevens\dotfiles" }

        if (Test-Path -LiteralPath (Join-Path $directory ".git")) {
            & git.exe -C $directory pull --ff-only
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Unable to update $directory; continuing with the existing checkout"
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
    return
}

if ($PSVersionTable.PSEdition -ne "Core") {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}

$ErrorActionPreference = "Stop"

function Update-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ";"
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Command,
        [string]$Name
    )

    if ($Command -and (Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue)) {
        return
    }

    if (-not (Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error "Error: winget.exe is required to install $Name"
        exit 1
    }

    if (-not $Command) {
        & winget.exe list --id $Id --exact --source winget --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) {
            return
        }
    }

    & winget.exe install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: unable to install $Name"
        exit 1
    }

    Update-ProcessPath
    if ($Command -and -not (Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error "Error: $Name was installed but $Command is not available"
        exit 1
    }
}

Update-ProcessPath

function Copy-WslSystemFile {
    param(
        [string]$Source,
        [string]$Target
    )

    $sourceFile = Join-Path $PSScriptRoot $Source

    if (-not (Test-Path $sourceFile)) {
        Write-Error "Error: Source file not found: $sourceFile"
        exit 1
    }

    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Write-Host "Skipped: wsl.exe not found, cannot write $Target"
        return
    }

    $distributions = @(& wsl.exe --list --quiet) -replace "`0", "" | Where-Object { $_.Trim() }
    if ($LASTEXITCODE -ne 0 -or $distributions.Count -eq 0) {
        Write-Host "Skipped: no WSL distribution registered, cannot write $Target"
        return
    }

    $wslSource = & wsl.exe -u root wslpath -a ($sourceFile -replace '\\', '/')
    if ($LASTEXITCODE -ne 0 -or -not $wslSource) {
        Write-Error "Error: unable to translate $sourceFile to a WSL path"
        exit 1
    }

    & wsl.exe -u root sh -c "tr -d '\r' < '$wslSource' > '$Target'"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: unable to write $Target inside WSL"
        exit 1
    }

    Write-Host "Copied: $sourceFile -> wsl:$Target"
}

Install-WingetPackage -Id "GitHub.cli" -Command "gh" -Name "GitHub CLI"

& gh stack --help *> $null
if ($LASTEXITCODE -ne 0) {
    & gh extension install github/gh-stack
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: unable to install the gh stack extension"
        exit 1
    }
}

$githubKeyScopes = "admin:public_key,admin:ssh_signing_key"
& gh.exe auth status --hostname github.com *> $null
if ($LASTEXITCODE -ne 0) {
    & gh.exe auth login --hostname github.com --git-protocol https --web --scopes $githubKeyScopes
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: unable to log in to GitHub with gh"
        exit 1
    }
}

& gh.exe api user/keys --silent *> $null
$hasAuthenticationKeyScope = $LASTEXITCODE -eq 0
& gh.exe api user/ssh_signing_keys --silent *> $null
$hasSigningKeyScope = $LASTEXITCODE -eq 0
if (-not ($hasAuthenticationKeyScope -and $hasSigningKeyScope)) {
    & gh.exe auth refresh --hostname github.com --scopes $githubKeyScopes
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: unable to grant gh the SSH key scopes"
        exit 1
    }
}

$sshPublicKeyPath = Join-Path $HOME ".ssh\id_ed25519.pub"
$sshPublicKeyFields = @((Get-Content -Raw -LiteralPath $sshPublicKeyPath).Trim() -split '\s+')
$sshPublicKey = "$($sshPublicKeyFields[0]) $($sshPublicKeyFields[1])"
$sshKeyTitle = if ($sshPublicKeyFields.Count -gt 2) { $sshPublicKeyFields[2] } else { "$env:USERNAME-$env:COMPUTERNAME".ToLowerInvariant() }
foreach ($githubKey in @(
    @{ Type = "authentication"; Endpoint = "user/keys" },
    @{ Type = "signing"; Endpoint = "user/ssh_signing_keys" }
)) {
    $registeredKeys = @(& gh.exe api $githubKey.Endpoint --paginate --jq ".[].key")
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: unable to list GitHub $($githubKey.Type) keys"
        exit 1
    }
    if ($registeredKeys -notcontains $sshPublicKey) {
        & gh.exe ssh-key add $sshPublicKeyPath --title $sshKeyTitle --type $githubKey.Type
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error: unable to add $sshPublicKeyPath to GitHub as a $($githubKey.Type) key"
            exit 1
        }
    }
}

$githubHostKeys = @(& gh.exe api meta --jq ".ssh_keys[]")
if ($LASTEXITCODE -ne 0 -or $githubHostKeys.Count -eq 0) {
    Write-Error "Error: unable to read the GitHub SSH host keys"
    exit 1
}
$knownHostsPath = Join-Path $HOME ".ssh\known_hosts"
$knownHosts = if (Test-Path -LiteralPath $knownHostsPath) { [IO.File]::ReadAllText($knownHostsPath) } else { "" }
$knownHostLines = @($knownHosts -split '\r?\n')
$missingGitHubHostKeys = @($githubHostKeys | ForEach-Object { "github.com $_" } | Where-Object { $knownHostLines -notcontains $_ })
if ($missingGitHubHostKeys.Count -gt 0) {
    $separator = if ($knownHosts.Length -gt 0 -and -not $knownHosts.EndsWith("`n")) { "`n" } else { "" }
    [IO.File]::AppendAllText($knownHostsPath, $separator + ($missingGitHubHostKeys -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    Write-Host "Added GitHub SSH host keys -> $knownHostsPath"
}

$originUrl = & git.exe -C $PSScriptRoot remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $originUrl -match '^https://github\.com/([^/]+/[^/]+?)(\.git)?/?$') {
    $sshOriginUrl = "git@github.com:$($Matches[1]).git"
    & git.exe -C $PSScriptRoot remote set-url origin $sshOriginUrl
    & git.exe -C $PSScriptRoot ls-remote --exit-code origin HEAD *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Switched origin to SSH: $sshOriginUrl"
    } else {
        & git.exe -C $PSScriptRoot remote set-url origin $originUrl
        Write-Warning "Unable to reach $sshOriginUrl; keeping origin at $originUrl"
    }
}

Install-WingetPackage -Id "Microsoft.PowerToys" -Name "PowerToys"

& winget.exe pin add --id Microsoft.PowerShell --exact --source winget --blocking --force --accept-source-agreements
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: unable to block winget upgrades of PowerShell"
    exit 1
}

if (-not (Get-Command mise.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    Invoke-RestMethod https://mise.run/powershell | Invoke-Expression
    Update-ProcessPath
    if (-not (Get-Command mise.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error "Error: mise was installed but mise.exe is not available"
        exit 1
    }
}

$miseDataDirectory = if ($env:MISE_DATA_DIR) { $env:MISE_DATA_DIR } else { Join-Path $env:LOCALAPPDATA "mise" }
$miseShims = Join-Path $miseDataDirectory "shims"
$dotnetTools = Join-Path $HOME ".dotnet\tools"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$userPathEntries = @($userPath -split ";" | Where-Object {
    $_ -and [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') -ine $miseShims.TrimEnd('\') -and
        [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') -ine $dotnetTools.TrimEnd('\')
})
[Environment]::SetEnvironmentVariable("Path", (@($miseShims, $dotnetTools) + $userPathEntries) -join ";", "User")
Update-ProcessPath
$env:Path = (Join-Path $miseDataDirectory "dotnet-root") + ";" + $env:Path

$miseTools = @(
    "aspire",
    "aube",
    "bun",
    "dotnet",
    "git-lfs",
    "java",
    "jq",
    "node",
    "npm",
    "npm:wrangler",
    "pnpm",
    "python",
    "rg",
    "yq"
)

& mise.exe use --global ($miseTools | ForEach-Object { "$_@latest" })
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install global tools with mise"
}

foreach ($miseTool in $miseTools) {
    & mise.exe config set --global "tools.$miseTool.auto_update" false
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to disable auto_update for $miseTool"
    }
}

& mise.exe settings unset self_update.auto
if ($LASTEXITCODE -ne 0) {
    throw "Unable to disable mise self-update"
}

& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-counters --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-counters"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-coverage --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-coverage"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-debug --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-debug"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-dump --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-dump"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-gcdump --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-gcdump"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-monitor --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-monitor"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-trace --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-trace"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-stack --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-stack"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-symbol
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-symbol"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-debugger-extensions --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-debugger-extensions"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-sos --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-sos"
}
& mise.exe exec dotnet@latest -- dotnet tool install --global dotnet-dsrouter --allow-roll-forward
if ($LASTEXITCODE -ne 0) {
    throw "Unable to install or update dotnet-dsrouter"
}

$hackInstalled = $false
$hackFontRegistryName = "HackNerdFont-Regular (TrueType)"
$fontRegistryPaths = @(
    "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts",
    "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
)

foreach ($fontRegistryPath in $fontRegistryPaths) {
    if ((Test-Path $fontRegistryPath) -and
        ((Get-Item $fontRegistryPath).GetValueNames() -contains $hackFontRegistryName)) {
        $hackInstalled = $true
        break
    }
}

if (-not $hackInstalled) {
    if (-not (Get-Module -ListAvailable -Name NerdFonts)) {
        Install-PSResource -Name NerdFonts -Scope CurrentUser -TrustRepository
    }

    Import-Module NerdFonts
    Install-NerdFont -Name Hack -Variant Standard

    $userFontDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $hackFontFiles = @(Get-ChildItem $userFontDirectory -Filter "HackNerdFont-*.ttf" -File)
    if ($hackFontFiles.Count -eq 0) {
        Write-Error "Error: Hack Nerd Font files were not installed"
        exit 1
    }

    if (-not (Test-Path $fontRegistryPaths[0])) {
        New-Item -Path $fontRegistryPaths[0] -Force | Out-Null
    }

    foreach ($hackFontFile in $hackFontFiles) {
        New-ItemProperty `
            -Path $fontRegistryPaths[0] `
            -Name "$($hackFontFile.BaseName) (TrueType)" `
            -Value $hackFontFile.FullName `
            -PropertyType String `
            -Force | Out-Null
    }
}

if (-not (Get-Command claude.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 | iex"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: unable to install Claude Code"
        exit 1
    }
    Update-ProcessPath
    if (-not (Get-Command claude.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error "Error: Claude Code was installed but claude.exe is not available"
        exit 1
    }
}

$links = @(
    @{ Source = ".gitconfig"; Target = "$HOME\.gitconfig" },
    @{ Source = ".gitconfig-windows"; Target = "$HOME\.gitconfig-windows" },
    @{ Source = ".gitignore-global"; Target = "$HOME\.gitignore-global" },
    @{ Source = ".wslconfig"; Target = "$HOME\.wslconfig" },
    @{ Source = ".claude\settings-windows.json"; Target = "$HOME\.claude\settings.json" },
    @{ Source = ".claude\statusline-command.ps1"; Target = "$HOME\.claude\statusline-command.ps1" },
    @{ Source = ".claude\no-agent-summary.js"; Target = "$HOME\.claude\no-agent-summary.js" },
    @{ Source = "shared\AGENTS.md"; Target = "$HOME\.claude\CLAUDE.md" },
    @{ Source = "shared\skills\narrative-rewrite\SKILL.md"; Target = "$HOME\.claude\skills\narrative-rewrite\SKILL.md" },
    @{ Source = "shared\skills\git-cleanup\SKILL.md"; Target = "$HOME\.claude\skills\git-cleanup\SKILL.md" },
    @{ Source = "shared\AGENTS.md"; Target = "$HOME\.codex\AGENTS.md" },
    @{ Source = "shared\skills\narrative-rewrite\SKILL.md"; Target = "$HOME\.codex\skills\narrative-rewrite\SKILL.md" },
    @{ Source = "shared\skills\git-cleanup\SKILL.md"; Target = "$HOME\.codex\skills\git-cleanup\SKILL.md" },
    @{ Source = "shared\skills\narrative-rewrite\agents\openai.yaml"; Target = "$HOME\.codex\skills\narrative-rewrite\agents\openai.yaml" },
    @{ Source = "shared\skills\git-cleanup\agents\openai.yaml"; Target = "$HOME\.codex\skills\git-cleanup\agents\openai.yaml" },
    @{ Source = ".codex\rules\default.rules"; Target = "$HOME\.codex\rules\default.rules" },
    @{ Source = ".grok\config.toml"; Target = "$HOME\.grok\config.toml" },
    @{ Source = "shared\AGENTS.md"; Target = "$HOME\.grok\AGENTS.md" },
    @{ Source = ".config\opencode\opencode.jsonc"; Target = "$HOME\.config\opencode\opencode.jsonc" },
    @{ Source = ".claude\keybindings.json"; Target = "$HOME\.claude\keybindings.json" },
    @{ Source = "powershell\profile.ps1"; Target = $PROFILE.AllUsersAllHosts },
    @{ Source = "powershell\performance.ps1"; Target = (Join-Path (Split-Path $PROFILE.AllUsersAllHosts -Parent) "performance.ps1") }
)

$pkg = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
if (-not $pkg) {
    Install-WingetPackage -Id "Microsoft.WindowsTerminal" -Name "Windows Terminal"
    $pkg = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
    if (-not $pkg) {
        Write-Error "Error: Windows Terminal was installed but its package is not registered"
        exit 1
    }
}
$wtSettingsTarget = Join-Path $env:LOCALAPPDATA "Packages\$($pkg.PackageFamilyName)\LocalState\settings.json"
$links += @{ Source = "windows-terminal\settings.json"; Target = $wtSettingsTarget }

foreach ($link in $links) {
    $sourceFile = Join-Path $PSScriptRoot $link.Source
    $target = $link.Target

    if (-not (Test-Path $sourceFile)) {
        Write-Error "Error: Source file not found: $sourceFile"
        exit 1
    }

    if (Test-Path $target) {
        Remove-Item $target -Force
        Write-Host "Removed existing: $target"
    }

    $targetDir = Split-Path -Parent $target
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    Copy-Item -Path $sourceFile -Destination $target
    Write-Host "Copied: $sourceFile -> $target"
}

$noAgentSummaryPreload = (Join-Path $HOME ".claude\no-agent-summary.js").Replace('\', '/')
[Environment]::SetEnvironmentVariable("BUN_OPTIONS", "--preload $noAgentSummaryPreload", "User")

& mise.exe exec yq@latest -- (Get-Process -Id $PID).Path -NoProfile -File (Join-Path $PSScriptRoot ".codex\configure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Unable to merge Codex settings"
}
& (Join-Path $PSScriptRoot ".claude\configure-mcp.ps1")
& (Join-Path $PSScriptRoot "ssh-keys\authorize.ps1")

Copy-WslSystemFile -Source "wsl.conf" -Target "/etc/wsl.conf"

Write-Host "Done."
