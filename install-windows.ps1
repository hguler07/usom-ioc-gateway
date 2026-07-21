# USOM IOC Gateway - Windows Docker Installer
# Compatible with Windows PowerShell 5.1 and PowerShell 7+

$ErrorActionPreference = "Stop"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}
catch {
    # TLS configuration is best effort on newer PowerShell versions.
}

function ConvertFrom-Utf8Base64 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return [System.Text.Encoding]::UTF8.GetString(
        [System.Convert]::FromBase64String($Value)
    )
}

# Keep the PowerShell source ASCII-only for Windows PowerShell 5.1.
# Turkish messages are decoded to Unicode only at runtime.
$TextExistingInstall = ConvertFrom-Utf8Base64 "RXNraSBiaXIgVVNPTSBJT0MgR2F0ZXdheSBrdXJ1bHVtdSB2ZXlhIERvY2tlciBrYWzEsW50xLFsYXLEsSBidWx1bmR1Lg=="
$TextCleanWarning = ConvertFrom-Utf8Base64 "VGVtaXoga3VydWx1bTsgZXNraSB2ZXJpdGFiYW7EsW7EsSwgZmVlZGxlcmksIGNvbnRhaW5lcmxhcsSxLCBhxJ/EsSB2ZSDDvHJldGlsZW4gxZ9pZnJlbGVyaSBzaWxlci4="
$TextCleanPrompt = ConvertFrom-Utf8Base64 "VGVtaXoga3VydWx1bSB5YXDEsWxzxLFuIG3EsT8gW0UvSF0="
$TextCleanAnswer = ConvertFrom-Utf8Base64 "RXZldCBpw6dpbiBFLCBIYXnEsXIgacOnaW4gSCBnaXJpbi4="
$TextCleaning = ConvertFrom-Utf8Base64 "RXNraSBVU09NIElPQyBHYXRld2F5IERvY2tlciBrYXluYWtsYXLEsSB0ZW1pemxlbml5b3IuLi4="
$TextCleanComplete = ConvertFrom-Utf8Base64 "RXNraSBrdXJ1bHVtIHZlcmlsZXJpIHNpbGluZGkuIFRlbWl6IGt1cnVsdW0gb2x1xZ90dXJ1bGFjYWsu"

$DefaultPort  = "8080"

# When this script is executed directly from GitHub (irm ... | iex),
# prepare C:\USOM, download the repository as a ZIP archive, then run the
# local copy. Git is not required.
$InstallRoot = "C:\USOM"
$RepositoryPath = Join-Path $InstallRoot "usom-ioc-gateway"
$RepositoryArchiveUrl = "https://github.com/hguler07/usom-ioc-gateway/archive/refs/heads/main.zip"
$RepositoryArchiveFolder = "usom-ioc-gateway-main"
$CurrentScriptPath = $MyInvocation.MyCommand.Path

# Some Windows profiles contain a stale or invalid 8.3 TEMP path
# (for example C:\Users\XXXXXX~1.XXX). Use a predictable installer-owned
# temporary directory so ZIP extraction and prerequisite installers do not
# depend on the user's TEMP/TMP configuration.
$InstallerTempRoot = Join-Path $InstallRoot ".installer-temp"
New-Item -Path $InstallerTempRoot -ItemType Directory -Force | Out-Null
$env:TEMP = $InstallerTempRoot
$env:TMP = $InstallerTempRoot
$RunningFromLocalFile = `
    -not [string]::IsNullOrWhiteSpace($CurrentScriptPath) -and `
    (Test-Path -LiteralPath $CurrentScriptPath -PathType Leaf)

