[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'Config\Config.json'),
    [ValidateSet('Auto', 'Laptop', 'POS', 'Server')]
    [string]$Profile = 'Auto',
    [switch]$Continuous,
    [switch]$SkipSnapshot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleFolder = Join-Path $PSScriptRoot 'Modules'
$moduleFiles = @(
    'ConfigManager.psm1',
    'Logger.psm1',
    'ProfileManager.psm1',
    'ServiceWatcher.psm1',
    'SnapshotManager.psm1',
    'EventWatcher.psm1',
    'PrinterDiagnostics.psm1',
	'VistaDiagnostics.psm1',
	'VistaLogAnalyzer.psm1',
	'HealthEngine.psm1'
)

foreach ($moduleFile in $moduleFiles) {
    $modulePath = Join-Path $moduleFolder $moduleFile
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        throw "Erforderliches Modul fehlt: $modulePath"
    }

    Import-Module $modulePath -Force -DisableNameChecking -ErrorAction Stop
}

$config = Initialize-CDSConfig -Path $ConfigPath
$configuredProfile = if ($Profile -ne 'Auto') {
    $Profile
}
elseif ($config.PSObject.Properties.Name -contains 'Profile') {
    [string]$config.Profile
}
else {
    'Auto'
}

$computerProfile = Get-CDSComputerProfile -Profile $configuredProfile
$servicesToWatch = @(Get-CDSProfileServices -Profile $computerProfile.Name -Config $config)

$logFile = Initialize-CDSLogger -LogFolder $config.LogFolder -MinimumLevel $config.LogLevel
[void](Clear-CDSOldLogs -KeepDays ([int]$config.KeepLogsDays))

Write-CDSLog -Message "CinemaxX Diagnostics Suite $($config.Version) gestartet." -Component 'Startup'
Write-CDSLog -Message ("Profil {0} erkannt ({1}); Hersteller={2}; Modell={3}." -f $computerProfile.Name, $computerProfile.Detection, $computerProfile.Manufacturer, $computerProfile.Model) -Component 'ProfileManager'
Write-Host "CinemaxX Diagnostics Suite $($config.Version)" -ForegroundColor Cyan
Write-Host "Profil: $($computerProfile.Name)"
Write-Host "Logdatei: $logFile"
# Vista erkennen
$vista = Get-CDSVistaInformation

if ($vista.Installed) {
    Write-CDSLog `
        -Component 'VistaDiagnostics' `
        -Level INFO `
        -Message ("Vista gefunden unter {0}; Typ={1}; relevante Dateien={2}." -f `
            $vista.InstallPath,
            $vista.InstallationType,
            @($vista.Files).Count)

    foreach ($file in @($vista.Files)) {
        $versionText = if ([string]::IsNullOrWhiteSpace([string]$file.Version)) {
            'keine Dateiversion'
        }
        else {
            $file.Version
        }

        Write-CDSLog `
            -Component 'VistaDiagnostics' `
            -Level INFO `
            -Message ("Datei {0}; Version={1}; Pfad={2}" -f `
                $file.Name,
                $versionText,
                $file.FullName)
    }
}
else {
    Write-CDSLog `
        -Component 'VistaDiagnostics' `
        -Level INFO `
        -Message 'Vista wurde nicht gefunden.'
}

# Erst NACH dem vollständigen if/else-Block
$logSummary = @(Get-CDSVistaLogSummary -MaxAgeDays 7)

if ($logSummary.Count -eq 0) {
    Write-CDSLog `
        -Component 'VistaLogAnalyzer' `
        -Level INFO `
        -Message 'Keine relevanten Treffer in aktuellen Vista-Logs gefunden.'
}
else {
    foreach ($entry in $logSummary) {
        Write-CDSLog `
            -Component 'VistaLogAnalyzer' `
            -Level $entry.Severity `
            -Message ("{0}: {1} Treffer; Datei={2}; Zeile={3}; Text={4}" -f `
                $entry.Pattern,
                $entry.Count,
                $entry.FirstPath,
                $entry.FirstLineNumber,
                $entry.FirstLine)
    }
}
$healthChecks = @()

if ($vista.Installed) {
    $healthChecks += New-CDSHealthCheck `
        -Name 'Vista Installation' `
        -Status 'OK' `
        -Message ("Vista ist unter {0} installiert. Typ={1}" -f `
            $vista.InstallPath,
            $vista.InstallationType)
}
else {
    $healthChecks += New-CDSHealthCheck `
        -Name 'Vista Installation' `
        -Status 'CRITICAL' `
        -Message 'Vista wurde nicht gefunden.' `
        -Recommendation 'Vista-Installation und Installationspfad prüfen.'
}

$vistaErrorCount = @(
    $logSummary | Where-Object { $_.Severity -eq 'ERROR' }
).Count

$vistaWarningCount = @(
    $logSummary | Where-Object { $_.Severity -eq 'WARNING' }
).Count

