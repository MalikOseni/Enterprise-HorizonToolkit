#Requires -Version 5.1

<#
===============================================================================

File Name   : Connect-Horizon.ps1
Project     : Enterprise-HorizonToolkit
Author      : Malik Oseni
Version     : 1.1.1

.SYNOPSIS
    Connects to a VMware Horizon Connection Server.

.DESCRIPTION
    Establishes a connection to one of the configured VMware Horizon
    Connection Servers and initialises the Enterprise Horizon Toolkit
    connection state.

    Credential resolution order:
        1. -Credential parameter
        2. -CredentialPath parameter
        3. Credential file path from toolkit configuration
        4. Interactive Get-Credential prompt

.PARAMETER Server
    Optional Horizon Connection Server FQDN or IP. When supplied this server
    is tried first; configured servers follow as fallback.

.PARAMETER Credential
    A PSCredential object. Mutually exclusive with -CredentialPath.

.PARAMETER CredentialPath
    Path to a credential XML file exported with Export-Clixml.
    Mutually exclusive with -Credential.

.PARAMETER Force
    If the toolkit already holds an active connection, disconnect it before
    establishing a new one. Without -Force the existing connection is reused.

.EXAMPLE
    Connect-Horizon

.EXAMPLE
    Connect-Horizon -Credential (Get-Credential)

.EXAMPLE
    Connect-Horizon -Server horizon.example.com

.EXAMPLE
    Connect-Horizon -CredentialPath <path-to-credential-file> -Force

.NOTES

Enterprise-HorizonToolkit
Copyright (c) 2026 Malik Oseni

Change log
----------
1.1.0  Fix #1  -Credential and -CredentialPath are now properly mutually
               exclusive via named parameter sets.
       Fix #2  Guard against orphaned sessions: reuse an active connection
               unless -Force is supplied; if -Force is supplied, call
               Disconnect-HVServer before reconnecting.
       Fix #3  Raise a clear, early error when no connection servers are
               resolvable from either the parameter or configuration.
       Fix #5  Collect per-server failure reasons and include them in the
               final throw so the caller has full context.

