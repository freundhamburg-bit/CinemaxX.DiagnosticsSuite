Set-StrictMode -Version Latest

function Get-CDSServiceStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Name
    )

    foreach ($serviceName in $Name) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

        if ($null -eq $service) {
            [pscustomobject]@{
                Name        = $serviceName
                DisplayName = $null
                Status      = 'NOT FOUND'
                StartType   = $null
                Exists      = $false
                Timestamp   = Get-Date
            }
            continue
        }

        $startType = $null
        try {
            $cimService = Get-CimInstance -ClassName Win32_Service -Filter ("Name='{0}'" -f ($serviceName -replace "'", "''")) -ErrorAction Stop
            $startType = $cimService.StartMode
        }
        catch {
            $startType = 'Unknown'
        }

        [pscustomobject]@{
            Name        = $service.Name
            DisplayName = $service.DisplayName
            Status      = [string]$service.Status
            StartType   = $startType
            Exists      = $true
            Timestamp   = Get-Date
        }
    }
}

function Test-CDSServices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Name
    )

    $results = @(Get-CDSServiceStatus -Name $Name)

    foreach ($result in $results) {
        $healthy = $result.Exists -and $result.Status -eq 'Running'
        [pscustomobject]@{
            Name      = $result.Name
            Status    = $result.Status
            StartType = $result.StartType
            Healthy   = $healthy
            Message   = if (-not $result.Exists) {
                'Dienst wurde nicht gefunden.'
            }
            elseif (-not $healthy) {
                'Dienst ist nicht gestartet.'
            }
            else {
                'Dienst läuft.'
            }
            Timestamp = $result.Timestamp
        }
    }
}

Export-ModuleMember -Function @(
    'Get-CDSServiceStatus',
    'Test-CDSServices'
)
