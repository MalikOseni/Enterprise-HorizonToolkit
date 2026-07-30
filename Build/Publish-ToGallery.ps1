[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$NuGetApiKey
)

$ModuleName  = 'Enterprise-HorizonToolkit'
$SourcePath  = $PSScriptRoot | Split-Path
$StagingPath = Join-Path $env:TEMP "$ModuleName-staging"

# Clean staging area
if (Test-Path $StagingPath) { Remove-Item $StagingPath -Recurse -Force }
New-Item $StagingPath -ItemType Directory | Out-Null

# Copy only what belongs in the package
$include = @(
    'Public',
    'Private',
    'Config',
    'LICENSE',
    'README.md',
    'CHANGELOG.md',
    "$ModuleName.psd1",
    "$ModuleName.psm1"
)

foreach ($item in $include) {
    $src = Join-Path $SourcePath $item
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $StagingPath $item) -Recurse
    }
}

# Verify the manifest is valid before publishing
$manifest = Join-Path $StagingPath "$ModuleName.psd1"
Test-ModuleManifest -Path $manifest

# Publish from the clean staging folder
Publish-Module -Path $StagingPath -NuGetApiKey $NuGetApiKey -Verbose

# Clean up
Remove-Item $StagingPath -Recurse -Force

Write-Host "Published $ModuleName successfully." -ForegroundColor Green