param(
    [string]$Version = "1.0.0",
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppProject = Join-Path $ProjectDir "ChargeCat.Windows\ChargeCat.Windows.csproj"
$OutputDir = Join-Path $ProjectDir "dist\$Runtime"
$ZipPath = Join-Path $ProjectDir "dist\ChargeCat-Windows-$Version-$Runtime.zip"

if (Test-Path $OutputDir) {
    Remove-Item $OutputDir -Recurse -Force
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

dotnet publish $AppProject `
    -c Release `
    -r $Runtime `
    --self-contained false `
    -p:PublishSingleFile=false `
    -o $OutputDir

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive -Path (Join-Path $OutputDir "*") -DestinationPath $ZipPath

Write-Host ""
Write-Host "Build complete"
Write-Host "Output: $OutputDir"
Write-Host "Zip:    $ZipPath"
