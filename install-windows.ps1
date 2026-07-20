@'
# USOM IOC Gateway - Windows Docker Installer
# Compatible with Windows PowerShell 5.1 and PowerShell 7+

$ErrorActionPreference = "Stop"

$BackendImage = "hguler07/usom-ioc-gateway:backend-0.1.16"
$NginxImage   = "hguler07/usom-ioc-gateway:nginx-0.1.18"

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

function Set-EnvValue {
    param(
        [string]$Content,
        [string]$Name,
        [string]$Value,
        [bool]$OnlyIfMissingOrPlaceholder = $false
    )

    $escapedName = [Regex]::Escape($Name)
    $pattern = "(?m)^[ \t]*$escapedName[ \t]*=.*$"
    $match = [Regex]::Match($Content, $pattern)

    if ($match.Success) {
        $currentLine = $match.Value
        $currentValue = ""

        if ($currentLine.Contains("=")) {
            $currentValue = $currentLine.Substring($currentLine.IndexOf("=") + 1).Trim().Trim('"').Trim("'")
        }

        if ($OnlyIfMissingOrPlaceholder -and `
            -not [string]::IsNullOrWhiteSpace($currentValue) -and `
            $currentValue -ne "CHANGE_ME" -and `
            $currentValue -ne "CHANGEME" -and `
            $currentValue -ne "REPLACE_ME") {
            return $Content
        }

        return [Regex]::Replace($Content, $pattern, "$Name=$Value")
    }

    if (-not $Content.EndsWith("`n") -and $Content.Length -gt 0) {
        $Content += "`r`n"
    }

    return $Content + "$Name=$Value`r`n"
}

function Get-EnvValue {
    param(
        [string]$Content,
        [string]$Name,
        [string]$DefaultValue = ""
    )

    $escapedName = [Regex]::Escape($Name)
    $pattern = "(?m)^[ \t]*$escapedName[ \t]*=(.*)$"
    $match = [Regex]::Match($Content, $pattern)

    if (-not $match.Success) {
        return $DefaultValue
    }

    return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Invoke-Docker {
    param(
        [string[]]$Arguments
    )

    & docker @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed: docker $($Arguments -join ' ')"
    }
}

try {
    Write-EXITCODE -ne 0) {
        throw "Docker command failed: docker $($Arguments -join ' ')"
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
        throw "Do not install under C:\Windows\System32. Use a folder like C:\USOM\usom-ioc-gateway."
    }

    Set-Location -LiteralPath $ProjectPath

    $ComposePath = Join-Path $ProjectPath "compose.yaml"
    $EnvExamplePath = Join-Path $ProjectPath ".env.example"
    $EnvPath = Join-Path $ProjectPath ".env"

    Write-Host "Project path: $ProjectPath" -ForegroundColor DarkGray

    if (-not (Test-Path -LiteralPath $ComposePath -PathType Leaf)) {
        throw "compose.yaml not found."
    }

    if (-not (Test-Path -LiteralPath $EnvExamplePath -PathType Leaf)) {
        throw ".env.example not found."
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
        throw "Docker Compose is not available."
    }

    if (-not (Test-Path -LiteralPath $EnvPath -PathType Leaf) -or (Get-Item -LiteralPath $EnvPath).Length -eq 0) {
        Copy-Item -LiteralPath $EnvExamplePath -Destination $EnvPath -Force
        Write-Host ".env file created." -ForegroundColor Green
    }
    else {
        Write-Host ".env already exists. Existing values will be preserved." -ForegroundColor DarkGray
    }

    $EnvContent = [System.IO.File]::ReadAllText($EnvPath, [System.Text.Encoding]::UTF8)

    if ([string]::IsNullOrWhiteSpace($EnvContent)) {
        $EnvContent = ""
    }

    $EnvContent = Set-EnvValue -Content $EnvContent -Name "SECRET_KEY" -Value (New-RandomHex -ByteLength 32) -OnlyIfMissingOrPlaceholder $true
    $EnvContent = Set-EnvValue -Content $EnvContent -Name "POSTGRES_PASSWORD" -Value (New-RandomHex -ByteLength 32) -OnlyIfMissingOrPlaceholder $true
    $EnvContent = Set-EnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_PASSWORD" -Value (New-RandomHex -ByteLength 24) -OnlyIfMissingOrPlaceholder $true
    $EnvContent = Set-EnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_USERNAME" -Value "admin" -OnlyIfMissingOrPlaceholder $true
    $EnvContent = Set-EnvValue -Content $EnvContent -Name "TFG_HTTP_PORT" -Value "8080" -OnlyIfMissingOrPlaceholder $false

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($EnvPath, $EnvContent, $Utf8NoBom)

    $ComposeContent = [System.IO.File]::ReadAllText($ComposePath, [System.Text.Encoding]::UTF8)
    $ComposeContent = $ComposeContent -replace "hguler07/usom-ioc-gateway:backend-[0-9]+\.[0-9]+\.[0-9]+", $BackendImage
    $ComposeContent = $ComposeContent -replace "hguler07/usom-ioc-gateway:nginx-[0-9]+\.[0-9]+\.[0-9]+", $NginxImage
    [System.IO.File]::WriteAllText($ComposePath, $ComposeContent, $Utf8NoBom)

    $AdminUser = Get-EnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_USERNAME" -DefaultValue "admin"
    $AdminPassword = Get-EnvValue -Content $EnvContent -Name "DJANGO_SUPERUSER_PASSWORD" -DefaultValue ""
    $HttpPort = Get-EnvValue -Content $EnvContent -Name "TFG_HTTP_PORT" -DefaultValue "8080"

    $ComposeArgs = @(
        "compose",
        "--project-name", "usom-ioc-gateway",
        "--project-directory", $ProjectPath,
        "--env-file", $EnvPath,
        "-f", $ComposePath
    )

    Write-Host "Checking Docker Compose config..." -ForegroundColor Cyan
    Invoke-Docker -Arguments ($ComposeArgs + @("config", "--quiet"))

    Write-Host "Pulling Docker images..." -ForegroundColor Cyan
    Invoke-Docker -Arguments ($ComposeArgs + @("pull"))

    Write-Host "Starting services..." -ForegroundColor Cyan
    Invoke-Docker -Arguments ($ComposeArgs + @("up", "-d", "--remove-orphans"))

    Write-Host ""
    Write-Host "Container status:" -ForegroundColor Cyan
    Invoke-Docker -Arguments ($ComposeArgs + @("ps"))

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
'@ | Set-Content -Path .\install-windows.ps1 -Encoding UTF8
