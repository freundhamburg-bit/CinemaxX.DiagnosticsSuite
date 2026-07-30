Set-StrictMode -Version Latest

function Get-CDSComputerProfile {
    [CmdletBinding()]
    param(
        [ValidateSet('Auto', 'Laptop', 'POS', 'Server')]
        [string]$Profile = 'Auto'
    )

    if ($Profile -ne 'Auto') {
        return [pscustomobject]@{
            Name         = $Profile
            Detection    = 'Configured'
            Manufacturer = $null
            Model        = $null
            ComputerName = $env:COMPUTERNAME
        }
    }

    $computerSystem = $null
    $operatingSystem = $null
    $enclosure = $null

    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    }
    catch {
        # Detection continues with the remaining signals.
    }

    try {
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    }
    catch {
        # Detection continues with the remaining signals.
    }

    try {
        $enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction Stop
    }
    catch {
        # Detection continues with the remaining signals.
    }

    $manufacturer = if ($null -ne $computerSystem) { [string]$computerSystem.Manufacturer } else { '' }
    $model = if ($null -ne $computerSystem) { [string]$computerSystem.Model } else { '' }
    $productType = if ($null -ne $operatingSystem) { [int]$operatingSystem.ProductType } else { 1 }
    $chassisTypes = if ($null -ne $enclosure) { @($enclosure.ChassisTypes | ForEach-Object { [int]$_ }) } else { @() }

    $isLaptopChassis = @($chassisTypes | Where-Object { $_ -in @(8, 9, 10, 14, 18, 21, 30, 31, 32) }).Count -gt 0
    $isAuresHardware = $manufacturer -match '(?i)AURES' -or $model -match '(?i)YUNO|SANGO|NINO|JAZZ|TWIST'
    $hasVistaInstallation = (Test-Path -LiteralPath 'F:\Vista' -PathType Container) -or (Test-Path -LiteralPath 'C:\Vista' -PathType Container)

    if ($productType -ne 1) {
        $profileName = 'Server'
        $detection = 'Windows ProductType'
    }
    elseif ($isAuresHardware) {
        $profileName = 'POS'
        $detection = 'Aures manufacturer or POS model'
    }
    elseif ($isLaptopChassis) {
        $profileName = 'Laptop'
        $detection = if ($hasVistaInstallation) {
            'Laptop chassis; Vista installation ignored as non-exclusive signal'
        }
        else {
            'System chassis type'
        }
    }
    elseif ($hasVistaInstallation) {
        $profileName = 'POS'
        $detection = 'Vista installation on workstation hardware'
    }
    else {
        $profileName = 'Laptop'
        $detection = 'Workstation fallback'
    }

    [pscustomobject]@{
        Name         = $profileName
        Detection    = $detection
        Manufacturer = $manufacturer
        Model        = $model
        ComputerName = $env:COMPUTERNAME
    }
}

function Get-CDSProfileServices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Laptop', 'POS', 'Server')]
        [string]$Profile,

        [Parameter(Mandatory)]
        [object]$Config
    )

    if ($Config.PSObject.Properties.Name -contains 'ServiceProfiles') {
        $profileProperty = $Config.ServiceProfiles.PSObject.Properties[$Profile]
        if ($null -ne $profileProperty) {
            return @($profileProperty.Value)
        }
    }

    return @($Config.ServicesToWatch)
}

Export-ModuleMember -Function @(
    'Get-CDSComputerProfile',
    'Get-CDSProfileServices'
)
