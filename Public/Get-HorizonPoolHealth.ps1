#Requires -Version 5.1

<#
.SYNOPSIS
    Returns VMware Horizon Desktop Pool health.

.DESCRIPTION
    Aggregates machine health information into
    desktop pool health summaries.

.PARAMETER DesktopPool
    Filter by desktop pool.

.EXAMPLE

Get-HorizonPoolHealth

.EXAMPLE

Get-HorizonPoolHealth -DesktopPool <DesktopPool>

.NOTES

Project : Enterprise-HorizonToolkit
Author  : Malik Oseni
Version : 1.0.0

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HorizonPoolHealth {

    [CmdletBinding()]

    [OutputType([PSCustomObject])]

    param(

        [Parameter()]
        [string]
        $DesktopPool

    )

    begin {

        Write-HorizonLog `
            -Message 'Starting Get-HorizonPoolHealth.' `
            -Level Information

    }

    process {

        Write-Verbose 'Retrieving machine health.'

        $Machines = Get-HorizonMachineHealth
        Write-HorizonLog `
            -Message "$($Machines.Count) machine health object(s) retrieved." `
            -Level Information

        if ($DesktopPool) {

            $Machines = $Machines | Where-Object {

                $_.DesktopPool -eq $DesktopPool

            }

        }
        Write-HorizonLog `
            -Message "$($Machines.Count) machine(s) remain after filtering." `
            -Level Information

        Write-Verbose "$($Machines.Count) machine(s) remain after filtering."

        Write-Verbose "Building pool summaries."
        if (-not $Machines) {

            Write-HorizonLog `
                -Message 'No machines matched the requested filters.' `
                -Level Warning

            return

        }
        #
        # Build Desktop Pool Health Summary
        #

        $PoolHealth = @(foreach ($Pool in ($Machines | Group-Object DesktopPool | Sort-Object Name)) {

                $PoolMachines = $Pool.Group

                $TotalMachines = $PoolMachines.Count

                $HealthyCount = @(
                    $PoolMachines | Where-Object {
                        $_.HealthStatus -eq 'Healthy'
                    }
                ).Count

                $WarningCount = @(
                    $PoolMachines | Where-Object {
                        $_.HealthStatus -eq 'Warning'
                    }
                ).Count

                $CriticalCount = @(
                    $PoolMachines | Where-Object {
                        $_.HealthStatus -eq 'Critical'
                    }
                ).Count

                $AvailableCount = @(
                    $PoolMachines | Where-Object {
                        $_.MachineState -eq 'AVAILABLE'
                    }
                ).Count

                $ConnectedCount = @(
                    $PoolMachines | Where-Object {
                        $_.MachineState -eq 'CONNECTED'
                    }
                ).Count

                #
                # Overall Pool Health
                #

                if ($CriticalCount -gt 0) {

                    $OverallHealth = 'Critical'

                }
                elseif ($WarningCount -gt 0) {

                    $OverallHealth = 'Warning'

                }
                else {

                    $OverallHealth = 'Healthy'

                }

                #
                # Calculate unavailable machines
                #

                $UnavailableCount = [math]::Max(
                    0,
                    $TotalMachines - $AvailableCount - $ConnectedCount
                )

                #
                # Availability and Utilization Percentages
                #

                if ($TotalMachines -gt 0) {

                    #
                    # Percentage of machines available to accept users.
                    #

                    $AvailabilityPercent = [math]::Round(
                        ($AvailableCount / $TotalMachines) * 100,
                        2
                    )

                    #
                    # Percentage of machines currently in use.
                    #

                    $UtilizationPercent = [math]::Round(
                        ($ConnectedCount / $TotalMachines) * 100,
                        2
                    )

                }
                else {

                    $UnavailableCount = 0
                    $AvailabilityPercent = 0
                    $UtilizationPercent = 0

                }

                [PSCustomObject]@{

                    PSTypeName          = 'Enterprise.Horizon.PoolHealth'
                    DesktopPool         = $Pool.Name
                    TotalMachines       = $TotalMachines
                    UnavailableMachines = $UnavailableCount
                    AvailableMachines   = $AvailableCount
                    ConnectedMachines   = $ConnectedCount
                    HealthyMachines     = $HealthyCount
                    WarningMachines     = $WarningCount
                    CriticalMachines    = $CriticalCount
                    AvailabilityPercent = $AvailabilityPercent
                    UtilizationPercent  = $UtilizationPercent
                    OverallHealth       = $OverallHealth

                }

            })

        Write-HorizonLog `
            -Message "$($PoolHealth.Count) desktop pool health object(s) returned." `
            -Level Information

        Write-Verbose 'Returning enterprise desktop pool health objects.'

        return $PoolHealth

    }

    end {

        Write-HorizonLog `
            -Message 'Get-HorizonPoolHealth completed successfully.' `
            -Level Information

        Write-Verbose 'Get-HorizonPoolHealth completed.'

    }

}