#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-HorizonConnection {

    [CmdletBinding()]
    [OutputType([bool], [PSCustomObject])]
    param(
        [switch]$PassThru
    )

    $isConnected = $false
    $server = $null
    $connectedAt = $null

    if ($script:Toolkit -and $script:Toolkit.Connection) {
        $isConnected = [bool]$script:Toolkit.Connection.IsConnected
        $server = $script:Toolkit.ConnectedServer
        $connectedAt = $script:Toolkit.ConnectedAt
    }

    if ($PassThru) {
        return [PSCustomObject]@{
            PSTypeName       = 'Enterprise.Horizon.ConnectionStatus'
            Connected        = $isConnected
            ConnectionServer = $server
            ConnectedAt      = $connectedAt
        }
    }

    return $isConnected
}