# install-windows.ps1
# compose.yaml ve .env.example ile aynı klasörde bulunmalıdır.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-RandomHex {
    param(
        [int]$ByteLength = 32
    )

    $Bytes = New-Object byte[] $ByteLength
    $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        $Rng.GetBytes($Bytes)
    }
    finally {
        $Rng.Dispose()
    }

    return -join ($Bytes | ForEach-Object {
        $_.ToString("x2")
    })
}

function Set-EnvVariable {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[string]]$Lines,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [switch]$OnlyIfMissingOrChangeMe
    )

    $Pattern = "^\s*$([Regex]::Escape($Name))\s*="
    $FoundIndex = -1

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $Pattern) {
            $FoundIndex = $i
            break
        }
    }

    if ($FoundIndex -ge 0) {
        $CurrentValue = ($Lines[$FoundIndex] -replace $Pattern, "").Trim()
        $CurrentValue = $CurrentValue.Trim('"', "'")

        if (
            $OnlyIfMissingOrChangeMe -and
            -not [string]::IsNullOrWhiteSpace($CurrentValue) -and
            $CurrentValue -notmatch "^(CHANGE_ME|CHANGEME|REPLACE_ME)$"
        ) {
            return
        }

        $Lines[$FoundIndex] = "$Name=$Value"
    }
    else {
        [void]$Lines.Add("$Name=$Value")
    }
}

function Get-EnvVariable {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[string]]$Lines,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $Pattern = "^\s*$([Regex]::Escape($Name))\s*=(.*)$"

    foreach ($Line in $Lines) {
        if ($Line -match $Pattern) {
            $Value = $Matches[1].Trim()
            return $Value.Trim('"', "'")
        }
    }

    throw ".env içerisinde '$Name' değeri bulunamadı."
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

$OriginalLocation = Get-Location

try {
    Write-Host ""
    Write-Host "USOM IOC Gateway Windows kurulumu başlıyor..." `
        -ForegroundColor Cyan

    # Script hangi klasördeyse proje klasörü odur.
    $ProjectPath = $PSScriptRoot

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        throw @"
Script klasörü tespit edilemedi.

Kodu PowerShell ekranına satır satır yapıştırmayın.
install-windows.ps1 dosyasını çalıştırın.
"@
    }

    Set-Location -LiteralPath $ProjectPath

    $ComposePath = Join-Path $ProjectPath "compose.yaml"
    $EnvExamplePath = Join-Path $ProjectPath ".env.example"
    $EnvPath = Join-Path $ProjectPath ".env"

    Write-Host "Proje klasörü: $ProjectPath" `
        -ForegroundColor DarkGray

    if (-not (Test-Path -LiteralPath $ComposePath -PathType Leaf)) {
        throw "compose.yaml bulunamadı: $ComposePath"
    }

    if (-not (Test-Path -LiteralPath $EnvExamplePath -PathType Leaf)) {
        throw ".env.example bulunamadı: $EnvExamplePath"
    }

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw @"
Docker komutu bulunamadı.

Docker Desktop'ı kurun ve PowerShell'i yeniden açın.
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

Docker Desktop'ı açın ve tamamen başlamasını bekleyin.
Ardından kurulumu yeniden çalıştırın.
"@
    }

    Invoke-Docker `
        -Arguments @("compose", "version") `
        -Quiet

    $EnvCreated = $false

    # .env yoksa veya boşsa yeniden oluştur.
    if (
        -not (Test-Path -LiteralPath $EnvPath -PathType Leaf) -or
        (Get-Item -LiteralPath $EnvPath).Length -eq 0
    ) {
        Copy-Item `
            -LiteralPath $EnvExamplePath `
            -Destination $EnvPath `
            -Force

        $EnvCreated = $true

        Write-Host ".env dosyası oluşturuldu." `
            -ForegroundColor Green
    }
    else {
        Write-Host "Mevcut .env dosyası korunuyor." `
            -ForegroundColor DarkGray
    }

    $EnvLines = New-Object `
        "System.Collections.Generic.List[string]"

    foreach (
        $Line in @(
            Get-Content `
                -LiteralPath $EnvPath `
                -Encoding UTF8
        )
    ) {
        [void]$EnvLines.Add([string]$Line)
    }

    Set-EnvVariable `
        -Lines $EnvLines `
        -Name "SECRET_KEY" `
        -Value (New-RandomHex -ByteLength 32) `
        -OnlyIfMissingOrChangeMe

    Set-EnvVariable `
        -Lines $EnvLines `
        -Name "POSTGRES_PASSWORD" `
        -Value (New-RandomHex -ByteLength 32) `
        -OnlyIfMissingOrChangeMe

    Set-EnvVariable `
        -Lines $EnvLines `
        -Name "DJANGO_SUPERUSER_PASSWORD" `
        -Value (New-RandomHex -ByteLength 24) `
        -OnlyIfMissingOrChangeMe

    Set-EnvVariable `
        -Lines $EnvLines `
        -Name "DJANGO_SUPERUSER_USERNAME" `
        -Value "admin" `
        -OnlyIfMissingOrChangeMe

    # Yeni kurulumlarda Windows portu 8080 olsun.
    if ($EnvCreated) {
        Set-EnvVariable `
            -Lines $EnvLines `
            -Name "TFG_HTTP_PORT" `
            -Value "8080"
    }
    else {
        Set-EnvVariable `
            -Lines $EnvLines `
            -Name "TFG_HTTP_PORT" `
            -Value "8080" `
            -OnlyIfMissingOrChangeMe
    }

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllLines(
        $EnvPath,
        $EnvLines,
        $Utf8NoBom
    )

    $AdminUser = Get-EnvVariable `
        -Lines $EnvLines `
        -Name "DJANGO_SUPERUSER_USERNAME"

    $AdminPass = Get-EnvVariable `
        -Lines $EnvLines `
        -Name "DJANGO_SUPERUSER_PASSWORD"

    $HttpPort = Get-EnvVariable `
        -Lines $EnvLines `
        -Name "TFG_HTTP_PORT"

    $ComposeArguments = @(
        "compose",
        "--env-file", $EnvPath,
        "-f", $ComposePath
    )

    Write-Host "Docker Compose yapılandırması kontrol ediliyor..." `
        -ForegroundColor Cyan

    Invoke-Docker `
        -Arguments ($ComposeArguments + @("config", "--quiet")) `
        -Quiet

    Write-Host "Docker image'ları indiriliyor..." `
        -ForegroundColor Cyan

    Invoke-Docker `
        -Arguments ($ComposeArguments + @("pull"))

    Write-Host "Servisler başlatılıyor..." `
        -ForegroundColor Cyan

    Invoke-Docker `
        -Arguments (
            $ComposeArguments +
            @("up", "-d", "--remove-orphans")
        )

    Write-Host ""
    Write-Host "Servis durumu:" `
        -ForegroundColor Cyan

    Invoke-Docker `
        -Arguments ($ComposeArguments + @("ps"))

    Write-Host ""
    Write-Host "Kurulum başarıyla tamamlandı." `
        -ForegroundColor Green

    Write-Host "Adres          : http://localhost:$HttpPort"
    Write-Host "Admin kullanıcı: $AdminUser"
    Write-Host "Admin şifre    : $AdminPass" `
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
    Set-Location $OriginalLocation
}
