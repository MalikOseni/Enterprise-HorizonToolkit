[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$NuGetApiKey
)

$ModuleName  = 'Enterprise-HorizonToolkit'
$SourcePath  = $PSScriptRoot | Split-Path
$StagingRoot = Join-Path $env:TEMP "$ModuleName-staging"
$StagingPath = Join-Path $StagingRoot $ModuleName

# Clean staging area
if (Test-Path $StagingRoot) { Remove-Item $StagingRoot -Recurse -Force }
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

# Prepend staging ROOT so PowerShell finds ModuleName\ModuleName.psd1
$env:PSModulePath = "$StagingRoot;$env:PSModulePath"
Import-Module -Name $ModuleName -Force

# Publish by name
Publish-Module `
    -Name $ModuleName `
    -NuGetApiKey $NuGetApiKey `
    -Repository PSGallery `
    -Force `
    -Verbose

# Clean up
Remove-Item $StagingRoot -Recurse -Force

Write-Host "Published $ModuleName successfully." -ForegroundColor Green