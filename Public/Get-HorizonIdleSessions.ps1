#Requires -Version 5.1

<#
===============================================================================

File Name   : Get-HorizonIdleSessions.ps1
Project     : Enterprise-HorizonToolkit
Author      : Malik Oseni
Version     : 1.1.0

.SYNOPSIS
    Returns idle VMware Horizon sessions.

.DESCRIPTION
    Retrieves Horizon sessions and returns those that have been idle
    for longer than the specified threshold.

.PARAMETER IdleMinutes
    Minimum idle time in minutes. Defaults to 240 (4 hours).

.PARAMETER UserName
    Filter by username.

.PARAMETER MachineName
    Filter by machine name.

.PARAMETER State
    Optional session state filter. Accepts CONNECTED or DISCONNECTED.

.EXAMPLE
    Get-HorizonIdleSessions

.EXAMPLE
    Get-HorizonIdleSessions -IdleMinutes 240

.EXAMPLE
    Get-HorizonIdleSessions -MachineName <MachineName>

.NOTES

Enterprise-HorizonToolkit
Copyright (c) 2026 Malik Oseni

Change log
----------
1.1.0  Bug #1  begin/process/end blocks were nested inside begin instead of
               being direct children of the function body. PowerShell only
               executed the begin block; process and end were never reached.
       Bug #2  Get-HorizonSessions was called twice with the same params and
               the log/verbose lines were duplicated. Duplicate call removed.
       Bug #3  $IdleSessions.Count fails when the foreach returns $null
               (zero matches). Wrapped in @() to guarantee an array so
               .Count is always safe.
       Bug #4  Missing closing brace for the function body added.

===============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HorizonIdleSessions {

    [OutputType('Enterprise.Horizon.IdleSession')]
    [CmdletBinding()]

    param(

        [Parameter()]
        [ValidateRange(1, 10080)]
        [int]
        $IdleMinutes = 240,

        [Parameter()]
        [string]
        $UserName,

        [Parameter()]
        [string]
        $MachineName,

        [Parameter()]
        [ValidateSet(
            'CONNECTED',
            'DISCONNECTED'
        )]
        [string]
        $State

    )

    # BUG #1 FIX: begin/process/end are now direct children of the function
    # body, not nested inside begin. In the original, PowerShell saw the outer
    # begin block and treated the inner begin/process/end as ordinary
    # statements inside it, meaning process and end never executed as
    # pipeline blocks.

    begin {

        Write-HorizonLog `
            -Message 'Starting Get-HorizonIdleSessions.' `
            -Level Information

    }

    process {

        Write-Verbose 'Retrieving Horizon sessions.'

        $Params = @{
            UserName    = $UserName
            MachineName = $MachineName
        }

        if ($PSBoundParameters.ContainsKey('State')) {

            $Params.State = $State
        }

        # BUG #2 FIX: Get-HorizonSessions was called twice back-to-back with
        # identical parameters, and the log/verbose lines that followed were
        # also duplicated. The second call was retrieving a fresh set of
        # sessions and silently discarding the first, which wasted an API
        # round-trip and could return inconsistent counts between the two
        # log lines. Removed the duplicate.
        $Sessions = @(Get-HorizonSessions @Params)

        Write-HorizonLog `
            -Message "$($Sessions.Count) Horizon session(s) retrieved." `
            -Level Information

        Write-Verbose 'Filtering idle sessions.'

        # BUG #3 FIX: When no sessions match the idle threshold the foreach
        # expression returns $null rather than an empty array. Calling .Count
        # on $null throws a property-not-found error under Set-StrictMode.
        # Wrapping in @() guarantees an array with a safe .Count in all cases.
        $IdleSessions = @(

            foreach ($Session in @($Sessions)) {

                # Ignore sessions that have no idle value
                if ($null -eq $Session.IdleMinutes) {
                    continue
                }

                # Apply idle threshold
                if ($Session.IdleMinutes -lt $IdleMinutes) {
                    continue
                }

                # Emit the enterprise session object
                [PSCustomObject] @{
                    PSTypeName              = 'Enterprise.Horizon.IdleSession'
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

            }

        )

        Write-HorizonLog `
            -Message "$($IdleSessions.Count) idle session(s) found." `
            -Level Information

        Write-Verbose 'Returning enterprise idle session objects.'

        Write-HorizonLog `
            -Message "Returning $($IdleSessions.Count) idle session(s)." `
            -Level Information

        return $IdleSessions

    }

    end {

        Write-HorizonLog `
            -Message 'Get-HorizonIdleSessions completed successfully.' `
            -Level Information

        Write-Verbose 'Get-HorizonIdleSessions completed.'

    }

    # BUG #4 FIX: The original file was missing the closing brace for the
    # function body entirely, which would cause a MissingEndCurlyBrace parse
    # error when the file was loaded.

}