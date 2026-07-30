<#
===============================================================================

Enterprise-HorizonToolkit.psm1

Author      : Malik Oseni
Project     : Enterprise-HorizonToolkit
Version     : 1.0.0

Description
-----------
Root module loader for the Enterprise Horizon Toolkit.

Responsibilities
----------------
- Import configuration
- Load private functions
- Load public functions
- Initialise module state
- Export public cmdlets

===============================================================================
#>

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {

    ###########################################################################
    # Module Root
    ###########################################################################

    $script:ModuleRoot = Split-Path -Parent $PSCommandPath

    ###########################################################################
    # Module State
    ###########################################################################

    $script:Toolkit = [PSCustomObject]@{

        Version         = '1.2.0'

        ModuleRoot      = $script:ModuleRoot

        Configuration   = $null

        Connection      = $null

        Services        = $null

        ConnectedServer = $null

        ConnectedAt     = $null

        Loaded          = $false

    }

    ###########################################################################
    # Load Private Functions
    ###########################################################################

    Get-ChildItem `
        -Path (Join-Path $script:ModuleRoot 'Private') `
        -Filter '*.ps1' `
        -File |
    Sort-Object Name |
    ForEach-Object {

        Write-Verbose "Loading private function [$($_.BaseName)]"

        . $_.FullName

    }

    ###########################################################################
    # Load Public Functions
    ###########################################################################

    Get-ChildItem `
        -Path (Join-Path $script:ModuleRoot 'Public') `
        -Filter '*.ps1' `
        -File |
    Sort-Object Name |
    ForEach-Object {

        Write-Verbose "Loading public function [$($_.BaseName)]"

        . $_.FullName

    }

    ###########################################################################
    # Load Configuration
    ###########################################################################

    $script:Toolkit.Configuration = Import-HorizonConfiguration

    ###########################################################################
    # Module Ready
    ###########################################################################

    $script:Toolkit.Loaded = $true

    Write-Verbose "Enterprise-HorizonToolkit initialised successfully."

    ###########################################################################
    # Export Public Cmdlets
    ###########################################################################

    $PublicFunctions = Get-ChildItem `
        -Path (Join-Path $script:ModuleRoot 'Public') `
        -Filter '*.ps1' `
        -File |
    Select-Object -ExpandProperty BaseName

    Export-ModuleMember -Function ($PublicFunctions + 'Invoke-HorizonQuery')

}
catch {

    throw

}