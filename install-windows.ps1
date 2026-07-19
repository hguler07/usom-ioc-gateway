# install-windows.ps1
# compose.yaml ve .env.example dosyalarına dokunmaz.
# Windows kurulumu için .env dosyasını otomatik oluşturur.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-RandomHex {
    param(
        [int]$Length = 32
    )

    $bytes = New-Object byte[] $Length
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }

    return -join (
        $bytes | ForEach-Object {
            $_.ToString("x2")
        }
    )
}

function Set-EnvValue {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[string]]$Lines,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value
    )

    $pattern = "^\s*$([regex]::Escape($Name))\s*="
    $found = $false

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $pattern) {
            $Lines[$i] = "$Name=$Value"
            $found = $true
            break
        }
    }

    if (-not $found) {
        [void]$Lines.Add("$Name=$Value")
    }
}

function Get-EnvValue {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[string]]$Lines,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $pattern = "^\s*$([regex]::Escape($Name))\s*=(.*)$"

    foreach ($line in $Lines) {
        if ($line -match $pattern) {
            return $Matches[1].Trim()
        }
    }

    return ""
}

function Invoke-Docker {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [switch]$Quiet
    )

    if ($Quiet) {
        & docker @Arguments *> $null
    }
    else {
        & docker @Arguments
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Docker komutu başarısız oldu: docker $($Arguments -join ' ')"
    }
}

$originalLocation = Get-Location

try {
    Write-Host ""
    Write-Host "USOM IOC Gateway Windows kurulumu başlıyor..." `
        -ForegroundColor Cyan

    # Her zaman scriptin bulunduğu klasörü kullan.
    $projectPath = $PSScriptRoot

    if ([string]::IsNullOrWhiteSpace($projectPath)) {
        throw "install-windows.ps1 dosyasının bulunduğu klasör tespit edilemedi."
    }

    Set-Location -LiteralPath $projectPath

    $composePath = Join-Path $projectPath "compose.yaml"
    $envExamplePath = Join-Path $projectPath ".env.example"
    $envPath = Join-Path $projectPath ".env"

    Write-Host "Proje klasörü: $projectPath" `
        -ForegroundColor DarkGray

    if (-not (Test-Path -LiteralPath $composePath -PathType Leaf)) {
        throw "compose.yaml bulunamadı: $composePath"
    }

    if (-not (Test-Path -LiteralPath $envExamplePath -PathType Leaf)) {
        throw ".env.example bulunamadı: $envExamplePath"
    }

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw @"
Docker bulunamadı.

Önce Docker Desktop'ı kurun ve PowerShell'i yeniden açın.
"@
    }

    Write-Host "Docker Desktop kontrol ediliyor..." `
        -ForegroundColor Cyan

    try {
        Invoke-Docker -Arguments @("info") -Quiet
    }
    catch {
        throw @"
Docker Desktop kurulu ancak Docker Engine çalışmıyor.

Docker Desktop'ı açın, Engine Running durumuna gelmesini bekleyin
ve kurulumu yeniden çalıştırın.
"@
    }

    Invoke-Docker `
        -Arguments @("compose", "version") `
        -Quiet

    # Sadece Windows kurulumuna ait .env oluşturulur.
    # .env.example dosyası kesinlikle değiştirilmez.
    if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
        Copy-Item `
            -LiteralPath $envExamplePath `
            -Destination $envPath `
            -Force

        Write-Host "Windows için .env dosyası oluşturuldu." `
            -ForegroundColor Green
    }
    else {
        Write-Host "Mevcut .env dosyası kullanılacak." `
            -ForegroundColor DarkGray
    }

    $envLines = New-Object `
        "System.Collections.Generic.List[string]"

    foreach (
        $line in @(
            Get-Content `
                -LiteralPath $envPath `
                -Encoding UTF8
        )
    ) {
        [void]$envLines.Add([string]$line)
    }

    $secretKey = Get-EnvValue `
        -Lines $envLines `
        -Name "SECRET_KEY"

    if (
        [string]::IsNullOrWhiteSpace($secretKey) -or
        $secretKey -eq "CHANGE_ME"
    ) {
        Set-EnvValue `
            -Lines $envLines `
            -Name "SECRET_KEY" `
            -Value (New-RandomHex -Length 32)
    }

    $postgresPassword = Get-EnvValue `
        -Lines $envLines `
        -Name "POSTGRES_PASSWORD"

    if (
        [string]::IsNullOrWhiteSpace($postgresPassword) -or
        $postgresPassword -eq "CHANGE_ME"
    ) {
        Set-EnvValue `
            -Lines $envLines `
            -Name "POSTGRES_PASSWORD" `
            -Value (New-RandomHex -Length 32)
    }

    $adminPassword = Get-EnvValue `
        -Lines $envLines `
        -Name "DJANGO_SUPERUSER_PASSWORD"

    if (
        [string]::IsNullOrWhiteSpace($adminPassword) -or
        $adminPassword -eq "CHANGE_ME"
    ) {
        Set-EnvValue `
            -Lines $envLines `
            -Name "DJANGO_SUPERUSER_PASSWORD" `
            -Value (New-RandomHex -Length 24)
    }

    # Yalnızca Windows için oluşturulan .env içerisinde 8080 kullanılır.
    Set-EnvValue `
        -Lines $envLines `
        -Name "TFG_HTTP_PORT" `
        -Value "8080"

    Set-EnvValue `
        -Lines $envLines `
        -Name "DJANGO_SUPERUSER_USERNAME" `
        -Value "admin"

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllLines(
        $envPath,
        $envLines,
        $utf8NoBom
    )

    $adminUser = Get-EnvValue `
        -Lines $envLines `
        -Name "DJANGO_SUPERUSER_USERNAME"

    $adminPass = Get-EnvValue `
        -Lines $envLines `
        -Name "DJANGO_SUPERUSER_PASSWORD"

    $httpPort = Get-EnvValue `
        -Lines $envLines `
        -Name "TFG_HTTP_PORT"

    $composeArguments = @(
        "compose",
        "--project-directory", $projectPath,
        "--env-file", $envPath,
        "-f", $composePath
    )

    Write-Host "Docker Compose dosyası doğrulanıyor..." `
        -ForegroundColor Cyan

    Invoke-Docker `
        -Arguments ($composeArguments + @("config", "--quiet")) `
        -Quiet

    Write-Host "Docker Hub image'ları indiriliyor..." `
        -ForegroundColor Cyan

    Invoke-Docker `
        -Arguments ($composeArguments + @("pull"))

    Write-Host "USOM IOC Gateway servisleri başlatılıyor..." `
        -ForegroundColor Cyan

    Invoke-Docker `
        -Arguments (
            $composeArguments +
            @("up", "-d", "--remove-orphans")
        )

    Write-Host ""
    Write-Host "Servis durumu:" `
        -ForegroundColor Cyan

    Invoke-Docker `
        -Arguments ($composeArguments + @("ps"))

    Write-Host ""
    Write-Host "Kurulum başarıyla tamamlandı." `
        -ForegroundColor Green

    Write-Host "Adres          : http://localhost:$httpPort"
    Write-Host "Admin kullanıcı: $adminUser"
    Write-Host "Admin şifre    : $adminPass" `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Admin şifresini güvenli bir yerde saklayın." `
        -ForegroundColor DarkYellow
}
catch {
    Write-Host ""
    Write-Host "KURULUM BAŞARISIZ OLDU" `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""
    exit 1
}
finally {
    Set-Location $originalLocation
}