function Invoke-DownloadFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [long]$MinimumBytes = 1024
    )

    $destinationDirectory = Split-Path -Parent $Destination

    if (-not [string]::IsNullOrWhiteSpace($destinationDirectory)) {
        New-Item -Path $destinationDirectory -ItemType Directory -Force | Out-Null
    }

    Invoke-WebRequest `
        -Uri $Uri `
        -OutFile $Destination `
        -UseBasicParsing `
        -Headers @{ "User-Agent" = "USOM-IOC-Gateway-Installer" } `
        -ErrorAction Stop | Out-Null

    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
        throw "Downloaded file was not created: $Destination"
    }

    if ((Get-Item -LiteralPath $Destination).Length -lt $MinimumBytes) {
        throw "Downloaded file is unexpectedly small: $Destination"
    }
}

function Start-RepositoryBootstrap {
    Write-Host ""
    Write-Host "USOM IOC Gateway installation is being prepared..." -ForegroundColor Cyan

    # Avoid operating from a deleted, renamed, or locked project directory.
    Set-Location -LiteralPath "C:\"

    New-Item -Path $InstallRoot -ItemType Directory -Force | Out-Null

    $operationId = [Guid]::NewGuid().ToString("N")
    $archivePath = Join-Path $InstallerTempRoot "usom-ioc-gateway-$operationId.zip"
    $extractPath = Join-Path $InstallerTempRoot "usom-ioc-gateway-$operationId"
    $preservedEnvPath = Join-Path $InstallerTempRoot "usom-ioc-gateway-$operationId.env"
    $existingEnvPath = Join-Path $RepositoryPath ".env"

    try {
        # Preserve generated passwords while refreshing the installation files.
        # The local installer still asks whether a clean installation is wanted.
        if (Test-Path -LiteralPath $existingEnvPath -PathType Leaf) {
            Copy-Item `
                -LiteralPath $existingEnvPath `
                -Destination $preservedEnvPath `
                -Force
        }

        Write-Host "Downloading project package from GitHub..." -ForegroundColor Cyan
        Invoke-DownloadFile `
            -Uri $RepositoryArchiveUrl `
            -Destination $archivePath `
            -MinimumBytes 1024

        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

        Write-Host "Extracting project package..." -ForegroundColor Cyan

        # Do not use Expand-Archive here. On some Windows PowerShell 5.1
        # installations the Microsoft.PowerShell.Archive module tries to
        # resolve a stale 8.3 user-profile path and fails before extraction.
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        if (Test-Path -LiteralPath $extractPath) {
            Remove-Item -LiteralPath $extractPath -Recurse -Force
        }

        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

        [System.IO.Compression.ZipFile]::ExtractToDirectory(
            $archivePath,
            $extractPath
        )

        $extractedRepository = Join-Path $extractPath $RepositoryArchiveFolder

        if (-not (Test-Path -LiteralPath $extractedRepository -PathType Container)) {
            throw "The expected project folder was not found in the downloaded ZIP package."
        }

        foreach ($requiredFile in @(
            "install-windows.ps1",
            "compose.yaml",
            ".env.example"
        )) {
            $requiredPath = Join-Path $extractedRepository $requiredFile

            if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
                throw "The downloaded project package is incomplete. Missing file: $requiredFile"
            }
        }

        if (Test-Path -LiteralPath $RepositoryPath) {
            Write-Host "Refreshing local installation files..." -ForegroundColor Cyan
            Remove-Item -LiteralPath $RepositoryPath -Recurse -Force
        }

        Move-Item `
            -LiteralPath $extractedRepository `
            -Destination $RepositoryPath `
            -Force

        if (Test-Path -LiteralPath $preservedEnvPath -PathType Leaf) {
            Copy-Item `
                -LiteralPath $preservedEnvPath `
                -Destination (Join-Path $RepositoryPath ".env") `
                -Force
        }

        $localInstaller = Join-Path $RepositoryPath "install-windows.ps1"

        # Windows PowerShell 5.1 treats UTF-8 files without a BOM as ANSI.
        # Normalize the extracted local installer before running it so Turkish
        # characters remain correct even if the repository editor removed BOM.
        $localInstallerContent = [System.IO.File]::ReadAllText(
            $localInstaller,
            [System.Text.Encoding]::UTF8
        )
        $Utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText(
            $localInstaller,
            $localInstallerContent,
            $Utf8WithBom
        )

        Write-Host "Starting local installer..." -ForegroundColor Green

        & powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $localInstaller

        if ($LASTEXITCODE -ne 0) {
            throw "USOM IOC Gateway installation failed."
        }
    }
    finally {
        Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $preservedEnvPath -Force -ErrorAction SilentlyContinue

        if (Test-Path -LiteralPath $InstallerTempRoot -PathType Container) {
            $remainingItems = @(Get-ChildItem -LiteralPath $InstallerTempRoot -Force -ErrorAction SilentlyContinue)

            if ($remainingItems.Count -eq 0) {
                Remove-Item -LiteralPath $InstallerTempRoot -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

if (-not $RunningFromLocalFile) {
    try {
        Start-RepositoryBootstrap
    }
    catch {
        Write-Host ""
        Write-Host "INSTALLATION FAILED" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
    }

    return
}

function New-RandomHex {
    param(
        [int]$ByteLength = 32
    )

    $bytes = New-Object byte[] $ByteLength
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        $rng.GetBytes($bytes)
    }
    finally {
        $rng.Dispose()
    }

    return -join ($bytes | ForEach-Object { $_.ToString("x2") })
}

function Set-DotEnvValue {
    param(
        [string]$Content,
        [string]$Name,
        [string]$Value,
        [bool]$OnlyIfEmptyOrPlaceholder = $false
    )

    if ($null -eq $Content) {
        $Content = ""
    }

    $lines = @()
    if ($Content.Length -gt 0) {
        $lines = $Content -split "`r?`n"
    }

    $output = New-Object System.Collections.Generic.List[string]
    $found = $false
    $existingValue = ""

    foreach ($line in $lines) {
        if ($line -match "^[ \t]*$([Regex]::Escape($Name))[ \t]*=") {
            if (-not $found) {
                $found = $true
                $existingValue = ($line -replace "^[ \t]*$([Regex]::Escape($Name))[ \t]*=", "").Trim().Trim('"').Trim("'")

                if ($OnlyIfEmptyOrPlaceholder -and `
                    -not [string]::IsNullOrWhiteSpace($existingValue) -and `
                    $existingValue -ne "CHANGE_ME" -and `
                    $existingValue -ne "CHANGEME" -and `
                    $existingValue -ne "REPLACE_ME") {
                    $output.Add("$Name=$existingValue")
                }
                else {
                    $output.Add("$Name=$Value")
                }
            }

            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $output.Add($line)
        }
    }

    if (-not $found) {
        $output.Add("$Name=$Value")
    }

    return (($output.ToArray()) -join "`r`n") + "`r`n"
}

function Get-DotEnvValue {
    param(
        [string]$Content,
        [string]$Name,
        [string]$DefaultValue = ""
    )

    if ($null -eq $Content) {
        return $DefaultValue
    }

    foreach ($line in ($Content -split "`r?`n")) {
        if ($line -match "^[ \t]*$([Regex]::Escape($Name))[ \t]*=") {
            return (($line -replace "^[ \t]*$([Regex]::Escape($Name))[ \t]*=", "").Trim().Trim('"').Trim("'"))
        }
    }

    return $DefaultValue
}

function Invoke-DockerCommand {
    param(
        [string[]]$DockerArgs
    )

    & docker @DockerArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed: docker $($DockerArgs -join ' ')"
    }
}


function Find-DockerExecutable {
    $dockerCommand = Get-Command docker.exe -ErrorAction SilentlyContinue

    if ($null -ne $dockerCommand) {
        return $dockerCommand.Source
    }

    $candidates = @(
        "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
        "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe"
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and
            (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    return $null
}

function Find-DockerDesktopExecutable {
    $candidates = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and
            (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    return $null
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Ensure-WslForDocker {
    $wslCommand = Get-Command wsl.exe -ErrorAction SilentlyContinue

    if ($null -eq $wslCommand) {
        throw "WSL is unavailable on this Windows version. Update Windows before installing Docker Desktop."
    }

    & $wslCommand.Source --version *> $null
    $wslAvailable = ($LASTEXITCODE -eq 0)

    if (-not $wslAvailable) {
        if (-not (Test-IsAdministrator)) {
            throw "WSL is not installed. Open PowerShell as Administrator and run the same installation command again."
        }

        Write-Host "WSL is not installed. Installing WSL 2..." -ForegroundColor Cyan

        $wslOutput = & $wslCommand.Source --install --no-distribution 2>&1
        $wslExitCode = $LASTEXITCODE
        $wslOutput | Out-Host

        if ($wslExitCode -ne 0) {
            throw "WSL installation failed."
        }

        Write-Host ""
        Write-Host "WSL was installed. Restart Windows, then run the same installation command again." -ForegroundColor Yellow
        throw "Windows restart is required before Docker Desktop can be installed."
    }

    Write-Host "Updating WSL..." -ForegroundColor Cyan
    & $wslCommand.Source --update *> $null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "WSL update could not be completed. Continuing with the installed WSL version." -ForegroundColor Yellow
    }

    & $wslCommand.Source --set-default-version 2 *> $null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "WSL default version could not be set automatically. Docker Desktop will verify it during startup." -ForegroundColor Yellow
    }
}

function Install-DockerDesktopFromOfficialSource {
    $installerPath = Join-Path $InstallerTempRoot "Docker-Desktop-Installer.exe"
    $downloadUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"

    try {
        Write-Host "Downloading Docker Desktop from Docker's official server..." -ForegroundColor Cyan
        Invoke-DownloadFile `
            -Uri $downloadUrl `
            -Destination $installerPath `
            -MinimumBytes 10MB

        Write-Host "Installing Docker Desktop with the WSL 2 backend..." -ForegroundColor Cyan

        $process = Start-Process `
            -FilePath $installerPath `
            -ArgumentList @(
                "install",
                "--user",
                "--accept-license",
                "--backend=wsl-2",
                "--quiet"
            ) `
            -Wait `
            -PassThru

        if ($process.ExitCode -ne 0) {
            throw "Docker Desktop installer returned exit code $($process.ExitCode)."
        }
    }
    finally {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}

