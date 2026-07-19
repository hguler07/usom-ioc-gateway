# install-windows.ps1
# Bu dosyayı compose.yaml ve .env.example ile aynı klasöre koyun.

[CmdletBinding()]
param(
    [string]$ProjectPath = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-SecureHex {
    param(
        [int]$ByteLength = 32
    )

    $bytes = [System.Array]::CreateInstance([byte], $ByteLength)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        $rng.GetBytes($bytes)
    }
    finally {
        $rng.Dispose()
    }

    return -join ($bytes | ForEach-Object {
        $_.ToString("x2")
    })
}

function Set-EnvValue {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[string]]$Lines,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [switch]$OnlyIfMissingOrPlaceholder
    )

    $pattern = "^\s*$([Regex]::Escape($Name))\s*="
    $foundIndex = -1

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $pattern) {
            $foundIndex = $i
        }
    }

    if ($foundIndex -ge 0) {
        $currentValue = ($Lines[$foundIndex] -replace $pattern, "").Trim()
        $currentValue = $currentValue.Trim([char[]]@('"', "'"))

        if (
            $OnlyIfMissingOrPlaceholder -and
            -not [string]::IsNullOrWhiteSpace($currentValue) -and
            $currentValue -notmatch "^(CHANGE_ME|CHANGEME|REPLACE_ME)(_|$)"
        ) {
            return
        }

        $Lines[$foundIndex] = "$Name=$Value"
    }
    else {
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

    $pattern = "^\s*$([Regex]::Escape($Name))\s*=(.*)$"
    $value = $null

    foreach ($line in $Lines) {
        if ($line -match $pattern) {
            $value = $Matches[1].Trim()
            $value = $value.Trim([char[]]@('"', "'"))
        }
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw ".env içerisinde '$Name' değeri bulunamadı veya boş."
    }

    return $value
}

function Invoke-DockerCommand {
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

$locationPushed = $false

try {
    Write-Host ""
    Write-Host "USOM IOC Gateway Windows kurulumu başlıyor..." `
        -ForegroundColor Cyan

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        throw @"
Script klasörü tespit edilemedi.

Kodu PowerShell ekranına satır satır yapıştırmayın.
Dosyayı install-windows.ps1 adıyla kaydedip çalıştırın.
"@
    }

    if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
        throw "Proje klasörü bulunamadı: $ProjectPath"
    }

    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path

    $composePath = Join-Path $ProjectPath "compose.yaml"
    $envExamplePath = Join-Path $ProjectPath ".env.example"
    $envPath = Join-Path $ProjectPath ".env"

    Write-Host "Proje klasörü: $ProjectPath" -ForegroundColor DarkGray

    if (-not (Test-Path -LiteralPath $composePath -PathType Leaf)) {
        throw "compose.yaml bulunamadı: $composePath"
    }

    if (
        -not (Test-Path -LiteralPath $envPath -PathType Leaf) -and
        -not (Test-Path -LiteralPath $envExamplePath -PathType Leaf)
    ) {
        throw ".env ve .env.example dosyaları bulunamadı."
    }

    Push-Location $ProjectPath
    $locationPushed = $true

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw @"
Docker komutu bulunamadı.

Docker Desktop'ı kurun ve ardından PowerShell'i yeniden açın.
"@
    }

    Write-Host "Docker Desktop kontrol ediliyor..." `
        -ForegroundColor Cyan

    try {
        Invoke-DockerCommand -Arguments @("info") -Quiet
    }
    catch {
        throw @"
Docker Desktop kurulu ancak Docker Engine çalışmıyor.

Docker Desktop'ı açın ve tamamen başlamasını bekledikten sonra
kurulumu yeniden çalıştırın.
"@
    }

    Invoke-DockerCommand `
        -Arguments @("compose", "version") `
        -Quiet

    if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
        Copy-Item `
            -LiteralPath $envExamplePath `
            -Destination $envPath `
            -ErrorAction Stop

        Write-Host ".env dosyası oluşturuldu." `
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
                -Encoding UTF8 `
                -ErrorAction Stop
        )
    ) {
        [void]$envLines.Add([string]$line)
    }

    Set-EnvValue `
        -Lines $envLines `
        -Name "SECRET_KEY" `
        -Value (New-SecureHex -ByteLength 32) `
        -OnlyIfMissingOrPlaceholder

    Set-EnvValue `
        -Lines $envLines `
        -Name "POSTGRES_PASSWORD" `
        -Value (New-SecureHex -ByteLength 32) `
        -OnlyIfMissingOrPlaceholder

    Set-EnvValue `
        -Lines $envLines `
        -Name "DJANGO_SUPERUSER_PASSWORD" `
        -Value (New-SecureHex -ByteLength 24) `
        -OnlyIfMissingOrPlaceholder

    Set-EnvValue `
        -Lines $envLines `
        -Name "DJANGO_SUPERUSER_USERNAME" `
        -Value "admin" `
        -OnlyIfMissingOrPlaceholder

    Set-EnvValue `
        -Lines $envLines `
        -Name "TFG_HTTP_PORT" `
        -Value "8080" `
        -OnlyIfMissingOrPlaceholder

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
        "--env-file", $envPath,
        "-f", $composePath
    )

    Write-Host "Docker Compose yapılandırması kontrol ediliyor..." `
        -ForegroundColor Cyan

    Invoke-DockerCommand `
        -Arguments ($composeArguments + @("config", "--quiet")) `
        -Quiet

    Write-Host "Docker image'ları indiriliyor..." `
        -ForegroundColor Cyan

    Invoke-DockerCommand `
        -Arguments ($composeArguments + @("pull"))

    Write-Host "Servisler başlatılıyor..." `
        -ForegroundColor Cyan

    Invoke-DockerCommand `
        -Arguments ($composeArguments + @("up", "-d"))

    Write-Host ""
    Write-Host "Servis durumu:" -ForegroundColor Cyan

    Invoke-DockerCommand `
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
    [Environment]::ExitCode = 1
    return
}
finally {
    if ($locationPushed) {
        Pop-Location
    }
}
