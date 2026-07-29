Set-StrictMode -Version Latest

$script:LoggerInitialized = $false
$script:LogFolder = $null
$script:LogFile = $null
$script:MinimumLevel = 'INFO'

function Get-CDSLevelValue {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Level)

    switch ($Level.ToUpperInvariant()) {
        'DEBUG' { return 10 }
        'INFO'  { return 20 }
        'WARN'  { return 30 }
        'ERROR' { return 40 }
        default { throw "Ungültiger LogLevel: $Level" }
    }
}

function Get-CDSLogFile {
    [CmdletBinding()]
    param()

    if ([string]::IsNullOrWhiteSpace($script:LogFolder)) {
        throw 'Der Logger wurde noch nicht initialisiert.'
    }

    return Join-Path $script:LogFolder ("CDS_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))
}

function Initialize-CDSLogger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LogFolder,
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')][string]$MinimumLevel = 'INFO'
    )

    try {
        if (-not (Test-Path -LiteralPath $LogFolder -PathType Container)) {
            [void](New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop)
        }

        $script:LogFolder = (Resolve-Path -LiteralPath $LogFolder -ErrorAction Stop).Path
        $script:MinimumLevel = $MinimumLevel.ToUpperInvariant()
        $script:LogFile = Get-CDSLogFile

        if (-not (Test-Path -LiteralPath $script:LogFile -PathType Leaf)) {
            [void](New-Item -Path $script:LogFile -ItemType File -Force -ErrorAction Stop)
        }

        $script:LoggerInitialized = $true
        return $script:LogFile
    }
    catch {
        $script:LoggerInitialized = $false
        throw "Der Logger konnte nicht initialisiert werden: $($_.Exception.Message)"
    }
}

function Write-CDSLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [string]$Component = 'Core'
    )

    if (-not $script:LoggerInitialized) {
        throw 'Der Logger wurde noch nicht initialisiert.'
    }

    if ((Get-CDSLevelValue -Level $Level) -lt (Get-CDSLevelValue -Level $script:MinimumLevel)) {
        return
    }

    $currentFile = Get-CDSLogFile
    if ($currentFile -ne $script:LogFile) {
        $script:LogFile = $currentFile
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            [void](New-Item -Path $script:LogFile -ItemType File -Force)
        }
    }

    $safeMessage = $Message -replace "`r?`n", ' '
    $line = '{0}|{1}|{2}|{3}' -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffK'), $Level.ToUpperInvariant(), $Component, $safeMessage
    Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction Stop
}

function Get-CDSCurrentLogFile {
    [CmdletBinding()]
    param()

    if (-not $script:LoggerInitialized) {
        throw 'Der Logger wurde noch nicht initialisiert.'
    }

    return $script:LogFile
}

function Test-CDSLogger {
    [CmdletBinding()]
    param()

    try {
        Write-CDSLog -Message 'Logger-Selbsttest erfolgreich.' -Level DEBUG -Component 'Logger'
        [pscustomobject]@{ Success = $true; LogFile = $script:LogFile; Message = 'Logger ist einsatzbereit.' }
    }
    catch {
        [pscustomobject]@{ Success = $false; LogFile = $script:LogFile; Message = $_.Exception.Message }
    }
}

function Clear-CDSOldLogs {
    [CmdletBinding()]
    param([ValidateRange(1, 3650)][int]$KeepDays = 30)

    if (-not $script:LoggerInitialized) {
        throw 'Der Logger wurde noch nicht initialisiert.'
    }

    $limit = (Get-Date).AddDays(-$KeepDays)
    $files = Get-ChildItem -LiteralPath $script:LogFolder -Filter 'CDS_*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $limit }

    foreach ($file in $files) {
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
    }

    return @($files).Count
}

Export-ModuleMember -Function @(
    'Initialize-CDSLogger',
    'Write-CDSLog',
    'Get-CDSCurrentLogFile',
    'Test-CDSLogger',
    'Clear-CDSOldLogs'
)
