#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Export-HorizonReport {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object]$InputObject,

        [ValidateSet('Csv', 'Json')]
        [string]$Format = 'Csv',

        [string]$Path,

        [switch]$Force
    )

    begin {
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($null -ne $InputObject) { $items.Add($InputObject) }
    }

    end {
        if ($items.Count -eq 0) {
            Write-Warning 'No report objects were supplied; no file was created.'
            return
        }

        if ([string]::IsNullOrWhiteSpace($Path)) {
            $configuration = Import-HorizonConfiguration
            $extension = if ($Format -eq 'Csv') { 'csv' } else { 'json' }
            $fileName = 'HorizonReport-{0:yyyyMMdd-HHmmss}.{1}' -f (Get-Date), $extension
            $Path = Join-Path $configuration.Reporting.OutputPath $fileName
        }

        $directory = Split-Path -Path $Path -Parent
        if ([string]::IsNullOrWhiteSpace($directory)) { $directory = (Get-Location).Path }
        if (-not (Test-Path -LiteralPath $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        if ((Test-Path -LiteralPath $Path) -and -not $Force) {
            throw "Report already exists: $Path. Use -Force to overwrite it."
        }

        if (-not $PSCmdlet.ShouldProcess($Path, "Export $($items.Count) Horizon report object(s) as $Format")) {
            return
        }

        if ($Format -eq 'Csv') {
            $items | Export-Csv -LiteralPath $Path -NoTypeInformation -Force:$Force
        }
        else {
            $items | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8 -Force:$Force
        }

        $result = Get-Item -LiteralPath $Path
        Write-HorizonLog -Message "Exported $($items.Count) Horizon report object(s) to [$($result.FullName)]." -Level Information
        return $result
    }
}