Set-StrictMode -Version Latest

function Get-CDSVistaLogSummary {

    [CmdletBinding()]
    param(
        [string]$LogFolder = "C:\Vista\Log"
    )

    if (!(Test-Path $LogFolder)) {
        return $null
    }

    $patterns = @(
        "existingConnection",
        "Login failed",
        "NullReferenceException",
        "AggregateException",
        "Stack Trace",
        "ErrorNo=",
        "DBError",
        "OPOS",
        "Printer",
        "SeatAllocation",
        "Timeout",
        "fiskaltrust",
        "card receipt not found"
    )

    $results = @()

    foreach ($pattern in $patterns) {

        $matches = Get-ChildItem $LogFolder -Filter *.log -Recurse -ErrorAction SilentlyContinue |
            Select-String -Pattern $pattern

        if ($matches) {

            $results += [PSCustomObject]@{
                Pattern = $pattern
                Count   = $matches.Count
                First   = $matches[0].Path
            }

        }
    }

    return $results
}

Export-ModuleMember -Function Get-CDSVistaLogSummary