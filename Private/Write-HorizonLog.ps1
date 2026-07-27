#Requires -Version 5.1

<#
.SYNOPSIS
    Writes messages to the Enterprise Horizon Toolkit log.

.DESCRIPTION
    Provides a consistent logging interface for all toolkit cmdlets.

.NOTES
    Project : Enterprise-HorizonToolkit
    Author  : Malik Oseni
    Version : 1.0.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-HorizonLog {

    [CmdletBinding()]
    param(

        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet(
            'Information',
            'Warning',
            'Error',
            'Debug',
            'Verbose'
        )]
        [string]$Level = 'Information'

    )

    try {

        $ModuleRoot = Split-Path $PSScriptRoot -Parent
        $LoggingConfiguration = $null

        if ($script:Toolkit -and $script:Toolkit.Configuration) {
            $LoggingConfiguration = $script:Toolkit.Configuration.Logging
        }

        $LogFolder = if ($LoggingConfiguration -and $LoggingConfiguration.Path) {
            $LoggingConfiguration.Path
        }
        else {
            '.\\Logs'
        }

        if (-not [System.IO.Path]::IsPathRooted($LogFolder)) {
            $LogFolder = Join-Path $ModuleRoot $LogFolder
        }

        if (-not (Test-Path -LiteralPath $LogFolder)) {

            New-Item `
                -Path $LogFolder `
                -ItemType Directory `
                -Force | Out-Null

        }

        $LogFileName = if ($LoggingConfiguration -and $LoggingConfiguration.FileName) {
            $LoggingConfiguration.FileName
        }
        else {
            'Enterprise-HorizonToolkit.log'
        }
        $LogFile = Join-Path $LogFolder $LogFileName

        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        $Entry = "[{0}] [{1}] {2}" -f $Timestamp, $Level.ToUpper(), $Message

        Add-Content `
            -Path $LogFile `
            -Value $Entry

        switch ($Level) {

            'Information' {

                Write-Information $Message -InformationAction Continue

            }

            'Warning' {

                Write-Warning $Message

            }

            'Error' {

                # Preserve the original exception when logging from a catch
                # block under $ErrorActionPreference = 'Stop'.
                Write-Error $Message -ErrorAction Continue

            }

            'Debug' {

                Write-Debug $Message

            }

            'Verbose' {

                Write-Verbose $Message

            }

        }

    }
    catch {

        # A log-path failure must not hide the Horizon operation that failed.
        Write-Verbose "Unable to write Horizon log: $($_.Exception.Message)"

    }

}