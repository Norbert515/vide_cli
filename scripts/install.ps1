# Usage: irm https://raw.githubusercontent.com/Norbert515/vide_cli/main/scripts/install.ps1 | iex

$ErrorActionPreference = "Stop"

$Repo = "Norbert515/vide_cli"
$BinaryName = "vide.exe"
$InstallDir = "$env:LOCALAPPDATA\Programs\vide"

function Get-LatestVersion {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
    return $release.tag_name -replace '^v', ''
}

function Add-ToPath {
    param([string]$Directory)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$Directory*") {
        $newPath = "$currentPath;$Directory"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "Added $Directory to user PATH"
        return $true
    }
    return $false
}

function Main {
    Write-Host "Installing vide..."

    # Get latest version
    Write-Host "Fetching latest version..."
    $version = Get-LatestVersion
    if (-not $version) {
        Write-Error "Failed to fetch latest version"
        exit 1
    }
    Write-Host "Latest version: $version"

    # Create install directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # Download binary
    $downloadUrl = "https://github.com/$Repo/releases/download/v$version/vide-windows-x64.exe"
    $outputPath = Join-Path $InstallDir $BinaryName

    Write-Host "Downloading from: $downloadUrl"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath

    Write-Host ""
    Write-Host "Successfully installed vide $version to $outputPath"

    # Add to PATH if not present
    $pathAdded = Add-ToPath -Directory $InstallDir

    if ($pathAdded) {
        Write-Host ""
        Write-Host "IMPORTANT: Please restart your terminal for PATH changes to take effect."
    }

    Write-Host ""
    Write-Host "Run 'vide --help' to get started"
}

Main
