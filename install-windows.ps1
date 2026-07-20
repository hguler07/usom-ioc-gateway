Write-Host "USOM IOC Gateway Windows kurulumu başlıyor..." -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

function New-Secret {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return [Convert]::ToBase64String($bytes)
}

function Set-Or-Add-EnvValue {
    param (
        [string]$Path,
        [string]$Key,
        [string]$Value
    )

    $lines = Get-Content $Path -ErrorAction SilentlyContinue

    if ($lines -match "^$Key=") {
        $lines = $lines -replace "^$Key=.*", "$Key=$Value"
    } else {
        $lines += "$Key=$Value"
    }

    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

function Replace-ChangeMe {
    param (
        [string]$Path,
        [string]$Key
    )

    $lines = Get-Content $Path -ErrorAction SilentlyContinue
    $current = ($lines | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1)

    if (-not $current) {
        $lines += "$Key=$(New-Secret)"
        Set-Content -Path $Path -Value $lines -Encoding UTF8
        return
    }

    if ($current -match "^$Key=CHANGE_ME$" -or $current -match "^$Key=$") {
        $newValue = New-Secret
        $lines = $lines -replace "^$Key=.*", "$Key=$newValue"
        Set-Content -Path $Path -Value $lines -Encoding UTF8
    }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "HATA: Docker bulunamadı." -ForegroundColor Red
    Write-Host "Lütfen Docker Desktop kurun ve çalıştırın."
    exit 1
}

docker version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "HATA: Docker Desktop çalışmıyor." -ForegroundColor Red
    Write-Host "Lütfen Docker Desktop'ı başlatın ve tekrar deneyin."
    exit 1
}

docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "HATA: Docker Compose çalışmıyor." -ForegroundColor Red
    Write-Host "Docker Desktop içinde Compose desteğini kontrol edin."
    exit 1
}

if (-not (Test-Path "compose.yaml")) {
    Write-Host "HATA: compose.yaml bulunamadı." -ForegroundColor Red
    Write-Host "Bu script'i GitHub repo klasörü içinde çalıştırmalısınız."
    exit 1
}

if (-not (Test-Path ".env.example")) {
    Write-Host "HATA: .env.example bulunamadı." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host ".env dosyası oluşturuldu."
} else {
    Write-Host ".env zaten var, mevcut ayarlar korunacak."
}

Replace-ChangeMe -Path ".env" -Key "SECRET_KEY"
Replace-ChangeMe -Path ".env" -Key "POSTGRES_PASSWORD"
Replace-ChangeMe -Path ".env" -Key "DJANGO_SUPERUSER_PASSWORD"

Set-Or-Add-EnvValue -Path ".env" -Key "TFG_HTTP_PORT" -Value "8080"

$compose = Get-Content "compose.yaml" -Raw
$compose = $compose -replace "hguler07/usom-ioc-gateway:backend-[0-9]+\.[0-9]+\.[0-9]+", "hguler07/usom-ioc-gateway:backend-0.1.16"
$compose = $compose -replace "hguler07/usom-ioc-gateway:nginx-[0-9]+\.[0-9]+\.[0-9]+", "hguler07/usom-ioc-gateway:nginx-0.1.18"
Set-Content -Path "compose.yaml" -Value $compose -Encoding UTF8

Write-Host "Compose dosyası kontrol ediliyor..." -ForegroundColor Cyan
docker compose -f compose.yaml config | Out-Null

Write-Host "Docker image'ları indiriliyor..." -ForegroundColor Cyan
docker compose -f compose.yaml pull

Write-Host "Servisler başlatılıyor..." -ForegroundColor Cyan
docker compose -f compose.yaml up -d --remove-orphans

Write-Host ""
Write-Host "Container durumu:" -ForegroundColor Cyan
docker compose -f compose.yaml ps

$adminUser = "admin"
$adminPass = ""
$httpPort = "8080"

$envLines = Get-Content ".env"

$userLine = $envLines | Where-Object { $_ -match "^DJANGO_SUPERUSER_USERNAME=" } | Select-Object -First 1
$passLine = $envLines | Where-Object { $_ -match "^DJANGO_SUPERUSER_PASSWORD=" } | Select-Object -First 1
$portLine = $envLines | Where-Object { $_ -match "^TFG_HTTP_PORT=" } | Select-Object -First 1

if ($userLine) { $adminUser = $userLine.Split("=", 2)[1] }
if ($passLine) { $adminPass = $passLine.Split("=", 2)[1] }
if ($portLine) { $httpPort = $portLine.Split("=", 2)[1] }

Write-Host ""
Write-Host "Kurulum tamamlandı." -ForegroundColor Green
Write-Host "Adres          : http://localhost:$httpPort"
Write-Host "Kullanıcı adı  : $adminUser"
Write-Host "Admin şifre    : $adminPass"
Write-Host ""
Write-Host "İlk açılışta backend servisleri hazırlanırken kısa süre 502 görülebilir. 1-2 dakika bekleyip sayfayı yenileyin."
