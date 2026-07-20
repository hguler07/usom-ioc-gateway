# USOM IOC Gateway - Windows Uninstaller
# Compatible with Windows PowerShell 5.1 and PowerShell 7+

param(
    [switch]$PruneDocker,
    [switch]$PurgeDockerDesktop
)

$ErrorActionPreference = "Continue"

$ProjectName = "usom-ioc-gateway"
$ProjectDir = "C:\USOM\usom-ioc-gateway"
$RootDir = "C:\USOM"
$BadSystem32Dir = "C:\Windows\System32\usom-ioc-gateway"

function Test-DockerAvailable {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        return $false
    }

    docker info *> $null

    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return $true
}

function Remove-DockerItemsByName {
    param(
        [string]$Type,
        [string]$Pattern
    )

    if ($Type -eq "container") {
        docker ps -a --format "{{.ID}} {{.Names}}" |
            Select-String $Pattern |
            ForEach-Object {
                $id = ($_ -split " ")[0]
                if ($id) {
                    docker rm -f $id
                }
            }
    }

    if ($Type -eq "image") {
        docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" |
            Select-String $Pattern |
            ForEach-Object {
                $image = ($_ -split " ")[0]
                if ($image) {
                    docker rmi -f $image
                }
            }
    }

    if ($Type -eq "volume") {
        docker volume ls --format "{{.Name}}" |
            Select-String $Pattern |
            ForEach-Object {
                $name = $_.ToString()
                if ($name) {
                    docker volume rm -f $name
                }
            }
    }

    if ($Type -eq "network") {
        docker network ls --format "{{.Name}}" |
            Select-String $Pattern |
            ForEach-Object {
                $name = $_.ToString()
                if ($name -and $name -ne "bridge" -and $name -ne "host" -and $name -ne "none") {
                    docker network rm $name
                }
            }
    }
}

Write-Host ""
Write-Host "USOM IOC Gateway Windows cleanup starting..." -ForegroundColor Cyan

$DockerAvailable = Test-DockerAvailable

if ($DockerAvailable) {
    Write-Host "Stopping USOM IOC Gateway services..." -ForegroundColor Cyan

    if (Test-Path $ProjectDir) {
        Set-Location $ProjectDir

        if (Test-Path ".\compose.yaml") {
            docker compose `
                --project-name $ProjectName `
                --project-directory $ProjectDir `
                -f .\compose.yaml `
                down -v --remove-orphans
        }
    }

    Write-Host "Removing matching containers..." -ForegroundColor Cyan
    Remove-DockerItemsByName -Type "container" -Pattern "usom-ioc-gateway|threat-feed-gateway"

    Write-Host "Removing matching images..." -ForegroundColor Cyan
    Remove-DockerItemsByName -Type "image" -Pattern "hguler07/usom-ioc-gateway|usom-ioc-gateway"

    Write-Host "Removing matching volumes..." -ForegroundColor Cyan
    Remove-DockerItemsByName -Type "volume" -Pattern "usom-ioc-gateway|threat-feed-gateway"

    Write-Host "Removing matching networks..." -ForegroundColor Cyan
    Remove-DockerItemsByName -Type "network" -Pattern "usom-ioc-gateway|threat-feed-gateway"

    if ($PruneDocker -or $PurgeDockerDesktop) {
        Write-Host "Cleaning unused Docker data..." -ForegroundColor Yellow
        docker system prune -a --volumes -f
    }
}
else {
    Write-Host "Docker is not available or Docker Desktop is not running. Skipping Docker cleanup." -ForegroundColor Yellow
}

Write-Host "Removing project folders..." -ForegroundColor Cyan
Remove-Item -Recurse -Force $RootDir -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $BadSystem32Dir -ErrorAction SilentlyContinue

if ($PurgeDockerDesktop) {
    Write-Host "Purging Docker Desktop..." -ForegroundColor Yellow

    winget uninstall --id Docker.DockerDesktop -e

    Remove-Item -Recurse -Force "$env:APPDATA\Docker" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Docker" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$env:PROGRAMDATA\Docker" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$env:PROGRAMDATA\DockerDesktop" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$env:USERPROFILE\.docker" -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Cleanup completed." -ForegroundColor Green
Write-Host ""
