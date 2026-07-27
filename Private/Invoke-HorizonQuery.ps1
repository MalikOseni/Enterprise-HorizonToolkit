#Requires -Version 5.1

<#
.SYNOPSIS
    Executes VMware Horizon QueryService queries.

.DESCRIPTION
    Provides a reusable wrapper around VMware Horizon QueryService.

    Handles:

        • Query creation
        • Paging
        • Cleanup
        • Error handling

.NOTES

Project : Enterprise-HorizonToolkit
Author  : Malik Oseni
Version : 1.0.0

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-HorizonQuery {

    [CmdletBinding()]

    [OutputType([Object[]])]

    param(

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $EntityType

    )

    begin {

        Write-HorizonLog `
            -Message "Starting Horizon query [$EntityType]." `
            -Level Information

        $Services = Get-HorizonService

        $QueryService = New-Object VMware.Hv.QueryServiceService

        $QueryDefinition = New-Object VMware.Hv.QueryDefinition

        $QueryDefinition.QueryEntityType = $EntityType

    }

    process {

        try {

            Write-Verbose "Executing Horizon query [$EntityType]."

            #
            # Execute the initial query
            #

            $QueryResult = $QueryService.QueryService_Create(
                $Services,
                $QueryDefinition
            )

            if (-not $QueryResult) {

                throw "The Horizon query for [$EntityType] returned no results."

            }

            #
            # Store all returned objects
            #

            $Results = @()

            while ($true) {

                if ($QueryResult.Results) {

                    $Results += $QueryResult.Results

                }

                if (
                    -not $QueryResult.RemainingCount -or
                    $QueryResult.RemainingCount -le 0
                ) {

                    break

                }

                Write-Verbose "Retrieving next page for [$EntityType]."

                $QueryResult = $QueryService.QueryService_GetNext(
                    $Services,
                    $QueryResult.Id
                )

            }

            Write-HorizonLog `
                -Message "$($Results.Count) object(s) returned for [$EntityType]." `
                -Level Information
            #
            # Return query results
            #

            return $Results

        }
        catch {

            Write-HorizonLog `
                -Message $_.Exception.Message `
                -Level Error

            throw

        }
        finally {

            #
            # Always destroy the Horizon query
            #

            if ($QueryResult -and $QueryResult.Id) {

                try {

                    Write-Verbose "Destroying Horizon query [$EntityType]."

                    $QueryService.QueryService_Delete(
                        $Services,
                        $QueryResult.Id
                    )

                }
                catch {

                    Write-HorizonLog `
                        -Message "Failed to destroy Horizon query [$EntityType]. $($_.Exception.Message)" `
                        -Level Warning

                }

            }
        }
    }

    end {

        Write-HorizonLog `
            -Message "Horizon query [$EntityType] completed successfully." `
            -Level Information

        Write-Verbose "Horizon query [$EntityType] completed."

    }

}