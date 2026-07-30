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

# Copy only what belongs in the package — no .git, no Build, no .github
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

# Verify staging contents
Write-Host "Staging folder contents:"
Get-ChildItem $StagingPath -Recurse | Select-Object FullName

# Publish using PSResourceGet v3 which handles path publishing correctly
Publish-PSResource `
    -Path $StagingPath `
    -ApiKey $NuGetApiKey `
    -Repository PSGallery `
    -Verbose

# Clean up
Remove-Item $StagingRoot -Recurse -Force

Write-Host "Published $ModuleName successfully." -ForegroundColor Green