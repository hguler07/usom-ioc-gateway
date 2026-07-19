# install-windows.ps1
# compose.yaml ve .env.example dosyalarini degistirmez.
# Windows kurulumu icin yerel .env dosyasi olusturur.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-RandomHex {
    param(
        [int]$ByteLength = 32
    )

    $Bytes = [System.Array]::CreateInstance(
        [byte],
        $ByteLength
    )

    $Generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        $Generator.GetBytes($Bytes)
    }
    finally {
        $Generator.Dispose()
    }

    return -join (
        $Bytes | ForEach-Object {
            $_.ToString("x2")
        }
    )
}

function Set-EnvValue {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [switch]$OnlyIfMissingOrPlaceholder
    )

    $EscapedName = [Regex]::Escape($Name)
    $Pattern = "(?m)^[ \t]*$EscapedName[ \t]*=(.*)$"
    $Match = [Regex]::Match($Content, $Pattern)

    if ($Match.Success) {
        $CurrentValue = $Match.Groups[1].Value.Trim()
        $CurrentValue = $CurrentValue.Trim(
            [char[]]@('"', "'")
        )

        if (
            $OnlyIfMissingOrPlaceholder -and
            -not [string]::IsNullOrWhiteSpace($CurrentValue) -and
            $CurrentValue -notmatch "^(CHANGE_ME|CHANGEME|REPLACE_ME)(_|$)"
        ) {
            return $Content
        }

        return [Regex]::Replace(
            $Content,
            $Pattern,
            "$Name=$Value"
        )
    }

    if (
        $Content.Length -gt 0 -and
        -not $Content.EndsWith("`n")
    ) {
        $Content += "`r`n"
    }

    return $Content + "$Name=$Value`r`n"
}

function Get-EnvValue {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $EscapedName = [Regex]::Escape($Name)
    $Pattern = "(?m)^[ \t]*$EscapedName[ \t]*=(.*)$"
    $Match = [Regex]::Match($Content, $Pattern)

    if (-not $Match.Success) {
        throw ".env dosyasinda '$Name' degeri bulunamadi."
    }

    $Value = $Match.Groups[1].Value.Trim()

    return $Value.Trim(
        [char[]]@('"', "'")
    )
}

function Invoke-DockerCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [switch]$Quiet
    )

    if ($Quiet) {
        & docker @Arguments | Out-Null
    }
    else {
        & docker @Arguments
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Docker komutu basarisiz oldu: docker $($Arguments -join ' ')"
    }
}

$OriginalLocation = Get-Location
$ExitCode = 0

