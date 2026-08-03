$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$json = [Console]::In.ReadToEnd()
$data = $json | ConvertFrom-Json

function Get-Prop($Object, $Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

$escape = [char]27
$reset = "$escape[0m"
$dim = "$escape[2m"
$underline = "$escape[4m"
$yellow = "$escape[38;2;246;226;183m"
$peach = "$escape[38;2;242;181;144m"
$red = "$escape[38;2;233;144;169m"
$blue = "$escape[38;2;143;179;239m"
$mauve = "$escape[38;2;200;169;238m"
$green = "$escape[38;2;171;223;167m"
$segments = @()

$model = Get-Prop $data.model 'display_name'
if ([string]::IsNullOrEmpty($model)) { $model = Get-Prop $data.model 'id' }
if ($model) {
    $effort = Get-Prop $data.effort 'level'
    if ([string]::IsNullOrEmpty($effort)) { $effort = 'default' }
    $segment = "$model $effort"
    if (Get-Prop $data 'fast_mode') { $segment = "$segment fast" }
    $segments += "$yellow$segment$reset"
}

$permissionMode = $null
foreach ($candidate in @('permissionMode', 'permission_mode')) {
    $value = Get-Prop $data $candidate
    if ($null -ne $value) { $permissionMode = $value; break }
}
if ($permissionMode) { $segments += "$mauve$permissionMode$reset" }

$contextUsed = Get-Prop (Get-Prop $data 'context_window') 'used_percentage'
if ($null -eq $contextUsed) { $contextUsed = 0 }
$segments += ($peach + ("Context {0:N0}% used" -f [double]$contextUsed) + $reset)

$rateLimits = Get-Prop $data 'rate_limits'
$fiveHourUsed = Get-Prop (Get-Prop $rateLimits 'five_hour') 'used_percentage'
if ($null -ne $fiveHourUsed) {
    $segments += ($red + ("5h {0:N0}% left" -f (100 - [double]$fiveHourUsed)) + $reset)
}

$weeklyUsed = Get-Prop (Get-Prop $rateLimits 'seven_day') 'used_percentage'
if ($null -ne $weeklyUsed) {
    $segments += ($red + ("weekly {0:N0}% left" -f (100 - [double]$weeklyUsed)) + $reset)
}

$pullRequest = Get-Prop $data 'pr'
$pullRequestNumber = Get-Prop $pullRequest 'number'
if ($pullRequestNumber) {
    $pullRequestText = $blue + $underline + "PR #$pullRequestNumber" + $reset
    $pullRequestUrl = Get-Prop $pullRequest 'url'
    if ($pullRequestUrl) { $pullRequestText = "$escape]8;;$pullRequestUrl$escape\$pullRequestText$escape]8;;$escape\" }
    $segments += $pullRequestText
}

$workspace = Get-Prop $data 'workspace'
$workDirectory = Get-Prop $workspace 'current_dir'
if ([string]::IsNullOrEmpty($workDirectory)) { $workDirectory = Get-Prop $data 'cwd' }
if ($workDirectory) {
    $branch = git -C $workDirectory branch --show-current 2>$null
    if ($branch) { $segments += "$blue$branch$reset" }
}

$repository = Get-Prop $workspace 'repo'
$projectName = Get-Prop $repository 'name'
if ([string]::IsNullOrEmpty($projectName)) {
    $projectDirectory = Get-Prop $workspace 'project_dir'
    if ($projectDirectory) { $projectName = Split-Path $projectDirectory -Leaf }
}
if ($projectName) { $segments += "$green$projectName$reset" }

$separator = $dim + ' ' + [char]0x00B7 + ' ' + $reset
Write-Host -NoNewline ($segments -join $separator)