function Install-DockerDesktopIfMissing {
    $dockerExecutable = Find-DockerExecutable

    if (-not [string]::IsNullOrWhiteSpace($dockerExecutable)) {
        return $dockerExecutable
    }

    Write-Host "Docker Desktop is not installed." -ForegroundColor Yellow
    Ensure-WslForDocker

    $wingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue
    $wingetSucceeded = $false

    if ($null -ne $wingetCommand) {
        Write-Host "Trying Docker Desktop installation with Windows Package Manager..." -ForegroundColor Cyan

        $wingetOutput = & $wingetCommand.Source install `
            --id Docker.DockerDesktop `
            --exact `
            --source winget `
            --accept-package-agreements `
            --accept-source-agreements `
            --silent 2>&1

        $wingetExitCode = $LASTEXITCODE
        $wingetOutput | Out-Host
        $wingetSucceeded = ($wingetExitCode -eq 0)

        if (-not $wingetSucceeded) {
            Write-Host "winget installation was not successful. Official direct download will be used." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "winget is unavailable. Official Docker download will be used." -ForegroundColor Yellow
    }

    if ($wingetSucceeded) {
        Start-Sleep -Seconds 3
        $dockerExecutable = Find-DockerExecutable

        if (-not [string]::IsNullOrWhiteSpace($dockerExecutable)) {
            Write-Host "Docker Desktop installed successfully." -ForegroundColor Green
            return $dockerExecutable
        }

        Write-Host "winget reported success, but docker.exe was not found. Official direct download will be tried." -ForegroundColor Yellow
    }

    Install-DockerDesktopFromOfficialSource
    Start-Sleep -Seconds 3

    $dockerExecutable = Find-DockerExecutable

    if ([string]::IsNullOrWhiteSpace($dockerExecutable)) {
        throw "Docker Desktop installation completed, but docker.exe could not be found."
    }

    Write-Host "Docker Desktop installed successfully." -ForegroundColor Green
    return $dockerExecutable
}

function Wait-DockerEngine {
    param(
        [int]$TimeoutSeconds = 360
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        & docker info *> $null

        if ($LASTEXITCODE -eq 0) {
            return $true
        }

        Start-Sleep -Seconds 5
    }
    while ((Get-Date) -lt $deadline)

    return $false
}

function Ensure-DockerEnvironment {
    $dockerExecutable = Install-DockerDesktopIfMissing

    $dockerDirectory = Split-Path -Parent $dockerExecutable
    if ($env:PATH -notlike "*$dockerDirectory*") {
        $env:PATH = "$dockerDirectory;$env:PATH"
    }

    & docker info *> $null

    if ($LASTEXITCODE -ne 0) {
        $desktopExecutable = Find-DockerDesktopExecutable

        if ([string]::IsNullOrWhiteSpace($desktopExecutable)) {
            throw "Docker Desktop is installed, but Docker Desktop.exe could not be found."
        }

        Write-Host "Starting Docker Desktop..." -ForegroundColor Cyan
        Start-Process -FilePath $desktopExecutable | Out-Null

        if (-not (Wait-DockerEngine -TimeoutSeconds 360)) {
            throw "Docker Desktop did not become ready within 6 minutes. A Windows restart or first-run confirmation may be required."
        }
    }

    & docker compose version *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose is unavailable. Update Docker Desktop."
    }

    Write-Host "Docker Desktop is ready." -ForegroundColor Green
}