===============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Connect-Horizon {

    [CmdletBinding(DefaultParameterSetName = 'Interactive')]

    param(

        # ── Server selection ────────────────────────────────────────────────

        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'WithCredential')]
        [Parameter(ParameterSetName = 'CredentialFile')]
        [string]
        $Server,

        # ── Credential sources (mutually exclusive) ─────────────────────────

        # FIX #1: $Credential now belongs to its own named set so it cannot
        # be combined with -CredentialPath at parse time.

        [Parameter(
            Mandatory,
            ParameterSetName = 'WithCredential'
        )]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(
            Mandatory,
            ParameterSetName = 'CredentialFile'
        )]
        [ValidateScript({
                if (-not (Test-Path $_.FullName)) {
                    throw "Credential file not found: $($_.FullName)"
                }
                $true
            })]
        [System.IO.FileInfo]
        $CredentialPath,

        # ── Behaviour flags ─────────────────────────────────────────────────

        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'WithCredential')]
        [Parameter(ParameterSetName = 'CredentialFile')]
        [switch]
        $Force

    )

    begin {

        Write-HorizonLog `
            -Message 'Starting Connect-Horizon.' `
            -Level Information

        Write-Verbose 'Loading toolkit configuration.'

        $Configuration = Import-HorizonConfiguration

        # ── Verify Horizon PowerCLI ──────────────────────────────────────────

        #
        # Initialise toolkit state
        #

        if (-not (Get-Variable Toolkit -Scope Script -ErrorAction SilentlyContinue)) {

            Write-Verbose 'Initialising toolkit state.'

            $script:Toolkit = [PSCustomObject]@{

                Connection      = $null

                Services        = $null

                ConnectedServer = $null

                ConnectedAt     = $null

                Configuration   = $Configuration

                Version         = '1.1.1'

            }

        }

        $PowerCLIModule = Get-Module `
            -ListAvailable `
            -Name VMware.VimAutomation.HorizonView

        if (-not $PowerCLIModule) {
            throw 'VMware.VimAutomation.HorizonView module is not installed.'
        }

        Write-Verbose "Detected VMware Horizon PowerCLI version $($PowerCLIModule.Version)"

        # ── Guard against orphaned / duplicate sessions ─────────────────────
        #
        # If the toolkit already holds a live connection object, either reuse
        # it (default) or disconnect it before proceeding (-Force).
        # Without this guard, calling Connect-Horizon a second time would
        # silently overwrite $script:Toolkit.Connection, leaving the previous
        # HVServer session dangling inside $global:DefaultHVServers.
        $ReuseExistingConnection = $false

        if ($script:Toolkit.Connection -and $script:Toolkit.Connection.IsConnected) {

            if (-not $Force) {

                Write-Verbose 'Reusing existing Horizon connection.'

                Write-HorizonLog `
                    -Message "Active connection to [$($script:Toolkit.ConnectedServer)] reused. Use -Force to reconnect." `
                    -Level Information

                # `return` from a begin block does not prevent PowerShell from
                # running the process block. Defer the cached result to the
                # start of process so no credential is resolved and no second
                # connection is made when the session is being reused.
                $ReuseExistingConnection = $true

            }


            Write-Verbose "-Force specified. Disconnecting existing session from [$($script:Toolkit.ConnectedServer)]."

            Write-HorizonLog `
                -Message "Disconnecting existing session from [$($script:Toolkit.ConnectedServer)] before reconnecting." `
                -Level Information

            try {

                Disconnect-HVServer `
                    -Server $script:Toolkit.Connection `
                    -Confirm:$false `
                    -ErrorAction SilentlyContinue

            }
            catch {

                # Non-fatal — the session may already have timed out on the
                # server side. Log and continue.
                Write-HorizonLog `
                    -Message "Disconnect warning: $($_.Exception.Message)" `
                    -Level Warning

            }
            finally {

                $script:Toolkit.Connection = $null
                $script:Toolkit.Services = $null
                $script:Toolkit.ConnectedServer = $null
                $script:Toolkit.ConnectedAt = $null

            }

        }

        # ── Build the ordered server list ────────────────────────────────────

        if (-not [string]::IsNullOrWhiteSpace($Server)) {

            # Requested server first, then any configured fallbacks not
            # already in the list.
            $ConnectionServers = [System.Collections.Generic.List[string]]::new()
            $ConnectionServers.Add($Server)

            foreach ($ConfiguredServer in $Configuration.Horizon.ConnectionServers) {

                if ($ConfiguredServer -notin $ConnectionServers) {

                    $ConnectionServers.Add($ConfiguredServer)

                }

            }

        }
        else {

            $ConnectionServers = $Configuration.Horizon.ConnectionServers

        }

        # ── FIX #3: Fail early when no servers are available ─────────────────
        #
        # Previously the foreach loop would silently do nothing if the list
        # was null/empty, producing a misleading "Unable to connect" message
        # that implied connection attempts had been made.

        if (-not $ConnectionServers -or $ConnectionServers.Count -eq 0) {

            throw (
                'No Horizon Connection Servers are configured and none was ' +
                'supplied via -Server. Add at least one entry to ' +
                'Horizon.ConnectionServers in the toolkit configuration.'
            )

        }

        Write-Verbose "Connection order: $($ConnectionServers -join ', ')"

    }

    process {

        if ($ReuseExistingConnection) {

            [PSCustomObject]@{
                PSTypeName       = 'Enterprise.Horizon.Connection'
                ConnectionServer = $script:Toolkit.ConnectedServer
                User             = "$($script:Toolkit.Connection.Domain)\$($script:Toolkit.Connection.User)"
                ServiceUri       = $script:Toolkit.Connection.ServiceUri
                Connected        = $script:Toolkit.Connection.IsConnected
                ConnectedAt      = $script:Toolkit.ConnectedAt
                ModuleVersion    = $script:Toolkit.Version
                HorizonVersion   = $PowerCLIModule.Version.ToString()
                Reused           = $true
            }

            return

        }

        # ── Resolve credentials ───────────────────────────────────────────────
        #
        # Parameter sets enforce mutual exclusivity for -Credential vs
        # -CredentialPath at parse time (Fix #1). The credential object
        # itself is resolved here for the file-path and interactive paths.

        if ($PSCmdlet.ParameterSetName -eq 'CredentialFile') {

            Write-Verbose "Importing credential from $($CredentialPath.FullName)"

            try {

                $Credential = Import-Clixml -Path $CredentialPath.FullName -ErrorAction Stop

            }
            catch {

                throw (
                    "Unable to import credential file [$CredentialPath]. " +
                    'Credential XML files are encrypted for the Windows user and computer that created them. ' +
                    'Create the file again with Export-Clixml under this account, or use -Credential.'
                )

            }

        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Interactive') {

            # Try the credential file path from configuration before prompting.

            $ConfigCredPath = $Configuration.Horizon.CredentialPath

            if (
                -not [string]::IsNullOrWhiteSpace($ConfigCredPath) -and
                (Test-Path $ConfigCredPath)
            ) {

                Write-Verbose 'Importing configured credential.'

                try {

                    $Credential = Import-Clixml -Path $ConfigCredPath -ErrorAction Stop

                }
                catch {

                    Write-HorizonLog `
                        -Message "Unable to import configured credential file [$ConfigCredPath]: $($_.Exception.Message). Prompting for credentials instead." `
                        -Level Warning

                    $Credential = Get-Credential -Message 'Enter VMware Horizon credentials'

                }

            }
            else {

                Write-Verbose 'Prompting for Horizon credentials.'

                $Credential = Get-Credential -Message 'Enter VMware Horizon credentials'

            }

        }
        # For the 'WithCredential' parameter set, $Credential is already bound.

        if ($Credential -isnot [System.Management.Automation.PSCredential]) {

            throw 'The supplied credential source did not contain a PSCredential object.'

        }

        # ── Attempt connections ───────────────────────────────────────────────
        #
        # FIX #5: Collect individual failure reasons so the final throw can
        # surface all of them instead of just a generic "unable to connect."

        $Connection = $null
        $ConnectedServer = $null
        $FailureReasons = [System.Collections.Generic.List[string]]::new()

        foreach ($CurrentServer in $ConnectionServers) {

            try {

                Write-HorizonLog `
                    -Message "Attempting connection to [$CurrentServer]." `
                    -Level Information

                Write-Verbose "Connecting to $CurrentServer"

                # -ErrorAction Stop is kept explicitly here to make the
                # intent clear to future maintainers, even though
                # $ErrorActionPreference is already 'Stop'.
                $Connection = Connect-HVServer `
                    -Server $CurrentServer `
                    -Credential $Credential `
                    -ErrorAction Stop

                $ConnectedServer = $CurrentServer

                Write-HorizonLog `
                    -Message "Successfully connected to [$CurrentServer]." `
                    -Level Information

                break

            }
            catch {

                $Reason = "$CurrentServer - $($_.Exception.Message)"

                $FailureReasons.Add($Reason)

                Write-HorizonLog `
                    -Message "Connection to [$CurrentServer] failed: $($_.Exception.Message)" `
                    -Level Warning

                Write-Verbose "Failed: $($_.Exception.Message)"

            }

        }

        # ── Validate that we actually connected ───────────────────────────────

        if (-not $Connection) {

            $FailureSummary = $FailureReasons -join '; '

            throw "Unable to connect to any configured Horizon Connection Server. Failures: $FailureSummary"

        }

        # ── Cache toolkit state ───────────────────────────────────────────────

        $ConnectedAt = Get-Date

        $script:Toolkit.Connection = $Connection
        $script:Toolkit.Services = $Connection.ExtensionData
        $script:Toolkit.ConnectedServer = $ConnectedServer
        $script:Toolkit.ConnectedAt = $ConnectedAt

        Write-Verbose 'Toolkit connection cache updated.'

        Write-HorizonLog `
            -Message 'Connection cache initialised.' `
            -Level Information

        # ── Build and emit the output object ──────────────────────────────────

        [PSCustomObject]@{

            PSTypeName       = 'Enterprise.Horizon.Connection'
            ConnectionServer = $ConnectedServer
            User             = "$($Connection.Domain)\$($Connection.User)"
            ServiceUri       = $Connection.ServiceUri
            Connected        = $Connection.IsConnected
            ConnectedAt      = $ConnectedAt
            ModuleVersion    = $script:Toolkit.Version
            HorizonVersion   = $PowerCLIModule.Version.ToString()
            Reused           = $false

        }

    }

    end {

        Write-Verbose 'Connect-Horizon completed.'

    }

}