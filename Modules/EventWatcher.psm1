Set-StrictMode -Version Latest

function Get-CDSRecentEvents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$EventLogs,
        [datetime]$StartTime = (Get-Date).AddMinutes(-5),
        [ValidateRange(1, 5000)][int]$MaxEvents = 200
    )

    $events = foreach ($eventLog in $EventLogs) {
        $logName = [string]$eventLog.LogName
        $levels = @($eventLog.Levels | ForEach-Object { [int]$_ })

        if ([string]::IsNullOrWhiteSpace($logName)) {
            continue
        }

        $filter = @{
            LogName   = $logName
            StartTime = $StartTime
        }

        if ($levels.Count -gt 0) {
            $filter.Level = $levels
        }

        try {
            Get-WinEvent -FilterHashtable $filter -MaxEvents $MaxEvents -ErrorAction Stop |
                Select-Object @{Name='LogName';Expression={$_.LogName}},
                              @{Name='TimeCreated';Expression={$_.TimeCreated}},
                              @{Name='Level';Expression={$_.Level}},
                              @{Name='LevelDisplayName';Expression={$_.LevelDisplayName}},
                              @{Name='ProviderName';Expression={$_.ProviderName}},
                              @{Name='Id';Expression={$_.Id}},
                              @{Name='RecordId';Expression={$_.RecordId}},
                              @{Name='Message';Expression={$_.Message}}
        }
        catch {
            [pscustomobject]@{
                LogName          = $logName
                TimeCreated      = Get-Date
                Level            = 2
                LevelDisplayName = 'Error'
                ProviderName     = 'CinemaxX.DiagnosticsSuite'
                Id               = 0
                RecordId         = 0
                Message          = "Ereignisprotokoll konnte nicht gelesen werden: $($_.Exception.Message)"
            }
        }
    }

    return @($events | Sort-Object TimeCreated -Descending | Select-Object -First $MaxEvents)
}

function Export-CDSEvents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Events,
        [Parameter(Mandatory)][string]$Path
    )

    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -Path $parent -ItemType Directory -Force -ErrorAction Stop)
    }

    $Events | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction Stop
    return $Path
}

Export-ModuleMember -Function @(
    'Get-CDSRecentEvents',
    'Export-CDSEvents'
)
