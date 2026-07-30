Set-StrictMode -Version Latest

function Get-CDSSafeCimInstance {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ClassName)

    try {
        return Get-CimInstance -ClassName $ClassName -ErrorAction Stop
    }
    catch {
        return $null
    }
}

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
    $computerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [Environment]::MachineName }
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

    $os = Get-CDSSafeCimInstance -ClassName 'Win32_OperatingSystem'
    $computer = Get-CDSSafeCimInstance -ClassName 'Win32_ComputerSystem'
    $printers = @(Get-CDSSafeCimInstance -ClassName 'Win32_Printer' |
        Select-Object Name, DriverName, PortName, PrinterStatus, WorkOffline, Default)

    $usbDevices = @()
    $pnpCommand = Get-Command -Name Get-PnpDevice -ErrorAction SilentlyContinue
    if ($null -ne $pnpCommand) {
        $usbDevices = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceId -like 'USB*' } |
            Select-Object Status, Class, FriendlyName, InstanceId)
    }
    else {
        $usbDevices = @(Get-CDSSafeCimInstance -ClassName 'Win32_PnPEntity' |
            Where-Object { $_.PNPDeviceID -like 'USB*' } |
            Select-Object @{Name='Status';Expression={$_.Status}},
                          @{Name='Class';Expression={$_.PNPClass}},
                          @{Name='FriendlyName';Expression={$_.Name}},
                          @{Name='InstanceId';Expression={$_.PNPDeviceID}})
    }

    $snapshot = [ordered]@{
        SchemaVersion = '1.0'
        CreatedAt     = (Get-Date).ToString('o')
        ComputerName  = $computerName
        UserName      = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        PowerShell    = $PSVersionTable.PSVersion.ToString()
        OperatingSystem = [ordered]@{
            Caption      = if ($os) { $os.Caption } else { $null }
            Version      = if ($os) { $os.Version } else { $null }
            BuildNumber  = if ($os) { $os.BuildNumber } else { $null }
            LastBootTime = if ($os) { $os.LastBootUpTime } else { $null }
        }
        Computer = [ordered]@{
            Manufacturer = if ($computer) { $computer.Manufacturer } else { $null }
            Model        = if ($computer) { $computer.Model } else { $null }
            TotalMemory  = if ($computer) { $computer.TotalPhysicalMemory } else { $null }
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