function Test-DockerObjectExists {
    param(
        [ValidateSet("volume", "network")]
        [string]$ObjectType,

        [string]$Name
    )

    # A missing Docker object is a normal result during a clean installation.
    # List existing names instead of calling `docker ... inspect` for an object
    # that may not exist. This avoids PowerShell converting Docker's native
    # "no such volume/network" stderr response into a terminating error.
    try {
        $existingNames = switch ($ObjectType) {
            "volume" {
                @(& docker volume ls --format '{{.Name}}' 2>$null)
            }
            "network" {
                @(& docker network ls --format '{{.Name}}' 2>$null)
            }
        }

        foreach ($existingName in @($existingNames)) {
            if (-not [string]::IsNullOrWhiteSpace("$existingName") -and
                "$existingName".Trim() -eq $Name) {
                return $true
            }
        }
    }
    catch {
        # The main prerequisite check already verified Docker readiness. A
        # lookup failure here is treated as "object not present".
    }

    return $false
}

function Test-ExistingInstallation {
    param(
        [string]$EnvPath
    )

    if (Test-Path -LiteralPath $EnvPath -PathType Leaf) {
        return $true
    }

    $containerIds = @()

    try {
        $containerIds = @(
            & docker ps -aq --filter "label=com.docker.compose.project=usom-ioc-gateway" 2>$null
        )
    }
    catch {
        $containerIds = @()
    }

    if ($containerIds.Count -gt 0) {
        return $true
    }

    if (Test-DockerObjectExists -ObjectType "volume" -Name "usom-ioc-gateway_postgres_data") {
        return $true
    }

    if (Test-DockerObjectExists -ObjectType "volume" -Name "usom-ioc-gateway_feeds_data") {
        return $true
    }

    if (Test-DockerObjectExists -ObjectType "network" -Name "usom-ioc-gateway_default") {
        return $true
    }

    return $false
}

