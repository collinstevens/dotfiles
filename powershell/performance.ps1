$global:PwshPerformance = @{
    Enabled = $env:PWSH_PERF_DISABLE -ne '1'
    Directory = Join-Path $env:LOCALAPPDATA 'PowerShell\Telemetry'
    Session = [guid]::NewGuid().ToString('N')
    Process = [System.Diagnostics.Process]::GetCurrentProcess()
    PreviousWriteMs = 0.0
    FileDate = ''
    FileBytes = 0L
    FileIndex = 0
    PromptCount = 0
    LastError = $null
}

function Write-PwshPerformance {
    param(
        [string]$Event,
        [string]$Stage,
        [double]$DurationMs,
        [hashtable]$Details = @{}
    )

    $state = $global:PwshPerformance
    if (-not $state.Enabled) { return }
    $writeTimer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $now = [DateTime]::UtcNow
        $date = $now.ToString('yyyy-MM-dd')
        if ($state.FileDate -ne $date) {
            $state.FileDate = $date
            $state.FileIndex = 0
            $state.FileBytes = 0L
        }
        if ($state.FileBytes -ge 10MB) {
            $state.FileIndex++
            $state.FileBytes = 0L
        }
        $record = [ordered]@{
            schema_version = 1
            timestamp = $now.ToString('o')
            session_id = $state.Session
            pid = $PID
            event = $Event
            stage = $Stage
            duration_ms = [math]::Round($DurationMs, 3)
            cwd = $ExecutionContext.SessionState.Path.CurrentLocation.Path
            previous_write_ms = [math]::Round($state.PreviousWriteMs, 3)
        }
        foreach ($key in $Details.Keys) { $record[$key] = $Details[$key] }
        $line = ($record | ConvertTo-Json -Compress -Depth 4) + "`n"
        $path = Join-Path $state.Directory "$date-$($state.Session)-$($state.FileIndex).jsonl"
        [System.IO.File]::AppendAllText($path, $line, [System.Text.UTF8Encoding]::new($false))
        $state.FileBytes += [System.Text.Encoding]::UTF8.GetByteCount($line)
    } catch {
        $state.Enabled = $false
        $state.LastError = $_.Exception.Message
    } finally {
        $state.PreviousWriteMs = $writeTimer.Elapsed.TotalMilliseconds
    }
}

function Get-PwshPerformance {
    param(
        [ValidateRange(1, 3650)]
        [int]$Days = 7,
        [switch]$Raw,
        [switch]$Daily
    )

    $cutoff = [DateTime]::UtcNow.AddDays(-$Days)
    $records = @(Get-ChildItem -LiteralPath $global:PwshPerformance.Directory -Filter '*.jsonl' -File -ErrorAction SilentlyContinue |
        Where-Object LastWriteTimeUtc -ge $cutoff |
        ForEach-Object {
            $reader = $null
            try {
                $stream = [System.IO.File]::Open($_.FullName, [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
                $reader = [System.IO.StreamReader]::new($stream)
                while ($null -ne ($line = $reader.ReadLine())) {
                    try {
                        $record = $line | ConvertFrom-Json -ErrorAction Stop
                        if ([DateTime]$record.timestamp -ge $cutoff) { $record }
                    } catch {}
                }
            } catch [System.IO.FileNotFoundException] {
            } finally {
                if ($reader) { $reader.Dispose() }
            }
        })
    if ($Raw) { return $records }
    $groupProperties = @('event', 'stage')
    if ($Daily) { $groupProperties = @({ ([DateTime]$_.timestamp).ToUniversalTime().ToString('yyyy-MM-dd') }) + $groupProperties }
    $records | Group-Object -Property $groupProperties | ForEach-Object {
        $durations = @($_.Group.duration_ms | Sort-Object)
        $summary = [ordered]@{}
        if ($Daily) { $summary.Date = ([DateTime]$_.Group[0].timestamp).ToUniversalTime().ToString('yyyy-MM-dd') }
        $summary.Event = $_.Group[0].event
        $summary.Stage = $_.Group[0].stage
        $summary.Count = $durations.Count
        $summary.AverageMs = [math]::Round(($durations | Measure-Object -Average).Average, 2)
        $summary.P95Ms = $durations[[math]::Ceiling($durations.Count * 0.95) - 1]
        $summary.MaxMs = $durations[-1]
        [pscustomobject]$summary
    } | Sort-Object MaxMs -Descending
}

if ($global:PwshPerformance.Enabled) {
    try {
        $null = [System.IO.Directory]::CreateDirectory($global:PwshPerformance.Directory)
        Get-ChildItem -LiteralPath $global:PwshPerformance.Directory -Filter '*.jsonl' -File |
            Where-Object LastWriteTimeUtc -lt ([DateTime]::UtcNow.AddDays(-30)) |
            Remove-Item -Force -ErrorAction Stop
    } catch {
        $global:PwshPerformance.Enabled = $false
        $global:PwshPerformance.LastError = $_.Exception.Message
    }
}

Write-PwshPerformance -Event session -Stage start -DurationMs 0 -Details @{
    powershell_version = $PSVersionTable.PSVersion.ToString()
    host_name = $Host.Name
    machine = [Environment]::MachineName
    profile_path = $PROFILE.AllUsersAllHosts
    process_started_at = $global:PwshPerformance.Process.StartTime.ToUniversalTime().ToString('o')
}
