[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),
    [string]$DestinationPath = 'C:\Program Files\CinemaxX\DiagnosticsSuite',
    [switch]$CreateScheduledTask
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
    throw "Quellordner wurde nicht gefunden: $SourcePath"
}

if ($PSCmdlet.ShouldProcess($DestinationPath, 'CinemaxX Diagnostics Suite installieren')) {
    [void](New-Item -Path $DestinationPath -ItemType Directory -Force)

    $items = @('Config', 'Modules', 'Watcher', 'Start-CDS.ps1', 'README.md')
    foreach ($item in $items) {
        $sourceItem = Join-Path $SourcePath $item
        if (Test-Path -LiteralPath $sourceItem) {
            Copy-Item -LiteralPath $sourceItem -Destination $DestinationPath -Recurse -Force
        }
    }

    $runtimeRoot = 'C:\ProgramData\CinemaxX\Diagnostics'
    foreach ($folder in @('Logs', 'Snapshots', 'Reports')) {
        [void](New-Item -Path (Join-Path $runtimeRoot $folder) -ItemType Directory -Force)
    }

    if ($CreateScheduledTask) {
        $scriptPath = Join-Path $DestinationPath 'Start-CDS.ps1'
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $scriptPath)
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries

        Register-ScheduledTask -TaskName 'CinemaxX Diagnostics Suite' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    }

    Write-Host "Installation abgeschlossen: $DestinationPath" -ForegroundColor Green
}
