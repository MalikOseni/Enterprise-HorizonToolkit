#Requires -Version 5.1

<#
.SYNOPSIS
    Retrieves VMware Horizon sessions.

.DESCRIPTION
    Queries VMware Horizon for desktop and RDS sessions and returns
    enterprise session objects suitable for reporting,
    troubleshooting and automation.

.PARAMETER UserName
    Filter by username.

.PARAMETER MachineName
    Filter by machine name.

.PARAMETER State
    Filter by Horizon session state.

.EXAMPLE
    Get-HorizonSessions

.EXAMPLE
    Get-HorizonSessions -State CONNECTED

.EXAMPLE
    Get-HorizonSessions -UserName l.cross

.NOTES

Project : Enterprise-HorizonToolkit
Author  : Malik Oseni
Version : 1.0.0

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HorizonSessions {

    [CmdletBinding()]

    [OutputType([PSCustomObject])]

    param(

        [Parameter()]
        [string]
        $UserName,

        [Parameter()]
        [string]
        $MachineName,

        [Parameter()]
        [ValidateSet(
            'CONNECTED',
            'DISCONNECTED',
            'PENDING',
            'CUSTOMIZING',
            'PROVISIONING',
            'ERROR'
        )]
        [string]
        $State

    )

    begin {

        Write-HorizonLog `
            -Message 'Starting Get-HorizonSessions.' `
            -Level Information

    }

    process {

        Write-Verbose 'Retrieving Horizon sessions.'

        $SessionResults = @(Invoke-HorizonQuery `
                -EntityType 'SessionLocalSummaryView')
        #
        # Apply Filters
        #

        if ($UserName) {

            Write-Verbose "Filtering by username [$UserName]."

            $SessionResults = @($SessionResults | Where-Object {

                    $_.NamesData.UserName -match [regex]::Escape($UserName)

                })

        }

        if ($MachineName) {

            Write-Verbose "Filtering by machine [$MachineName]."

            $SessionResults = @($SessionResults | Where-Object {

                    $_.NamesData.MachineOrRDSServerName -match [regex]::Escape($MachineName)

                })

        }

        if ($State) {

            Write-Verbose "Filtering by state [$State]."

            $SessionResults = @($SessionResults | Where-Object {

                    $_.SessionData.SessionState -eq $State

                })

        }

        Write-HorizonLog `
            -Message "$($SessionResults.Count) session(s) matched the requested filters." `
            -Level Information

        Write-Verbose "$($SessionResults.Count) session(s) remain after filtering."

        #
        # Convert Horizon objects into Enterprise Toolkit objects
        #
        $Now = Get-Date
        foreach ($Session in $SessionResults) {

            $Names = $Session.NamesData
            $Data = $Session.SessionData

            #
            # Calculate Idle Minutes
            #

            $IdleMinutes = $null

            if ($null -ne $Data.IdleDuration) {

                $IdleMinutes = [math]::Round(
                    ($Data.IdleDuration / 60),
                    2
                )

            }

            #
            # Calculate Session Duration
            #

            $DurationMinutes = $null

            if ($Data.StartTime) {

                $DurationMinutes = [math]::Round(

                    ($Now - $Data.StartTime).TotalMinutes,

                    2

                )

            }

            [PSCustomObject]@{

                PSTypeName              = 'Enterprise.Horizon.Session'

                RawSessionId            = $Session.Id

                SessionId               = $Session.RefId

                UserName                = $Names.UserName

                MachineName             = $Names.MachineOrRDSServerName

                MachineDNS              = $Names.MachineOrRDSServerDNS

                DesktopPool             = $Names.DesktopPoolCN

                DesktopName             = $Names.DesktopName

                DesktopType             = $Names.DesktopType

                DesktopSource           = $Names.DesktopSource

                SessionState            = $Data.SessionState

                SessionType             = $Data.SessionType

                Protocol                = $Data.SessionProtocol

                StartTime               = $Data.StartTime

                DisconnectTime          = $Data.DisconnectTime

                DurationMinutes         = $DurationMinutes

                IdleMinutes             = $IdleMinutes

                ClientName              = $Names.ClientName

                ClientType              = $Names.ClientType

                ClientAddress           = $Names.ClientAddress

                ClientVersion           = $Names.ClientVersion

                AgentVersion            = $Names.AgentVersion

                SecurityGateway         = $Names.SecurityGatewayDNS

                SecurityGatewayAddress  = $Names.SecurityGatewayAddress

                SecurityGatewayLocation = $Names.SecurityGatewayLocation

                BrokeredRemotely        = $Data.BrokeredRemotely

                ResourcedRemotely       = $Data.ResourcedRemotely

                ForeverSession          = $Data.ForeverSession

                Unauthenticated         = $Data.Unauthenticated

            }

        }
        Write-HorizonLog `
            -Message "Returning $($SessionResults.Count) enterprise session object(s)." `
            -Level Information

        Write-Verbose 'Enterprise session objects created successfully.'

    }

    end {

        Write-HorizonLog `
            -Message 'Get-HorizonSessions completed successfully.' `
            -Level Information

        Write-Verbose 'Get-HorizonSessions completed.'

    }

}