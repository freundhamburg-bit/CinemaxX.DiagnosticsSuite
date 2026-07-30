Set-StrictMode -Version Latest

function Get-CDSVistaInformation {

    [CmdletBinding()]
    param()

    $vistaPaths = @(
        "C:\Vista",
        "F:\Vista",
        "G:\Vista"
    )

    $installed = $false
    $installPath = $null

    foreach ($path in $vistaPaths) {
        if (Test-Path $path) {
            $installed = $true
            $installPath = $path
            break
        }
    }

    [PSCustomObject]@{
        Installed = $installed
        InstallPath = $installPath
        Computer = $env:COMPUTERNAME
        Checked = Get-Date
    }
}

Export-ModuleMember -Function Get-CDSVistaInformation