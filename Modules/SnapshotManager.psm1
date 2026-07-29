Set-StrictMode -Version Latest

function New-CDSSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SnapshotFolder,
        [string[]]$ServicesToWatch = @(),
        [ValidateRange(1, 1000)][int]$KeepSnapshots = 20
    )

    if (-not (Test-Path -LiteralPath $SnapshotFolder -PathType Container)) {
        [void](New-Item -Path $SnapshotFolder -ItemType Directory -Force -ErrorAction Stop)
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $computerName = $env:COMPUTERNAME
    $snapshotPath = Join-Path $SnapshotFolder ("CDS_Snapshot_{0}_{1}.json" -f $computerName, $timestamp)

    $serviceData = foreach ($serviceName in $ServicesToWatch) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            [pscustomobject]@{ Name = $serviceName; Status = 'NOT FOUND'; DisplayName = $null }
        }
        else {
            [pscustomobject]@{ Name = $service.Name; Status = [string]$service.Status; DisplayName = $service.DisplayName }
        }
    }

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    $printers = Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue |
        Select-Object Name, DriverName, PortName, PrinterStatus, WorkOffline, Default
    $usbDevices = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -like 'USB*' } |
        Select-Object Status, Class, FriendlyName, InstanceId

    $snapshot = [ordered]@{
        SchemaVersion = '1.0'
        CreatedAt     = (Get-Date).ToString('o')
        ComputerName  = $computerName
        UserName      = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        PowerShell    = $PSVersionTable.PSVersion.ToString()
        OperatingSystem = [ordered]@{
            Caption      = $os.Caption
            Version      = $os.Version
            BuildNumber  = $os.BuildNumber
            LastBootTime = $os.LastBootUpTime
        }
        Computer = [ordered]@{
            Manufacturer = $computer.Manufacturer
            Model        = $computer.Model
            TotalMemory  = $computer.TotalPhysicalMemory
        }
        Services = @($serviceData)
        Printers = @($printers)
        USB      = @($usbDevices)
    }

    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8 -ErrorAction Stop

    $oldSnapshots = Get-ChildItem -LiteralPath $SnapshotFolder -Filter 'CDS_Snapshot_*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $KeepSnapshots

    foreach ($oldSnapshot in $oldSnapshots) {
        Remove-Item -LiteralPath $oldSnapshot.FullName -Force -ErrorAction SilentlyContinue
    }

    return $snapshotPath
}

Export-ModuleMember -Function 'New-CDSSnapshot'
