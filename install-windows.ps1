Write-Host "USOM IOC Gateway Windows kurulumu başlıyor..." -ForegroundColor Cyan

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "HATA: Docker bulunamadı." -ForegroundColor Red
    Write-Host "Lütfen önce Docker Desktop kurun ve çalıştırın."
    exit 1
}

docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "HATA: Docker Compose çalışmıyor." -ForegroundColor Red
    Write-Host "Docker Desktop'ın çalıştığından emin olun."
    exit 1
}

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host ".env oluşturuldu."
}

function New-Secret {
    return [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))
}

$content = Get-Content ".env"

$content = $content -replace "^SECRET_KEY=CHANGE_ME", "SECRET_KEY=$(New-Secret)"
$content = $content -replace "^POSTGRES_PASSWORD=CHANGE_ME", "POSTGRES_PASSWORD=$(New-Secret)"
$content = $content -replace "^DJANGO_SUPERUSER_PASSWORD=CHANGE_ME", "DJANGO_SUPERUSER_PASSWORD=$(New-Secret)"

if ($content -notmatch "^TFG_HTTP_PORT=") {
    $content += "TFG_HTTP_PORT=8080"
}

Set-Content ".env" $content

Write-Host "Docker image'ları indiriliyor..." -ForegroundColor Cyan
docker compose -f compose.yaml pull

Write-Host "Servisler başlatılıyor..." -ForegroundColor Cyan
docker compose -f compose.yaml up -d

docker compose -f compose.yaml ps

$adminUser = (Select-String -Path ".env" -Pattern "^DJANGO_SUPERUSER_USERNAME=").Line.Split("=")[1]
$adminPass = (Select-String -Path ".env" -Pattern "^DJANGO_SUPERUSER_PASSWORD=").Line.Split("=")[1]
$httpPort = (Select-String -Path ".env" -Pattern "^TFG_HTTP_PORT=").Line.Split("=")[1]

Write-Host ""
Write-Host "Kurulum tamamlandı." -ForegroundColor Green
Write-Host "Adres: http://localhost:$httpPort"
Write-Host "Admin kullanıcı: $adminUser"
Write-Host "Admin şifre: $adminPass"
