@{

    # -------------------------------------------------------------------------
    # Script Module
    # -------------------------------------------------------------------------

    RootModule = 'Enterprise-HorizonToolkit.psm1'

    ModuleVersion = '1.2.0'

    GUID = 'b9f6f3c4-9c66-4d73-b7c2-2b2d8d2d5f21'

    Author = 'Malik Oseni'

    CompanyName = 'Personal Project'

    Copyright = '(c) 2026 Malik Oseni. All rights reserved.'

    Description = 'Enterprise PowerShell Toolkit for VMware Horizon administration, diagnostics, reporting and automation.'

    PowerShellVersion = '5.1'

    CompatiblePSEditions = @(
        'Desktop'
    )

    # -------------------------------------------------------------------------
    # Required Modules
    # -------------------------------------------------------------------------

    RequiredModules = @(
        @{
            ModuleName = 'VMware.VimAutomation.HorizonView'
            ModuleVersion = '13.2.0'
        }
    )

    # -------------------------------------------------------------------------
    # Exported Members
    # -------------------------------------------------------------------------

    FunctionsToExport = @(
        'Connect-Horizon',
        'Get-HorizonSessions',
        'Get-HorizonIdleSessions',
        'Get-HorizonDisconnectedSessions',
        'Get-HorizonFailedSessions',
        'Send-HorizonSessionMessage',
        'Restart-HorizonMachine',
        'Get-HorizonMachineHealth',
        'Get-HorizonPoolHealth',
        'Export-HorizonReport'
    )

    CmdletsToExport = @()

    VariablesToExport = @()

    AliasesToExport = @()

    # -------------------------------------------------------------------------
    # Private Data
    # -------------------------------------------------------------------------

    PrivateData = @{

        PSData = @{

            Tags = @(
                'VMware'
                'Horizon'
                'PowerShell'
                'Automation'
                'VDI'
                'Enterprise'
            )

            LicenseUri = 'https://opensource.org/licenses/MIT'

            ProjectUri = 'https://github.com/MalikOseni/Enterprise-HorizonToolkit'

            ReleaseNotes = @'
Initial project structure.

Configuration framework implemented.

Module loader implemented.
'@

        }

    }

}