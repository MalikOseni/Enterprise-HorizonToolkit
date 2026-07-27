#Requires -Version 5.1

<#
.SYNOPSIS
    Imports the Enterprise Horizon Toolkit configuration.

.DESCRIPTION
    Loads the ToolkitConfig.psd1 configuration file and validates
    that all required configuration sections are present.

.OUTPUTS
    Hashtable

.NOTES
    Project : Enterprise-HorizonToolkit
    Author  : Malik Oseni
    Version : 1.0.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-HorizonConfiguration {

    [CmdletBinding()]
    param()

    try {

        $ModuleRoot = Split-Path $PSScriptRoot -Parent

        $ConfigurationFile = Join-Path `
            $ModuleRoot `
            'Config\ToolkitConfig.psd1'

        $LocalConfigurationFile = Join-Path `
            $ModuleRoot `
            'Config\ToolkitConfig.local.psd1'

        if (Test-Path -LiteralPath $LocalConfigurationFile) {

            $ConfigurationFile = $LocalConfigurationFile

        }

        if (-not (Test-Path -LiteralPath $ConfigurationFile)) {

            throw "Configuration file not found: $ConfigurationFile"

        }

        $Configuration = Import-PowerShellDataFile `
            -Path $ConfigurationFile

        $RequiredSections = @(
            'Horizon'
            'Session'
            'Logging'
            'Reporting'
            'Exclusions'
        )

        foreach ($Section in $RequiredSections) {

            if (-not $Configuration.ContainsKey($Section)) {

                throw "Missing configuration section [$Section]"

            }


        }
        ##############################################################
        # Validate Horizon Configuration
        ##############################################################

        if (-not $Configuration.Horizon.ConnectionServers) {

            throw "Configuration validation failed: Horizon.ConnectionServers cannot be empty."

        }

        if ([string]::IsNullOrWhiteSpace($Configuration.Horizon.DefaultConnectionServer)) {

            throw "Configuration validation failed: Horizon.DefaultConnectionServer is missing."

        }

        # CredentialPath is optional. A credential XML is protected with
        # Windows DPAPI and should not be copied between accounts or computers.
        # Connect-Horizon prompts when it is absent or cannot be decrypted.
        if (-not $Configuration.Horizon.ContainsKey('CredentialPath')) {

            $Configuration.Horizon.CredentialPath = $null

        }

        return $Configuration

    }
    catch {

        throw

    }

}