function Read-CleanInstallChoice {
    Write-Host ""
    Write-Host $TextExistingInstall -ForegroundColor Yellow
    Write-Host $TextCleanWarning -ForegroundColor Yellow

    while ($true) {
        $answer = (Read-Host $TextCleanPrompt).Trim().ToUpperInvariant()

        switch ($answer) {
            "E" { return $true }
            "Y" { return $true }
            "H" { return $false }
            "N" { return $false }
            default {
                Write-Host $TextCleanAnswer -ForegroundColor Yellow
            }
        }
    }
}

function Remove-ExistingInstallation {
    param(
        [string]$EnvPath
    )

    Write-Host $TextCleaning -ForegroundColor Cyan

    $containerIds = @()

    try {
        $containerIds = @(
            & docker ps -aq --filter "label=com.docker.compose.project=usom-ioc-gateway" 2>$null
        )
    }
    catch {
        $containerIds = @()
    }

    if ($containerIds.Count -gt 0) {
        & docker rm -f @containerIds *> $null

        if ($LASTEXITCODE -ne 0) {
            throw "Old USOM IOC Gateway containers could not be removed."
        }
    }

    foreach ($volumeName in @(
        "usom-ioc-gateway_postgres_data",
        "usom-ioc-gateway_feeds_data"
    )) {
        if (Test-DockerObjectExists -ObjectType "volume" -Name $volumeName) {
            & docker volume rm -f $volumeName *> $null

            if ($LASTEXITCODE -ne 0) {
                throw "Docker volume could not be removed: $volumeName"
            }
        }
    }

    if (Test-DockerObjectExists -ObjectType "network" -Name "usom-ioc-gateway_default") {
        & docker network rm "usom-ioc-gateway_default" *> $null

        if ($LASTEXITCODE -ne 0) {
            throw "Old Docker network could not be removed."
        }
    }

    Remove-Item -LiteralPath $EnvPath -Force -ErrorAction SilentlyContinue

    Write-Host $TextCleanComplete -ForegroundColor Green
}