if ($vistaErrorCount -gt 0) {
    $healthChecks += New-CDSHealthCheck `
        -Name 'Vista Loganalyse' `
        -Status 'CRITICAL' `
        -Message ("Es wurden {0} kritische Fehlermuster gefunden." -f `
            $vistaErrorCount) `
        -Recommendation 'Aktuelle Vista-Logs und die gemeldeten Fundstellen prüfen.'
}
elseif ($vistaWarningCount -gt 0) {
    $healthChecks += New-CDSHealthCheck `
        -Name 'Vista Loganalyse' `
        -Status 'WARNING' `
        -Message ("Es wurden {0} Warnungsmuster gefunden." -f `
            $vistaWarningCount) `
        -Recommendation 'Warnungen prüfen und mit dem gemeldeten Programmverhalten vergleichen.'
}
else {
    $healthChecks += New-CDSHealthCheck `
        -Name 'Vista Loganalyse' `
        -Status 'OK' `
        -Message 'Keine relevanten Fehler in aktuellen Vista-Logs gefunden.'
}

$healthSummary = Get-CDSHealthSummary -Checks $healthChecks

Write-CDSLog `
    -Component 'HealthEngine' `
    -Level INFO `
    -Message ("Gesamtstatus={0}; Prüfungen={1}; OK={2}; Warnungen={3}; Kritisch={4}" -f `
        $healthSummary.OverallStatus,
        $healthSummary.TotalChecks,
        $healthSummary.OkCount,
        $healthSummary.WarningCount,
        $healthSummary.CriticalCount)

foreach ($check in $healthSummary.Checks) {
    $logLevel = switch ($check.Status) {
        'CRITICAL' { 'ERROR' }
        'WARNING'  { 'WARNING' }
        default    { 'INFO' }
    }

    Write-CDSLog `
        -Component 'HealthEngine' `
        -Level $logLevel `
        -Message ("{0}: Status={1}; {2}" -f `
            $check.Name,
            $check.Status,
            $check.Message)

    if (-not [string]::IsNullOrWhiteSpace($check.Recommendation)) {
        Write-CDSLog `
            -Component 'HealthEngine' `
            -Level INFO `
            -Message ("Empfehlung für {0}: {1}" -f `
                $check.Name,
                $check.Recommendation)
    }
}

function Invoke-CDSDiagnosticsCycle {
    [CmdletBinding()]
    param()

    $cycleStart = Get-Date
    Write-CDSLog -Message 'Diagnosezyklus gestartet.' -Level DEBUG -Component 'Core'

    if ([bool]$config.EnableServiceWatcher) {
        $serviceResults = @(Test-CDSServices -Name $servicesToWatch)
        foreach ($result in $serviceResults) {
            $level = if ($result.Healthy) { 'INFO' } else { 'WARN' }
            Write-CDSLog -Message ("Dienst {0}: {1} ({2})" -f $result.Name, $result.Status, $result.Message) -Level $level -Component 'ServiceWatcher'
        }
    }

    if ([bool]$config.EnablePrinterWatcher) {
        try {
            $printerDiagnostics = Test-CDSPrinterHealth -IncludePrintJobs
            $printerLevel = if ($printerDiagnostics.Healthy) { 'INFO' } else { 'WARN' }
            Write-CDSLog -Message $printerDiagnostics.Message -Level $printerLevel -Component 'PrinterDiagnostics'

            foreach ($printer in @($printerDiagnostics.Printers)) {
                $details = "Drucker '{0}': Status={1}, Offline={2}, Port={3}, Treiber={4}, Jobs={5}" -f `
                    $printer.Name,
                    $printer.PrinterStatus,
                    $printer.WorkOffline,
                    $printer.PortName,
                    $printer.DriverName,
                    $printer.QueueLength

                $level = if ($printer.Healthy) { 'INFO' } else { 'WARN' }
                Write-CDSLog -Message $details -Level $level -Component 'PrinterDiagnostics'

                foreach ($problem in @($printer.Problems)) {
                    Write-CDSLog -Message ("Drucker '{0}': {1}" -f $printer.Name, $problem) -Level WARN -Component 'PrinterDiagnostics'
                }
            }
        }
        catch {
            Write-CDSLog -Message "Druckerdiagnose fehlgeschlagen: $($_.Exception.Message)" -Level ERROR -Component 'PrinterDiagnostics'
        }
    }

    if ([bool]$config.EnableEventWatcher) {
        $events = @(Get-CDSRecentEvents -EventLogs @($config.EventLogs) -StartTime $cycleStart.AddSeconds(-[int]$config.PollingInterval))
        foreach ($event in $events) {
            $message = "{0}/{1} ID {2}: {3}" -f $event.LogName, $event.ProviderName, $event.Id, $event.Message
            Write-CDSLog -Message $message -Level WARN -Component 'EventWatcher'
        }
    }

    if (-not $SkipSnapshot) {
        try {
            $snapshotPath = New-CDSSnapshot -SnapshotFolder $config.SnapshotFolder -ServicesToWatch $servicesToWatch -KeepSnapshots ([int]$config.KeepSnapshots)
            Write-CDSLog -Message "Snapshot erstellt: $snapshotPath" -Level INFO -Component 'SnapshotManager'
        }
        catch {
            Write-CDSLog -Message "Snapshot konnte nicht erstellt werden: $($_.Exception.Message)" -Level ERROR -Component 'SnapshotManager'
        }
    }

    Write-CDSLog -Message 'Diagnosezyklus abgeschlossen.' -Level DEBUG -Component 'Core'
}

try {
    if ($Continuous) {
        Write-Host 'Dauerbetrieb aktiv. Abbruch mit STRG+C.' -ForegroundColor Yellow
        while ($true) {
            Invoke-CDSDiagnosticsCycle
            Start-Sleep -Seconds ([int]$config.PollingInterval)
        }
    }
    else {
        Invoke-CDSDiagnosticsCycle
        Write-Host 'Diagnose erfolgreich abgeschlossen.' -ForegroundColor Green
    }
}
catch {
    try {
        Write-CDSLog -Message $_.Exception.Message -Level ERROR -Component 'Startup'
    }
    catch {
        # Logger may be unavailable; preserve the original exception.
    }

    Write-Error $_
    exit 1
}
