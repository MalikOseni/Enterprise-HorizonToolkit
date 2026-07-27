#Requires -Version 5.1

<#
.SYNOPSIS
    Returns the active VMware Horizon Services object.

.DESCRIPTION
    Retrieves the cached VMware.Hv.Services object created by
    Connect-Horizon.

    All toolkit cmdlets should call this function instead of
    referencing $global:DefaultHVServers directly.

.NOTES

Project : Enterprise-HorizonToolkit
Author  : Malik Oseni
Version : 1.0.0

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HorizonService {

    [CmdletBinding()]
    [OutputType([VMware.Hv.Services])]

    param()

    try {

        Write-Verbose 'Retrieving Horizon Services object.'

        if (-not $script:Toolkit) {

            throw 'Toolkit has not been initialised.'

        }

        if (-not $script:Toolkit.Connection) {

            throw 'No active Horizon connection exists. Run Connect-Horizon first.'

        }

        if (-not $script:Toolkit.Connection.IsConnected) {

            throw 'Cached Horizon connection is no longer connected.'

        }

        if (-not $script:Toolkit.Services) {

            throw 'Cached VMware.Hv.Services object is missing.'

        }

        Write-HorizonLog `
            -Message 'VMware.Hv.Services object returned.' `
            -Level Information

        return $script:Toolkit.Services

    }
    catch {

        Write-HorizonLog `
            -Message $_.Exception.Message `
            -Level Error

        throw

    }

}