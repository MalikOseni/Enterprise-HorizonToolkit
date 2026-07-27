#Requires -Version 5.1

<#
.SYNOPSIS
    Sends a message to a connected VMware Horizon session.

.DESCRIPTION
    Locates the connected Horizon session running on the specified machine
    and sends a popup message using the VMware Horizon Services API.

.PARAMETER MachineName
    Horizon machine name.

.PARAMETER Message
    Message to display to the user.

.PARAMETER MessageType
    Message severity.

.PARAMETER Execute
    Actually send the message.
    Without -Execute the cmdlet performs a dry run and returns the plan.

.EXAMPLE

Send-HorizonSessionMessage `
    -MachineName <MachineName> `
    -Message "IT Maintenance tonight at 19:00."

.EXAMPLE

Send-HorizonSessionMessage `
    -MachineName <MachineName> `
    -Message "Please save your work." `
    -MessageType WARNING `
    -Execute

.NOTES

Project : Enterprise-HorizonToolkit
Author  : Malik Oseni
Version : 1.2.0

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Send-HorizonSessionMessage {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]

    [OutputType('Enterprise.Horizon.SessionMessagePlan')]

    param(

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MachineName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Message,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $MessageType = 'INFO',

        [switch]
        $Execute

    )

    begin {

        Write-HorizonLog `
            -Message "Starting Send-HorizonSessionMessage." `
            -Level Information

    }

    process {

        try {

            Write-Verbose "Searching for connected session on [$MachineName]."

            $Matches = @(
                Get-HorizonSessions -MachineName $MachineName |
                Where-Object SessionState -eq 'CONNECTED'
            )

            if ($Matches.Count -eq 0) {

                throw "No connected Horizon session exists on [$MachineName]."

            }

            if ($Matches.Count -gt 1) {

                throw "Multiple connected sessions were found on [$MachineName]. Refine the target."

            }

            $Session = $Matches[0]

            $Plan = [PSCustomObject]@{

                PSTypeName   = 'Enterprise.Horizon.SessionMessagePlan'

                MachineName  = $Session.MachineName

                UserName     = $Session.UserName

                RawSessionId = $Session.RawSessionId

                SessionId    = $Session.SessionId

                MessageType  = $MessageType

                Message      = $Message

                WillSend     = [bool]$Execute

            }

            if (-not $Execute) {

                Write-Information `
                    "Message plan created for [$($Session.MachineName)]. Re-run with -Execute to send it." `
                    -InformationAction Continue

                return $Plan

            }

            $Services = Get-HorizonService

            if (-not ($Services.Session | Get-Member `
                        -Name Session_SendMessage `
                        -MemberType Method)) {

                throw "Session_SendMessage() is not available in this version of VMware Horizon."

            }

            if ($PSCmdlet.ShouldProcess(

                    "Session [$($Session.SessionId)]",

                    "Send Horizon message"

                )) {

                Write-HorizonLog `
                    -Message "Sending [$MessageType] message to [$($Session.UserName)] on [$($Session.MachineName)]." `
                    -Level Information

                #
                # VMware Horizon API
                #

                $Services.Session.Session_SendMessage(

                    $Session.RawSessionId,

                    $MessageType,

                    $Message

                )

                Write-HorizonLog `
                    -Message "Message successfully sent to [$($Session.UserName)]." `
                    -Level Information

            }

            return $Plan

        }
        catch {

            Write-HorizonLog `
                -Message $_.Exception.Message `
                -Level Error

            throw

        }

    }

    end {

        Write-HorizonLog `
            -Message "Send-HorizonSessionMessage completed." `
            -Level Information

        Write-Verbose "Send-HorizonSessionMessage completed."

    }

}