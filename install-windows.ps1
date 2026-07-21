# USOM IOC Gateway - Windows Docker Installer
# Compatible with Windows PowerShell 5.1 and PowerShell 7+

$ErrorActionPreference = "Stop"

$DefaultPort  = "8080"

# When this script is executed directly from GitHub (irm ... | iex),
# prepare C:\USOM, download/update the repository, then run the local copy.
$InstallRoot = "C:\USOM"
$RepositoryPath = Join-Path $InstallRoot "usom-ioc-gateway"
$RepositoryUrl = "https://github.com/hguler07/usom-ioc-gateway.git"
$CurrentScriptPath = $MyInvocation.MyCommand.Path
$RunningFromLocalFile = `
    -not [string]::IsNullOrWhiteSpace($CurrentScriptPath) -and `
    (Test-Path -LiteralPath $CurrentScriptPath -PathType Leaf)

function Find-GitExecutable {
    $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue

    if ($null -ne $gitCommand) {
        return $gitCommand.Source
    }

    $candidates = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and `
            (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    return $null
}

function Install-GitIfMissing {
    $gitExecutable = Find-GitExecutable

    if (-not [string]::IsNullOrWhiteSpace($gitExecutable)) {
        return $gitExecutable
    }

    $wingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue

    if ($null -eq $wingetCommand) {
        throw "Git is not installed and Windows Package Manager (winget) is unavailable. Install Git for Windows first."
    }

    Write-Host "Git is not installed. Installing Git for Windows..." -ForegroundColor Cyan

    & $wingetCommand.Source install `
        --id Git.Git `
        --exact `
        --source winget `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent

    if ($LASTEXITCODE -ne 0) {
        throw "Git installation failed."
    }

    $gitExecutable = Find-GitExecutable

    if ([string]::IsNullOrWhiteSpace($gitExecutable)) {
        throw "Git was installed, but git.exe could not be found. Open a new PowerShell window and run the command again."
    }

    return $gitExecutable
}

function Start-RepositoryBootstrap {
    Write-Host "" 
    Write-Host "USOM IOC Gateway installation is being prepared..." -ForegroundColor Cyan

    # Avoid operating from a deleted, renamed, or locked repository directory.
    Set-Location -LiteralPath "C:\"

    New-Item -Path $InstallRoot -ItemType Directory -Force | Out-Null

    $gitExecutable = Install-GitIfMissing

    if (Test-Path -LiteralPath (Join-Path $RepositoryPath ".git") -PathType Container) {
        Write-Host "Existing installation found. Updating repository..." -ForegroundColor Cyan

        & $gitExecutable -C $RepositoryPath pull --ff-only

        if ($LASTEXITCODE -ne 0) {
            throw "Repository update failed. Check local changes or network access."
        }
    }
    else {
        if (Test-Path -LiteralPath $RepositoryPath) {
            $backupPath = "$RepositoryPath-old-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Write-Host "Incomplete project folder is being preserved as: $backupPath" -ForegroundColor Yellow
            Move-Item -LiteralPath $RepositoryPath -Destination $backupPath -Force
        }

        Write-Host "Downloading project from GitHub..." -ForegroundColor Cyan

        & $gitExecutable clone --branch main --single-branch $RepositoryUrl $RepositoryPath

        if ($LASTEXITCODE -ne 0) {
            throw "Repository download failed."
        }
    }

    $localInstaller = Join-Path $RepositoryPath "install-windows.ps1"

    if (-not (Test-Path -LiteralPath $localInstaller -PathType Leaf)) {
        throw "Local installer was not found: $localInstaller"
    }

    Write-Host "Starting local installer..." -ForegroundColor Green

    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $localInstaller

    if ($LASTEXITCODE -ne 0) {
        throw "USOM IOC Gateway installation failed."
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

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker command not found. Install Docker Desktop first."
    }

    Write-Host "Checking Docker Desktop..." -ForegroundColor Cyan
    & docker info *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "Docker Desktop is not running. Start Docker Desktop and try again."
    }

    & docker compose version *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose is not available. Update Docker Desktop."
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
