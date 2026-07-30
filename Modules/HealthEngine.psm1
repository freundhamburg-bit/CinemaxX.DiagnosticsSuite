Set-StrictMode -Version Latest

function New-CDSHealthCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('OK', 'WARNING', 'CRITICAL')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Recommendation = ''
    )

    [pscustomobject]@{
        Name           = $Name
        Status         = $Status
        Message        = $Message
        Recommendation = $Recommendation
    }
}

function Get-CDSHealthSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Checks
    )

    $criticalCount = @(
        $Checks | Where-Object { $_.Status -eq 'CRITICAL' }
    ).Count

    $warningCount = @(
        $Checks | Where-Object { $_.Status -eq 'WARNING' }
    ).Count

    $okCount = @(
        $Checks | Where-Object { $_.Status -eq 'OK' }
    ).Count

    $overallStatus = if ($criticalCount -gt 0) {
        'CRITICAL'
    }
    elseif ($warningCount -gt 0) {
        'WARNING'
    }
    else {
        'HEALTHY'
    }

    [pscustomobject]@{
        OverallStatus = $overallStatus
        TotalChecks   = $Checks.Count
        OkCount       = $okCount
        WarningCount  = $warningCount
        CriticalCount = $criticalCount
        Checks        = $Checks
        Checked       = Get-Date
    }
}

Export-ModuleMember -Function @(
    'New-CDSHealthCheck',
    'Get-CDSHealthSummary'
)