function Wait-PostgresReady {
    param(
        [string[]]$ComposeArgs,
        [int]$TimeoutSeconds = 120
    )

    Write-Host "Waiting for PostgreSQL to become ready..." -ForegroundColor Cyan
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        & docker @($ComposeArgs + @(
            "exec",
            "-T",
            "db",
            "pg_isready",
            "-U", "threatfeed",
            "-d", "threatfeed"
        )) *> $null

        if ($LASTEXITCODE -eq 0) {
            return $true
        }

        Start-Sleep -Seconds 2
    }
    while ((Get-Date) -lt $deadline)

    return $false
}

function Sync-PostgresPassword {
    param(
        [string[]]$ComposeArgs,
        [string]$PostgresUser,
        [string]$PostgresDatabase,
        [string]$PostgresPassword
    )

    if ([string]::IsNullOrWhiteSpace($PostgresUser)) {
        throw "POSTGRES_USER is empty."
    }

    if ([string]::IsNullOrWhiteSpace($PostgresDatabase)) {
        throw "POSTGRES_DB is empty."
    }

    if ([string]::IsNullOrWhiteSpace($PostgresPassword)) {
        throw "POSTGRES_PASSWORD is empty."
    }

    Write-Host "Synchronizing the PostgreSQL application password..." -ForegroundColor Cyan

    # Send SQL directly to psql through standard input. This avoids the nested
    # PowerShell -> Docker -> sh -> psql quoting problem.
    $SafeRoleName = $PostgresUser.Replace('"', '""')
    $SafePassword = $PostgresPassword.Replace("'", "''")
    $SqlStatement = "ALTER ROLE `"$SafeRoleName`" WITH PASSWORD '$SafePassword';"

    $SqlStatement | & docker @($ComposeArgs + @(
        "exec",
        "-T",
        "db",
        "psql",
        "-U", $PostgresUser,
        "-d", $PostgresDatabase,
        "-v", "ON_ERROR_STOP=1"
    )) *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL password synchronization failed."
    }

    # Validate the same TCP/password authentication method used by Django.
    & docker @($ComposeArgs + @(
        "exec",
        "-T",
        "db",
        "env",
        "PGPASSWORD=$PostgresPassword",
        "psql",
        "-h", "127.0.0.1",
        "-U", $PostgresUser,
        "-d", $PostgresDatabase,
        "-v", "ON_ERROR_STOP=1",
        "-tAc", "SELECT 1"
    )) *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL password validation failed after synchronization."
    }

    Write-Host "PostgreSQL password synchronized successfully." -ForegroundColor Green
}

function Sync-DjangoAdmin {
    param(
        [string[]]$ComposeArgs
    )

    Write-Host "Synchronizing the Django administrator credentials..." -ForegroundColor Cyan

    # Run a standalone Python script through standard input. This does not rely
    # on manage.py shell supporting the -c/--command option.
    $PythonCode = @'
import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "threatfeed.settings")

import django
django.setup()

from django.contrib.auth import get_user_model

User = get_user_model()
username = os.environ.get("DJANGO_SUPERUSER_USERNAME", "admin")
password = os.environ.get("DJANGO_SUPERUSER_PASSWORD", "")
email = os.environ.get("DJANGO_SUPERUSER_EMAIL", "")

if not password:
    raise RuntimeError("DJANGO_SUPERUSER_PASSWORD is empty")

user, _ = User.objects.get_or_create(
    username=username,
    defaults={"email": email},
)

if email:
    user.email = email

user.is_active = True
user.is_staff = True
user.is_superuser = True
user.set_password(password)
user.save()

if not user.check_password(password):
    raise RuntimeError("Administrator password verification failed")

print("Administrator credentials synchronized.")
'@

    $PythonCode | & docker @($ComposeArgs + @(
        "exec",
        "-T",
        "web",
        "python",
        "-"
    )) *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "Django administrator credential synchronization failed."
    }

    Write-Host "Administrator credentials synchronized successfully." -ForegroundColor Green
}

function Wait-ApplicationReady {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 240
    )

    Write-Host "Waiting for the web application to become ready..." -ForegroundColor Cyan

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        try {
            $response = Invoke-WebRequest `
                -Uri $Url `
                -UseBasicParsing `
                -TimeoutSec 5 `
                -ErrorAction Stop

            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                return $true
            }
        }
        catch {
            # The service may still be running migrations or starting Gunicorn.
        }

        Start-Sleep -Seconds 3
    }
    while ((Get-Date) -lt $deadline)

    return $false
}

function Show-StartupDiagnostics {
    param(
        [string[]]$ComposeArgs
    )

    if ($null -eq $ComposeArgs -or $ComposeArgs.Count -eq 0) {
        return
    }

    Write-Host ""
    Write-Host "Container status:" -ForegroundColor Yellow
    & docker @($ComposeArgs + @("ps", "-a"))

    Write-Host ""
    Write-Host "Startup logs:" -ForegroundColor Yellow
    & docker @($ComposeArgs + @(
        "logs",
        "--tail=150",
        "db",
        "feeds-init",
        "web",
        "nginx"
    ))
}

$ComposeArgs = $null

try {
    Write-Host ""
    Write-Host "USOM IOC Gateway Windows installer starting..." -ForegroundColor Cyan

    $ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        throw "Project path could not be detected."
    }

    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path

    if ($ProjectPath.ToLower().StartsWith("c:\windows\system32")) {
        throw "Do not install under C:\Windows\System32. Use C:\USOM\usom-ioc-gateway."
    }

    Set-Location -LiteralPath $ProjectPath

    $ComposePath = Join-Path $ProjectPath "compose.yaml"
    $EnvExamplePath = Join-Path $ProjectPath ".env.example"
    $EnvPath = Join-Path $ProjectPath ".env"

    Write-Host "Project path: $ProjectPath" -ForegroundColor DarkGray

    if (-not (Test-Path -LiteralPath $ComposePath -PathType Leaf)) {
        throw "compose.yaml not found. Run this script inside the repository folder."
    }

    if (-not (Test-Path -LiteralPath $EnvExamplePath -PathType Leaf)) {
        throw ".env.example not found. Run this script inside the repository folder."
    }

    Write-Host "Checking Windows prerequisites..." -ForegroundColor Cyan
    Ensure-DockerEnvironment

    if (Test-ExistingInstallation -EnvPath $EnvPath) {
        $cleanInstall = Read-CleanInstallChoice

        if ($cleanInstall) {
            Remove-ExistingInstallation -EnvPath $EnvPath
        }
        else {
            Write-Host "Existing installation data will be preserved and repaired where possible." -ForegroundColor DarkGray
        }
    }

    if (-not (Test-Path -LiteralPath $EnvPath -PathType Leaf)) {
        Copy-Item -LiteralPath $EnvExamplePath -Destination $EnvPath -Force
        Write-Host ".env file created." -ForegroundColor Green
    }
    elseif ((Get-Item -LiteralPath $EnvPath).Length -eq 0) {
        Copy-Item -LiteralPath $EnvExamplePath -Destination $EnvPath -Force
        Write-Host ".env file recreated because it was empty." -ForegroundColor Green
    }
    else {
        Write-Host ".env already exists. Existing passwords will be preserved." -ForegroundColor DarkGray
    }

    $EnvContent = [System.IO.File]::ReadAllText($EnvPath, [System.Text.Encoding]::UTF8)

    $EnvContent = Set-DotEnvValue -Content $EnvContent -Name "SECRET_KEY" -Value (New-RandomHex -ByteLength 32) -OnlyIfEmptyOrPlaceholder $true
    $EnvContent = Set-DotEnvValue -Content $EnvContent -Name "POSTGRES_PASSWORD" -Value (New-RandomHex -ByteLength 32) -OnlyIfEmptyOrPlaceholder $true
    $EnvContent = Set-DotEnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_PASSWORD" -Value (New-RandomHex -ByteLength 24) -OnlyIfEmptyOrPlaceholder $true
    $EnvContent = Set-DotEnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_USERNAME" -Value "admin" -OnlyIfEmptyOrPlaceholder $true
    $EnvContent = Set-DotEnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_EMAIL" -Value "admin@example.local" -OnlyIfEmptyOrPlaceholder $true
    $EnvContent = Set-DotEnvValue -Content $EnvContent -Name "TFG_HTTP_PORT" -Value $DefaultPort -OnlyIfEmptyOrPlaceholder $false

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($EnvPath, $EnvContent, $Utf8NoBom)


    $AdminUser = Get-DotEnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_USERNAME" -DefaultValue "admin"
    $AdminPassword = Get-DotEnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_PASSWORD" -DefaultValue ""
    $HttpPort = Get-DotEnvValue -Content $EnvContent -Name "TFG_HTTP_PORT" -DefaultValue $DefaultPort
    $PostgresUser = Get-DotEnvValue -Content $EnvContent -Name "POSTGRES_USER" -DefaultValue "threatfeed"
    $PostgresDatabase = Get-DotEnvValue -Content $EnvContent -Name "POSTGRES_DB" -DefaultValue "threatfeed"
    $PostgresPassword = Get-DotEnvValue -Content $EnvContent -Name "POSTGRES_PASSWORD" -DefaultValue ""

    $ComposeArgs = @(
        "compose",
        "--project-name", "usom-ioc-gateway",
        "--project-directory", $ProjectPath,
        "--env-file", $EnvPath,
        "-f", $ComposePath
    )

    Write-Host "Checking Docker Compose config..." -ForegroundColor Cyan
    & docker @($ComposeArgs + @("config", "--quiet")) *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose configuration is invalid."
    }

    Write-Host "Pulling Docker images..." -ForegroundColor Cyan
    Invoke-DockerCommand -DockerArgs ($ComposeArgs + @("pull"))

    # Start PostgreSQL first. If an old Docker volume survived while .env was
    # recreated, align the database role password with the current .env without
    # deleting the database.
    Write-Host "Starting PostgreSQL..." -ForegroundColor Cyan
    Invoke-DockerCommand -DockerArgs ($ComposeArgs + @("up", "-d", "db", "feeds-init"))

    if (-not (Wait-PostgresReady -ComposeArgs $ComposeArgs -TimeoutSeconds 120)) {
        throw "PostgreSQL did not become ready within 120 seconds."
    }

    Sync-PostgresPassword `
        -ComposeArgs $ComposeArgs `
        -PostgresUser $PostgresUser `
        -PostgresDatabase $PostgresDatabase `
        -PostgresPassword $PostgresPassword

    Write-Host "Starting application services..." -ForegroundColor Cyan
    Invoke-DockerCommand -DockerArgs ($ComposeArgs + @("up", "-d", "--remove-orphans"))

    $ApplicationUrl = "http://localhost:$HttpPort"

    if (-not (Wait-ApplicationReady -Url $ApplicationUrl -TimeoutSeconds 240)) {
        throw "The web application did not become ready within 240 seconds."
    }

    # Keep the administrator account in the database aligned with the password
    # displayed by this installer. This also repairs installations that reused
    # an older PostgreSQL volume with a previously created admin account.
    Sync-DjangoAdmin -ComposeArgs $ComposeArgs

    Write-Host ""
    Write-Host "Container status:" -ForegroundColor Cyan
    Invoke-DockerCommand -DockerArgs ($ComposeArgs + @("ps"))

    Write-Host ""
    Write-Host "Installation completed successfully." -ForegroundColor Green
    Write-Host "URL           : $ApplicationUrl"
    Write-Host "Username      : $AdminUser"
    Write-Host "Admin password: $AdminPassword" -ForegroundColor Yellow
    Write-Host ""

    exit 0
}
catch {
    Write-Host ""
    Write-Host "INSTALLATION FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ($null -ne $ComposeArgs) {
        Show-StartupDiagnostics -ComposeArgs $ComposeArgs
    }

    Write-Host ""
    exit 1
}
