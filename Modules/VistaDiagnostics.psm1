Set-StrictMode -Version Latest

function Get-CDSVistaFileInformation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VistaPath
    )

    $targetFiles = @(
        'visCommon.dll',
        'visData.dll',
        'visPOS.exe',
        'VistaPOS.ini'
    )

    $files = @(
        Get-ChildItem -LiteralPath $VistaPath -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -in $targetFiles
            } |
            ForEach-Object {
                $version = $null

                if ($_.Extension -in @('.dll', '.exe')) {
                    $version = $_.VersionInfo.FileVersion
                }

                [pscustomobject]@{
                    Name         = $_.Name
                    FullName     = $_.FullName
                    RelativePath = $_.FullName.Substring($VistaPath.Length).TrimStart('\')
                    Version      = $version
                    SizeBytes    = $_.Length
                    LastWriteTime = $_.LastWriteTime
                }
            }
    )

    return $files
}

function Get-CDSVistaInstallationType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VistaPath,

        [Parameter(Mandatory)]
        [object[]]$Files
    )

    $hasHeadOffice = Test-Path -LiteralPath (Join-Path $VistaPath 'HeadOffice')
    $hasHO         = Test-Path -LiteralPath (Join-Path $VistaPath 'HO')
    $hasBO         = Test-Path -LiteralPath (Join-Path $VistaPath 'BO')
    $hasPOS        = @($Files | Where-Object { $_.Name -eq 'visPOS.exe' }).Count -gt 0

    if ($hasHeadOffice -or $hasHO) {
        return 'HeadOffice'
    }

    if ($hasPOS) {
        return 'POS'
    }

    if ($hasBO) {
        return 'BackOffice'
    }

    return 'Unknown'
}

function Get-CDSVistaInformation {
    [CmdletBinding()]
    param()

    $vistaPaths = @(
        'C:\Vista',
        'F:\Vista',
        'G:\Vista'
    )

    $installPath = $null

    foreach ($path in $vistaPaths) {
        if (Test-Path -LiteralPath $path -PathType Container) {
            $installPath = $path
            break
        }
    }

    if ($null -eq $installPath) {
        return [pscustomobject]@{
            Installed       = $false
            InstallPath     = $null
            InstallationType = 'NotInstalled'
            Files           = @()
            Computer        = $env:COMPUTERNAME
            Checked         = Get-Date
        }
    }

    $files = @(Get-CDSVistaFileInformation -VistaPath $installPath)
    $installationType = Get-CDSVistaInstallationType `
        -VistaPath $installPath `
        -Files $files

    [pscustomobject]@{
        Installed        = $true
        InstallPath      = $installPath
        InstallationType = $installationType
        Files            = $files
        Computer         = $env:COMPUTERNAME
        Checked          = Get-Date
    }
}

Export-ModuleMember -Function @(
    'Get-CDSVistaInformation',
    'Get-CDSVistaFileInformation',
    'Get-CDSVistaInstallationType'
)