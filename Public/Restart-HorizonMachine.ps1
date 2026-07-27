#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Restart-HorizonMachine {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('Enterprise.Horizon.MachineRestartPlan')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MachineName,

        [ValidateRange(0, 720)]
        [int]$MinimumDisconnectedHours = 6,

        [switch]$IncludeFailedSessions,

        [switch]$Execute
    )

    $machineMatches = @(Invoke-HorizonQuery -EntityType 'MachineSummaryView' |
        Where-Object { $_.Base.Name -eq $MachineName })

    if ($machineMatches.Count -eq 0) {
        throw "No Horizon machine named [$MachineName] was found. No action was taken."
    }
    if ($machineMatches.Count -gt 1) {
        throw "More than one Horizon machine named [$MachineName] was found. No action was taken."
    }

    $machine = $machineMatches[0]
    $poolName = $machine.Base.DesktopName

    $configuration = Import-HorizonConfiguration

    if ($configuration.Exclusions.Pools -contains $poolName) {
        throw "Machine [$MachineName] belongs to excluded pool [$poolName]. No action was taken."
    }

    $sessions = @(Get-HorizonSessions -MachineName $MachineName |
        Where-Object { $_.MachineName -eq $MachineName })

    $excludedUsers = @($sessions | Where-Object { $_.UserName -in $configuration.Exclusions.Users })

    if ($excludedUsers.Count -gt 0) {
        throw "Machine [$MachineName] has an excluded user session. No action was taken."
    }

    $blockingSessions = @($sessions | Where-Object { $_.SessionState -notin @('DISCONNECTED', 'ERROR') })

    if ($blockingSessions.Count -gt 0) {
        throw "Machine [$MachineName] has $($blockingSessions.Count) connected or transitional session(s). No action was taken."
    }

    $failedSessions = @($sessions | Where-Object { $_.SessionState -eq 'ERROR' })

    if ($failedSessions.Count -gt 0 -and -not $IncludeFailedSessions) {
        throw "Machine [$MachineName] has failed session(s). Re-run with -IncludeFailedSessions only after reviewing Get-HorizonFailedSessions."
    }

    $now = Get-Date

    $recentDisconnects = @($sessions | Where-Object {
            $_.SessionState -eq 'DISCONNECTED' -and
            ($null -eq $_.DisconnectTime -or ($now - $_.DisconnectTime).TotalHours -lt $MinimumDisconnectedHours)
        })

    if ($recentDisconnects.Count -gt 0) {
        throw "Machine [$MachineName] has session(s) disconnected for less than $MinimumDisconnectedHours hour(s). No action was taken."
    }

    $plan = [PSCustomObject]@{
        PSTypeName               = 'Enterprise.Horizon.MachineRestartPlan'
        MachineName              = $machine.Base.Name
        DesktopPool              = $poolName
        MachineId                = $machine.Id
        SessionCount             = $sessions.Count
        DisconnectedSessionCount = @($sessions | Where-Object SessionState -eq 'DISCONNECTED').Count
        FailedSessionCount       = $failedSessions.Count
        MinimumDisconnectedHours = $MinimumDisconnectedHours
        WillRestart              = [bool]$Execute
    }

    if (-not $Execute) {
        Write-Information "Restart plan created for [$MachineName]. Re-run with -Execute -Confirm to restart it." -InformationAction Continue
        return $plan
    }

    $services = Get-HorizonService

    if (-not ($services.Machine | Get-Member -Name 'Machine_Restart' -MemberType Method)) {
        throw 'This installed Horizon PowerCLI version does not expose Machine_Restart. No restart was performed.'
    }

    if ($PSCmdlet.ShouldProcess("machine [$MachineName] in pool [$poolName]", 'Restart Horizon machine')) {

        $null = $services.Machine.Machine_Restart($machine.Id)

        Write-HorizonLog `
            -Message "Restart requested for Horizon machine [$MachineName] in pool [$poolName]." `
            -Level Warning

    }

    return $plan

}