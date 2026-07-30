Set-StrictMode -Version Latest

$script:Config = $null
$script:ConfigPath = $null

function Test-CDSConfigFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Die Konfigurationsdatei wurde nicht gefunden: $Path"
    }
}

function Read-CDSConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Test-CDSConfigFile -Path $Path

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        return $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Die Konfigurationsdatei konnte nicht gelesen werden: $($_.Exception.Message)"
    }
}

function Test-CDSConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Configuration
    )

    $requiredProperties = @(
        'Version',
        'LogFolder',
        'SnapshotFolder',
        'PollingInterval',
        'KeepLogsDays',
        'KeepSnapshots',
        'LogLevel',
        'ServicesToWatch',
        'EventLogs'
    )

    foreach ($propertyName in $requiredProperties) {
        if ($null -eq $Configuration.PSObject.Properties[$propertyName]) {
            throw "Die Pflichtkonfiguration '$propertyName' fehlt."
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$Configuration.LogFolder)) {
        throw 'LogFolder darf nicht leer sein.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$Configuration.SnapshotFolder)) {
        throw 'SnapshotFolder darf nicht leer sein.'
    }

    if ([int]$Configuration.PollingInterval -lt 5) {
        throw 'PollingInterval muss mindestens 5 Sekunden betragen.'
    }

    if ([int]$Configuration.KeepLogsDays -lt 1) {
        throw 'KeepLogsDays muss mindestens 1 betragen.'
    }

    if ([int]$Configuration.KeepSnapshots -lt 1) {
        throw 'KeepSnapshots muss mindestens 1 betragen.'
    }

    $validLevels = @('DEBUG', 'INFO', 'WARN', 'ERROR')
    if ($validLevels -notcontains ([string]$Configuration.LogLevel).ToUpperInvariant()) {
        throw "LogLevel muss einen dieser Werte besitzen: $($validLevels -join ', ')"
    }

    return $true
}

function Initialize-CDSConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $configuration = Read-CDSConfig -Path $resolvedPath
    [void](Test-CDSConfiguration -Configuration $configuration)

    $script:Config = $configuration
    $script:ConfigPath = $resolvedPath

    return $script:Config
}

function Get-CDSConfig {
    [CmdletBinding()]
    param()

    if ($null -eq $script:Config) {
        throw 'Die CDS-Konfiguration wurde noch nicht initialisiert.'
    }

    return $script:Config
}

function Reload-CDSConfig {
    [CmdletBinding()]
    param()

    if ([string]::IsNullOrWhiteSpace($script:ConfigPath)) {
        throw 'Die CDS-Konfiguration wurde noch nicht initialisiert.'
    }

    return Initialize-CDSConfig -Path $script:ConfigPath
}

function Test-CDSConfig {
    [CmdletBinding()]
    param(
        [string]$Path
    )

    try {
        if ($Path) {
            $configuration = Read-CDSConfig -Path $Path
        }
        else {
            $configuration = Get-CDSConfig
        }

        [void](Test-CDSConfiguration -Configuration $configuration)

        [pscustomobject]@{
            Success = $true
            Message = 'Die Konfiguration ist gültig.'
            Path    = if ($Path) { $Path } else { $script:ConfigPath }
        }
    }
    catch {
        [pscustomobject]@{
            Success = $false
            Message = $_.Exception.Message
            Path    = if ($Path) { $Path } else { $script:ConfigPath }
        }
    }
}

Export-ModuleMember -Function @(
    'Initialize-CDSConfig',
    'Get-CDSConfig',
    'Reload-CDSConfig',
    'Test-CDSConfig'
)
