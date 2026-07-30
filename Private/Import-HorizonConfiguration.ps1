#Requires -Version 5.1

<#
.SYNOPSIS
    Imports the Enterprise Horizon Toolkit configuration.

.DESCRIPTION
    Loads ToolkitConfig.psd1 (or ToolkitConfig.local.psd1 if present)
    and validates that all required configuration sections are present.

    Returns $null with a clear warning when no configuration file exists,
    allowing the module to load cleanly in CI and on fresh installs.
    Cmdlets that require configuration must check for $null and throw a
    descriptive error themselves.

.OUTPUTS
    Hashtable â€” populated configuration, or $null if no file is found.

.NOTES
    Project : Enterprise-HorizonToolkit
    Author  : Malik Oseni
    Version : 1.1.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-HorizonConfiguration {

    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $ModuleRoot = Split-Path $PSScriptRoot -Parent

    $ConfigurationFile = Join-Path $ModuleRoot 'Config\ToolkitConfig.psd1'
    $LocalConfigurationFile = Join-Path $ModuleRoot 'Config\ToolkitConfig.local.psd1'

    # Prefer the local override if present
    if (Test-Path -LiteralPath $LocalConfigurationFile) {
        $ConfigurationFile = $LocalConfigurationFile
    }

    # No config found â€” return null with actionable guidance rather than throwing.
    # This allows the module to import cleanly in CI and on fresh installs.
    # Cmdlets that need config must call Test-HorizonConfiguration before proceeding.
    if (-not (Test-Path -LiteralPath $ConfigurationFile)) {

        $ExampleFile = Join-Path $ModuleRoot 'Config\ToolkitConfig.example.psd1'

        Write-Warning "Enterprise-HorizonToolkit: No configuration file found."
        Write-Warning "Expected: $ConfigurationFile"
        Write-Warning "To configure: Copy-Item '$ExampleFile' '$ConfigurationFile'"
        Write-Warning "Then populate it with your Horizon environment values."

        return $null

    }

    try {

        $Configuration = Import-PowerShellDataFile -Path $ConfigurationFile

    }
    catch {
        throw "Failed to read configuration file '$ConfigurationFile': $($_.Exception.Message)"
    }

    ##############################################################
    # Validate required top-level sections
    ##############################################################

    $RequiredSections = @(
        'Horizon'
        'Session'
        'Logging'
        'Reporting'
        'Exclusions'
    )

    foreach ($Section in $RequiredSections) {

        if (-not $Configuration.ContainsKey($Section)) {
            throw "Configuration validation failed: missing required section [$Section] in '$ConfigurationFile'."
        }

    }

    ##############################################################
    # Validate Horizon section
    ##############################################################

    if (-not $Configuration.Horizon.ConnectionServers) {
        throw "Configuration validation failed: Horizon.ConnectionServers cannot be empty."
    }

    if ([string]::IsNullOrWhiteSpace($Configuration.Horizon.DefaultConnectionServer)) {
        throw "Configuration validation failed: Horizon.DefaultConnectionServer is missing or empty."
    }

    # CredentialPath is optional â€” Windows DPAPI-protected XML created under
    # the service account. Connect-Horizon prompts interactively when absent.
    if (-not $Configuration.Horizon.ContainsKey('CredentialPath')) {
        $Configuration.Horizon.CredentialPath = $null
    }

    return $Configuration

}