try {
    Write-Host ""
    Write-Host "USOM IOC Gateway Windows kurulumu baslatiliyor..." `
        -ForegroundColor Cyan

    $ProjectPath = $PSScriptRoot

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        throw "Kurulum dosyasinin bulundugu klasor tespit edilemedi."
    }

    $ProjectPath = (
        Resolve-Path -LiteralPath $ProjectPath
    ).Path

    Set-Location -LiteralPath $ProjectPath

    $ComposePath = Join-Path `
        $ProjectPath `
        "compose.yaml"

    $EnvExamplePath = Join-Path `
        $ProjectPath `
        ".env.example"

    $EnvPath = Join-Path `
        $ProjectPath `
        ".env"

    Write-Host "Proje klasoru: $ProjectPath" `
        -ForegroundColor DarkGray

    if (-not (
        Test-Path `
            -LiteralPath $ComposePath `
            -PathType Leaf
    )) {
        throw "compose.yaml bulunamadi: $ComposePath"
    }

    if (-not (
        Test-Path `
            -LiteralPath $EnvExamplePath `
            -PathType Leaf
    )) {
        throw ".env.example bulunamadi: $EnvExamplePath"
    }

    if (-not (
        Get-Command docker `
            -ErrorAction SilentlyContinue
    )) {
        throw @"
Docker komutu bulunamadi.

Docker Desktop'i kurun ve PowerShell'i yeniden acin.
"@
    }

    Write-Host "Docker Desktop kontrol ediliyor..." `
        -ForegroundColor Cyan

    & docker info *> $null

    if ($LASTEXITCODE -ne 0) {
        throw @"
Docker Desktop kurulu ancak Docker Engine calismiyor.

Docker Desktop'i acin ve Engine Running durumuna gelmesini bekleyin.
"@
    }

    & docker compose version *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose calismiyor."
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $EnvPath `
                -PathType Leaf
        ) -or
        (Get-Item -LiteralPath $EnvPath).Length -eq 0
    ) {
        Copy-Item `
            -LiteralPath $EnvExamplePath `
            -Destination $EnvPath `
            -Force

        Write-Host "Windows icin .env dosyasi olusturuldu." `
            -ForegroundColor Green
    }
    else {
        Write-Host "Mevcut .env dosyasi kullaniliyor." `
            -ForegroundColor DarkGray
    }

    $EnvContent = [System.IO.File]::ReadAllText(
        $EnvPath,
        [System.Text.Encoding]::UTF8
    )

    if ([string]::IsNullOrWhiteSpace($EnvContent)) {
        throw ".env dosyasi bos."
    }

    $EnvContent = Set-EnvValue `
        -Content $EnvContent `
        -Name "SECRET_KEY" `
        -Value (New-RandomHex -ByteLength 32) `
        -OnlyIfMissingOrPlaceholder

    $EnvContent = Set-EnvValue `
        -Content $EnvContent `
        -Name "POSTGRES_PASSWORD" `
        -Value (New-RandomHex -ByteLength 32) `
        -OnlyIfMissingOrPlaceholder

    $EnvContent = Set-EnvValue `
        -Content $EnvContent `
        -Name "DJANGO_SUPERUSER_PASSWORD" `
        -Value (New-RandomHex -ByteLength 24) `
        -OnlyIfMissingOrPlaceholder

    $EnvContent = Set-EnvValue `
        -Content $EnvContent `
        -Name "DJANGO_SUPERUSER_USERNAME" `
        -Value "admin" `
        -OnlyIfMissingOrPlaceholder

    # Ubuntu dosyalari degismez.
    # Yalnizca Windows bilgisayarindaki .env 8080 kullanir.
    $EnvContent = Set-EnvValue `
        -Content $EnvContent `
        -Name "TFG_HTTP_PORT" `
        -Value "8080"

    $Utf8NoBom = New-Object `
        System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $EnvPath,
        $EnvContent,
        $Utf8NoBom
    )

    $AdminUser = Get-EnvValue `
        -Content $EnvContent `
        -Name "DJANGO_SUPERUSER_USERNAME"

    $AdminPassword = Get-EnvValue `
        -Content $EnvContent `
        -Name "DJANGO_SUPERUSER_PASSWORD"

    $HttpPort = Get-EnvValue `
        -Content $EnvContent `
        -Name "TFG_HTTP_PORT"

    $ComposeArguments = @(
        "compose",
        "--project-name",
        "usom-ioc-gateway",
        "--project-directory",
        $ProjectPath,
        "--env-file",
        $EnvPath,
        "-f",
        $ComposePath
    )

    Write-Host "Docker Compose yapilandirmasi kontrol ediliyor..." `
        -ForegroundColor Cyan

    Invoke-DockerCommand `
        -Arguments (
            $ComposeArguments +
            @("config", "--quiet")
        ) `
        -Quiet

    Write-Host "Docker Hub image dosyalari indiriliyor..." `
        -ForegroundColor Cyan

    Invoke-DockerCommand `
        -Arguments (
            $ComposeArguments +
            @("pull")
        )

    Write-Host "USOM IOC Gateway servisleri baslatiliyor..." `
        -ForegroundColor Cyan

    Invoke-DockerCommand `
        -Arguments (
            $ComposeArguments +
            @(
                "up",
                "-d",
                "--remove-orphans"
            )
        )

    Write-Host ""
    Write-Host "Servis durumu:" `
        -ForegroundColor Cyan

    Invoke-DockerCommand `
        -Arguments (
            $ComposeArguments +
            @("ps")
        )

    Write-Host ""
    Write-Host "Kurulum basariyla tamamlandi." `
        -ForegroundColor Green

    Write-Host "Adres          : http://localhost:$HttpPort"
    Write-Host "Admin kullanici: $AdminUser"
    Write-Host "Admin sifre    : $AdminPassword" `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Admin sifresini guvenli bir yerde saklayin." `
        -ForegroundColor DarkYellow
}
catch {
    $ExitCode = 1

    Write-Host ""
    Write-Host "KURULUM BASARISIZ OLDU" `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""
}
finally {
    Set-Location -LiteralPath $OriginalLocation.Path
}

exit $ExitCode
