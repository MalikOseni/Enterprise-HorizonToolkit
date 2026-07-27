#Requires -Version 5.1

<#
.SYNOPSIS
    Returns disconnected VMware Horizon sessions.

.DESCRIPTION
    Retrieves disconnected Horizon sessions using Get-HorizonSessions
    and filters them based on disconnect duration.

.PARAMETER HoursDisconnected
    Minimum number of hours the session has been disconnected.

.PARAMETER UserName
    Filter by username.

.PARAMETER MachineName
    Filter by machine name.

.EXAMPLE

Get-HorizonDisconnectedSessions

.EXAMPLE

Get-HorizonDisconnectedSessions -HoursDisconnected 4

.EXAMPLE

Get-HorizonDisconnectedSessions -UserName l.cross

.NOTES

Project : Enterprise-HorizonToolkit
Author  : Malik Oseni
Version : 1.0.0

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HorizonDisconnectedSessions {

    [CmdletBinding()]

    [OutputType([PSCustomObject])]

    param(

        [Parameter()]
        [ValidateRange(0, 720)]
        [int]
        $HoursDisconnected = 0,

        [Parameter()]
        [string]
        $UserName,

        [Parameter()]
        [string]
        $MachineName

    )

    begin {

        Write-HorizonLog `
            -Message 'Starting Get-HorizonDisconnectedSessions.' `
            -Level Information

        $Now = Get-Date

    }

    process {

        Write-Verbose 'Retrieving disconnected Horizon sessions.'

        $SessionParameters = @{ State = 'DISCONNECTED' }

        if ($PSBoundParameters.ContainsKey('UserName')) {
            $SessionParameters.UserName = $UserName
        }

        if ($PSBoundParameters.ContainsKey('MachineName')) {
            $SessionParameters.MachineName = $MachineName
        }

        $Sessions = @(Get-HorizonSessions @SessionParameters)

        Write-HorizonLog `
            -Message "$($Sessions.Count) disconnected Horizon session(s) retrieved." `
            -Level Information

        Write-Verbose 'Filtering disconnected sessions.'

        $DisconnectedSessions = @(foreach ($Session in $Sessions) {

            #
            # Skip sessions that have never disconnected
            #

            if ($null -eq $Session.DisconnectTime) {

                continue

            }

            #
            # Calculate how long the session has been disconnected
            #

            $DisconnectedHours = [math]::Round(

                (
                    $Now - $Session.DisconnectTime
                ).TotalHours,

                2

            )

            #
            # Apply threshold filter
            #

            if ($DisconnectedHours -lt $HoursDisconnected) {

                continue

            }

            #
            # Return immutable enterprise object
            #

            [PSCustomObject]@{

                PSTypeName              = 'Enterprise.Horizon.DisconnectedSession'

                SessionId               = $Session.SessionId

                UserName                = $Session.UserName

                MachineName             = $Session.MachineName

                MachineDNS              = $Session.MachineDNS

                DesktopPool             = $Session.DesktopPool

                DesktopName             = $Session.DesktopName

                DesktopType             = $Session.DesktopType

                DesktopSource           = $Session.DesktopSource

                SessionState            = $Session.SessionState

                SessionType             = $Session.SessionType

                Protocol                = $Session.Protocol

                StartTime               = $Session.StartTime

                DisconnectTime          = $Session.DisconnectTime

                DurationMinutes         = $Session.DurationMinutes

                IdleMinutes             = $Session.IdleMinutes

                HoursDisconnected       = $DisconnectedHours

                ClientName              = $Session.ClientName

                ClientType              = $Session.ClientType

                ClientAddress           = $Session.ClientAddress

                ClientVersion           = $Session.ClientVersion

                AgentVersion            = $Session.AgentVersion

                SecurityGateway         = $Session.SecurityGateway

                SecurityGatewayAddress  = $Session.SecurityGatewayAddress

                SecurityGatewayLocation = $Session.SecurityGatewayLocation

                BrokeredRemotely        = $Session.BrokeredRemotely

                ResourcedRemotely       = $Session.ResourcedRemotely

                ForeverSession          = $Session.ForeverSession

                Unauthenticated         = $Session.Unauthenticated

            }

        })

        Write-HorizonLog `
            -Message "$($DisconnectedSessions.Count) disconnected session(s) matched the requested criteria." `
            -Level Information

        Write-Verbose 'Returning enterprise disconnected session objects.'

        return $DisconnectedSessions

    }

    end {

        Write-HorizonLog `
            -Message 'Get-HorizonDisconnectedSessions completed successfully.' `
            -Level Information

        Write-Verbose 'Get-HorizonDisconnectedSessions completed.'

    }

}