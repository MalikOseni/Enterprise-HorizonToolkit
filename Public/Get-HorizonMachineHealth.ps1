#Requires -Version 5.1

<#
.SYNOPSIS
    Retrieves VMware Horizon machine health information.

.DESCRIPTION
    Queries VMware Horizon for machine inventory and returns
    a simplified health object suitable for monitoring,
    reporting and troubleshooting.

.PARAMETER MachineName
    Filter by machine name.

.PARAMETER DesktopPool
    Filter by desktop pool.

.PARAMETER State
    Filter by Horizon machine state.

.EXAMPLE

Get-HorizonMachineHealth

.EXAMPLE

Get-HorizonMachineHealth -MachineName <MachineName>

.EXAMPLE

Get-HorizonMachineHealth -DesktopPool Win11

.NOTES

Project : Enterprise-HorizonToolkit
Author  : Malik Oseni
Version : 1.0.0

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HorizonMachineHealth {

    [CmdletBinding()]

    [OutputType([PSCustomObject])]

    param(

        [Parameter()]
        [string]
        $MachineName,

        [Parameter()]
        [string]
        $DesktopPool,

        [Parameter()]
        [string]
        $State

    )

    begin {

        Write-HorizonLog `
            -Message 'Starting Get-HorizonMachineHealth.' `
            -Level Information

    }

    process {
        Write-Verbose 'Retrieving Horizon machine inventory.'

        $MachineResults = Invoke-HorizonQuery `
            -EntityType 'MachineSummaryView'
        Write-HorizonLog `
            -Message "$($MachineResults.Count) Horizon machine(s) retrieved." `
            -Level Information
        #
        # Apply filters
        #

        if ($MachineName) {

            $MachineResults = $MachineResults | Where-Object {

                $_.base.name -match [regex]::Escape($MachineName)

            }

        }

        if ($DesktopPool) {

            $MachineResults = $MachineResults | Where-Object {

                $_.base.desktopName -match [regex]::Escape($DesktopPool)

            }

        }

        if ($State) {

            $MachineResults = $MachineResults | Where-Object {

                $_.base.basicState -eq $State

            }

        }

        Write-HorizonLog `
            -Message "$($MachineResults.Count) machine(s) remain after filtering." `
            -Level Information

        Write-Verbose "$($MachineResults.Count) machine(s) remain after filtering."        #
        # Build Enterprise Machine Health Objects
        #

        foreach ($Machine in $MachineResults) {

            $Base = $Machine.Base

            #
            # Default health
            #

            $HealthStatus = 'Healthy'
            $HealthReason = 'Machine operating normally.'

            #
            # Determine health based on Horizon state
            #

            switch ($Base.BasicState) {

                'AVAILABLE' {

                    $HealthStatus = 'Healthy'
                    $HealthReason = 'Machine available for user assignment.'

                }

                'CONNECTED' {

                    $HealthStatus = 'Healthy'
                    $HealthReason = 'Machine currently has an active user session.'

                }

                'MAINTENANCE' {

                    $HealthStatus = 'Warning'
                    $HealthReason = 'Machine is in maintenance mode.'

                }

                'PROVISIONING' {

                    $HealthStatus = 'Warning'
                    $HealthReason = 'Machine is currently provisioning.'

                }

                'CUSTOMIZING' {

                    $HealthStatus = 'Warning'
                    $HealthReason = 'Machine customization is in progress.'

                }

                'DELETING' {

                    $HealthStatus = 'Warning'
                    $HealthReason = 'Machine is being deleted.'

                }

                'ERROR' {

                    $HealthStatus = 'Critical'
                    $HealthReason = 'Machine is reporting an error state.'

                }

                'AGENT_UNREACHABLE' {

                    $HealthStatus = 'Critical'
                    $HealthReason = 'The Horizon Agent is unreachable.'

                }

                default {

                    $HealthStatus = 'Unknown'
                    $HealthReason = "Unhandled Horizon state: $($Base.BasicState)"

                }

            }

            #
            # Return enterprise object
            #

            [PSCustomObject]@{

                PSTypeName      = 'Enterprise.Horizon.MachineHealth'

                MachineName     = $Base.Name

                DesktopPool     = $Base.DesktopName

                DNSName         = $Base.DnsName

                MachineState    = $Base.BasicState

                HealthStatus    = $HealthStatus

                HealthReason    = $HealthReason

                AgentVersion    = $Base.AgentVersion

                OperatingSystem = $Base.OperatingSystem

            }

        }

        Write-HorizonLog `
            -Message "$($MachineResults.Count) machine health object(s) returned." `
            -Level Information

        Write-Verbose 'Returning machine health objects.'

    }

    end {

        Write-HorizonLog `
            -Message 'Get-HorizonMachineHealth completed successfully.' `
            -Level Information

        Write-Verbose 'Get-HorizonMachineHealth completed.'

    }

}