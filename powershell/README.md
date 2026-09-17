# PowerShell performance telemetry

The profile automatically writes JSON Lines to
`$env:LOCALAPPDATA\PowerShell\Telemetry`. All terminals for the current Windows
user share this local directory. Each profile load has a unique session ID and
its own files, so concurrent terminals do not contend for a log file. Nothing is
uploaded.

Open a new terminal after installing the profile, then review the measurements:

```powershell
Get-PwshPerformance
Get-PwshPerformance -Days 30 -Daily | Format-Table
Get-PwshPerformance -Raw | Sort-Object duration_ms -Descending | Select-Object -First 20
explorer $global:PwshPerformance.Directory
```

Summaries show count, average, 95th percentile, and maximum milliseconds for each
event and stage. `-Daily` groups by UTC date. `-Raw` returns individual records,
including timestamps, session IDs, process IDs, and working directories, for
filtering or export:

```powershell
Get-PwshPerformance -Days 30 -Raw |
    Where-Object { $_.event -eq 'hook' -and $_.duration_ms -gt 200 } |
    Select-Object timestamp, session_id, cwd, duration_ms
Get-PwshPerformance -Days 30 -Daily | Export-Csv ./pwsh-performance.csv -NoTypeInformation
```

Recorded measurements:

| Event / stage | Measures |
| --- | --- |
| `session / start` | PowerShell version, host, machine, profile path, and process start time |
| `startup / telemetry` | Loading and initializing the logger, including retention cleanup |
| `startup / mise` | Finding mise, refreshing its activation cache if needed, and loading it |
| `startup / git-alias` | Finding Git and configuring the Bash alias |
| `startup / profile-total` | The whole shared profile, including instrumentation overhead |
| `startup / first-idle` | Deferred PSReadLine configuration and the initial mise hook |
| `hook / mise` | Runtime mise environment refreshes, including directory changes |

Stage measurements overlap: the profile total includes startup stages, and the
first idle action includes its mise hook. Do not add all rows together.
Durations use a monotonic stopwatch.

Each record includes `previous_write_ms`, the serialization and disk-write cost
of the preceding record in that session. Logging is synchronous, so this makes
its contribution visible. The logs contain no command text, command output, or
environment variable values. Paths and machine names are included.

Files roll over at midnight UTC or approximately 10 MiB. Files last written more
than 30 days ago are removed on profile load. Disk or serialization failures
disable logging for that session without interrupting the shell; inspect
`$global:PwshPerformance.LastError` for the reason.

For comparison with logging disabled, set `PWSH_PERF_DISABLE=1` before launching
a fresh shell:

```powershell
$env:PWSH_PERF_DISABLE = '1'
pwsh
Remove-Item Env:PWSH_PERF_DISABLE
```

Run `./init-windows.ps1` to install both `profile.ps1` and `performance.ps1` into
the all-users PowerShell profile directory. Existing terminals need to be
reopened to load the instrumentation.
