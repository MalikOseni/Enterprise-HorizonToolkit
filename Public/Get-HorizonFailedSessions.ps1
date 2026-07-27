#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HorizonFailedSessions {

    [CmdletBinding()]
    [OutputType('Enterprise.Horizon.FailedSession')]
    param(
        [string]$UserName,
        [string]$MachineName
    )

    begin {
        Write-HorizonLog -Message 'Starting Get-HorizonFailedSessions.' -Level Information
    }

    process {
        $parameters = @{ State = 'ERROR' }
        if ($PSBoundParameters.ContainsKey('UserName')) { $parameters.UserName = $UserName }
        if ($PSBoundParameters.ContainsKey('MachineName')) { $parameters.MachineName = $MachineName }

        $sessions = @(Get-HorizonSessions @parameters)
        $failedSessions = @(
            foreach ($session in $sessions) {
                [PSCustomObject]@{
                    PSTypeName       = 'Enterprise.Horizon.FailedSession'
                    SessionId        = $session.SessionId
                    UserName         = $session.UserName
                    MachineName      = $session.MachineName
                    MachineDNS       = $session.MachineDNS
                    DesktopPool      = $session.DesktopPool
                    SessionState     = $session.SessionState
                    StartTime        = $session.StartTime
                    DisconnectTime   = $session.DisconnectTime
                    DurationMinutes  = $session.DurationMinutes
                    ClientName       = $session.ClientName
                    ClientAddress    = $session.ClientAddress
                    FailureCategory  = 'Horizon session state is ERROR'
                }
            }
        )

        Write-HorizonLog -Message "$($failedSessions.Count) failed session(s) found." -Level Information
        return $failedSessions
    }

    end {
        Write-HorizonLog -Message 'Get-HorizonFailedSessions completed successfully.' -Level Information
    }
}