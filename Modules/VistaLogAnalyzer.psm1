Set-StrictMode -Version Latest

function Get-CDSVistaLogSummary {
    [CmdletBinding()]
    param(
        [string]$LogFolder = 'C:\Vista\Log',

        [ValidateRange(1, 365)]
        [int]$MaxAgeDays = 7
    )

    if (-not (Test-Path -LiteralPath $LogFolder -PathType Container)) {
        return @()
    }

    $cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)

    $patterns = @(
        [pscustomobject]@{
            Name     = 'existingConnection'
            Pattern  = 'existingConnection'
            Severity = 'ERROR'
        }
        [pscustomobject]@{
            Name     = 'Login failed'
            Pattern  = 'Login failed'
            Severity = 'ERROR'
        }
        [pscustomobject]@{
            Name     = 'NullReferenceException'
            Pattern  = 'NullReferenceException'
            Severity = 'ERROR'
        }
        [pscustomobject]@{
            Name     = 'AggregateException'
            Pattern  = 'AggregateException'
            Severity = 'ERROR'
        }
        [pscustomobject]@{
            Name     = 'DBError'
            Pattern  = 'DBError'
            Severity = 'ERROR'
        }
        [pscustomobject]@{
            Name     = 'ErrorNo='
            Pattern  = 'ErrorNo='
            Severity = 'ERROR'
        }
        [pscustomobject]@{
            Name     = 'Timeout'
            Pattern  = 'Timeout'
            Severity = 'WARNING'
        }
        [pscustomobject]@{
            Name     = 'OPOS'
            Pattern  = 'OPOS'
            Severity = 'WARNING'
        }
        [pscustomobject]@{
            Name     = 'Printer'
            Pattern  = 'Printer'
            Severity = 'WARNING'
        }
        [pscustomobject]@{
            Name     = 'SeatAllocation'
            Pattern  = 'SeatAllocation'
            Severity = 'WARNING'
        }
        [pscustomobject]@{
            Name     = 'fiskaltrust'
            Pattern  = 'fiskaltrust'
            Severity = 'WARNING'
        }
        [pscustomobject]@{
            Name     = 'card receipt not found'
            Pattern  = 'card receipt not found'
            Severity = 'WARNING'
        }
    )

    $logFiles = @(
        Get-ChildItem -LiteralPath $LogFolder -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.LastWriteTime -ge $cutoffDate -and
                $_.Extension -in @('.log', '.txt') -and
                $_.Name -notlike 'UPGRADE_*' -and
                $_.Name -notlike '*InstallLog*' -and
                $_.Name -notlike '*Setup_Install*'
            }
    )

    if ($logFiles.Count -eq 0) {
        return @()
    }

    $results = foreach ($patternDefinition in $patterns) {
        $matches = @(
            $logFiles |
                Select-String `
                    -Pattern $patternDefinition.Pattern `
                    -SimpleMatch `
                    -ErrorAction SilentlyContinue
        )

        if ($matches.Count -gt 0) {
            $firstMatch = $matches |
                Sort-Object Path, LineNumber |
                Select-Object -First 1

            $lastMatch = $matches |
                Sort-Object Path, LineNumber |
                Select-Object -Last 1

            [pscustomobject]@{
                Pattern         = $patternDefinition.Name
                Severity        = $patternDefinition.Severity
                Count           = $matches.Count
                FirstPath       = $firstMatch.Path
                FirstLineNumber = $firstMatch.LineNumber
                FirstLine       = $firstMatch.Line.Trim()
                LastPath        = $lastMatch.Path
                LastLineNumber  = $lastMatch.LineNumber
                FilesChecked    = $logFiles.Count
                MaxAgeDays      = $MaxAgeDays
            }
        }
    }

    return @(
        $results |
            Sort-Object `
                @{ Expression = {
                    switch ($_.Severity) {
                        'ERROR'   { 1 }
                        'WARNING' { 2 }
                        default   { 3 }
                    }
                }},
                @{ Expression = 'Count'; Descending = $true }
    )
}

Export-ModuleMember -Function 'Get-CDSVistaLogSummary'