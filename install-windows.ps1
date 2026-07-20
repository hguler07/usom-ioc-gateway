# USOM IOC Gateway - Windows Docker Installer
# Compatible with Windows PowerShell 5.1 and PowerShell 7+

$ErrorActionPreference = "Stop"

$BackendImage = "hguler07/usom-ioc-gateway:backend-0.1.16"
$NginxImage   = "hguler07/usom-ioc-gateway:nginx-0.1.19"
$DefaultPort  = "8080"

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

    $ComposeContent = [System.IO.File]::ReadAllText($ComposePath, [System.Text.Encoding]::UTF8)

    $ComposeContent = [Regex]::Replace(
        $ComposeContent,
        "(?m)^([ \t]*image:[ \t]*)hguler07/usom-ioc-gateway:backend[^ \t`r`n#]*",
        "`${1}$BackendImage"
    )

    $ComposeContent = [Regex]::Replace(
        $ComposeContent,
        "(?m)^([ \t]*image:[ \t]*)hguler07/usom-ioc-gateway:nginx[^ \t`r`n#]*",
        "`${1}$NginxImage"
    )

    [System.IO.File]::WriteAllText($ComposePath, $ComposeContent, $Utf8NoBom)

    $AdminUser = Get-DotEnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_USERNAME" -DefaultValue "admin"
    $AdminPassword = Get-DotEnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_PASSWORD" -DefaultValue ""
    $HttpPort = Get-DotEnvValue -Content $EnvContent -Name "TFG_HTTP_PORT" -DefaultValue $DefaultPort

    $ComposeArgs = @(
        "compose",
        "--project-name", "usom-ioc-gateway",
        "--project-directory", $ProjectPath,
        "--env-file", $EnvPath,
        "-f", $ComposePath
    )

    Write-Host "Checking Docker Compose config..." -ForegroundColor Cyan
    Invoke-DockerCommand -DockerArgs ($ComposeArgs + @("config"))

    Write-Host "Pulling Docker images..." -ForegroundColor Cyan
    Invoke-DockerCommand -DockerArgs ($ComposeArgs + @("pull"))

    Write-Host "Starting services..." -ForegroundColor Cyan
    Invoke-DockerCommand -DockerArgs ($ComposeArgs + @("up", "-d", "--remove-orphans"))

    Write-Host ""
    Write-Host "Container status:" -ForegroundColor Cyan
    Invoke-DockerCommand -DockerArgs ($ComposeArgs + @("ps"))

    Write-Host ""
    Write-Host "Installation completed successfully." -ForegroundColor Green
    Write-Host "URL           : http://localhost:$HttpPort"
    Write-Host "Username      : $AdminUser"
    Write-Host "Admin password: $AdminPassword" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If you see 502 on first startup, wait 1-2 minutes and refresh the page."
    Write-Host ""

    exit 0
}
catch {
    Write-Host ""
    Write-Host "INSTALLATION FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    exit 1
}
