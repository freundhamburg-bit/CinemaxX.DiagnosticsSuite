Set-StrictMode -Version Latest

function Get-CDSPrinterStatusText {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$PrinterStatus
    )

    $statusMap = @{
        1 = 'Other'
        2 = 'Unknown'
        3 = 'Idle'
        4 = 'Printing'
        5 = 'Warmup'
        6 = 'Stopped Printing'
        7 = 'Offline'
    }

    $numericStatus = 0
    if ($null -ne $PrinterStatus -and [int]::TryParse([string]$PrinterStatus, [ref]$numericStatus)) {
        if ($statusMap.ContainsKey($numericStatus)) {
            return $statusMap[$numericStatus]
        }
    }

    return 'Unknown'
}

function Get-CDSPrintJobs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PrinterName
    )

    try {
        $escapedName = $PrinterName.Replace("'", "''")
        return @(
            Get-CimInstance -ClassName Win32_PrintJob -Filter "Name LIKE '$escapedName,%'" -ErrorAction Stop |
                Select-Object Name, Document, JobId, JobStatus, Owner, TotalPages, PagesPrinted, Size, TimeSubmitted
        )
    }
    catch {
        return @()
    }
}

function Get-CDSPrinterDiagnostics {
    [CmdletBinding()]
    param(
        [string[]]$Name,
        [switch]$IncludePrintJobs
    )

    $spooler = Get-Service -Name 'Spooler' -ErrorAction SilentlyContinue
    $spoolerRunning = $null -ne $spooler -and $spooler.Status -eq 'Running'

    try {
        $printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop)
    }
    catch {
        return [pscustomobject]@{
            Component      = 'PrinterDiagnostics'
            Status         = 'Error'
            Severity       = 'Error'
            Healthy        = $false
            Recommendation = 'Windows-Druckerverwaltung und WMI/CIM prüfen.'
            Message        = "Druckerdaten konnten nicht gelesen werden: $($_.Exception.Message)"
            SpoolerStatus  = if ($null -eq $spooler) { 'NOT FOUND' } else { [string]$spooler.Status }
            Printers       = @()
            CheckedAt      = Get-Date
        }
    }

    $namePatterns = @($Name | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($namePatterns.Count -gt 0) {
        $printers = @($printers | Where-Object {
            $printerName = [string]$_.Name
            foreach ($pattern in $namePatterns) {
                if ($printerName -like $pattern) {
                    return $true
                }
            }
            return $false
        })
    }

    $printerResults = @(foreach ($printer in $printers) {
        $queueJobs = if ($IncludePrintJobs) {
            @(Get-CDSPrintJobs -PrinterName ([string]$printer.Name))
        }
        else {
            @()
        }

        $problemReasons = [System.Collections.Generic.List[string]]::new()

        if (-not $spoolerRunning) {
            [void]$problemReasons.Add('Spooler läuft nicht.')
        }
        if ([bool]$printer.WorkOffline) {
            [void]$problemReasons.Add('Drucker ist als offline markiert.')
        }
        if ([bool]$printer.ErrorCleared -eq $false -and [uint32]$printer.DetectedErrorState -gt 2) {
            [void]$problemReasons.Add("Erkannter Fehlerstatus: $($printer.DetectedErrorState)")
        }
        if ([uint32]$printer.PrinterStatus -eq 7) {
            [void]$problemReasons.Add('Druckerstatus ist Offline.')
        }
        if ([uint32]$printer.ExtendedPrinterStatus -in @(7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23)) {
            [void]$problemReasons.Add("Erweiterter Druckerstatus meldet ein Problem: $($printer.ExtendedPrinterStatus)")
        }

        $healthy = $problemReasons.Count -eq 0
        $recommendation = if ($healthy) {
            'Keine Maßnahme erforderlich.'
        }
        elseif (-not $spoolerRunning) {
            'Spooler-Dienst starten und anschließend Druckwarteschlange erneut prüfen.'
        }
        elseif ([bool]$printer.WorkOffline) {
            'Verbindung, Stromversorgung und die Windows-Einstellung „Drucker offline verwenden“ prüfen.'
        }
        else {
            'Druckwarteschlange, Anschluss, Treiber und Gerätestatus prüfen.'
        }

        [pscustomobject]@{
            Name               = [string]$printer.Name
            Default            = [bool]$printer.Default
            Network            = [bool]$printer.Network
            Shared             = [bool]$printer.Shared
            WorkOffline        = [bool]$printer.WorkOffline
            DriverName         = [string]$printer.DriverName
            PortName           = [string]$printer.PortName
            PrintProcessor     = [string]$printer.PrintProcessor
            PrinterStatusCode  = [uint32]$printer.PrinterStatus
            PrinterStatus      = Get-CDSPrinterStatusText -PrinterStatus $printer.PrinterStatus
            ExtendedStatusCode = [uint32]$printer.ExtendedPrinterStatus
            DetectedErrorState = [uint32]$printer.DetectedErrorState
            QueueLength        = @($queueJobs).Count
            PrintJobs          = @($queueJobs)
            Healthy            = $healthy
            Severity           = if ($healthy) { 'Info' } else { 'Warning' }
            Problems           = @($problemReasons)
            Recommendation     = $recommendation
        }
    })

    $unhealthyPrinters = @($printerResults | Where-Object { -not $_.Healthy })
    $overallHealthy = $spoolerRunning -and $unhealthyPrinters.Count -eq 0

    [pscustomobject]@{
        Component      = 'PrinterDiagnostics'
        Status         = if ($overallHealthy) { 'Healthy' } else { 'Warning' }
        Severity       = if ($overallHealthy) { 'Info' } else { 'Warning' }
        Healthy        = $overallHealthy
        Recommendation = if ($overallHealthy) { 'Keine Maßnahme erforderlich.' } else { 'Details der betroffenen Drucker prüfen.' }
        Message        = "$(@($printerResults).Count) Drucker geprüft; $($unhealthyPrinters.Count) mit Auffälligkeiten."
        SpoolerStatus  = if ($null -eq $spooler) { 'NOT FOUND' } else { [string]$spooler.Status }
        Printers       = @($printerResults)
        CheckedAt      = Get-Date
    }
}

function Test-CDSPrinterHealth {
    [CmdletBinding()]
    param(
        [string[]]$Name,
        [switch]$IncludePrintJobs
    )

    Get-CDSPrinterDiagnostics -Name $Name -IncludePrintJobs:$IncludePrintJobs
}

Export-ModuleMember -Function @(
    'Get-CDSPrinterDiagnostics',
    'Test-CDSPrinterHealth'
)
