<p align="right">
  <a href="./README.md"><strong>Türkçe</strong></a>
  &nbsp;·&nbsp;
  <a href="./README_EN.md">English</a>
</p>

<h1 align="center">USOM IOC Gateway</h1>

<p align="center">
  USOM IOC verilerini senkronize eden ve güvenlik ürünleri için kullanıma hazır TXT feed'leri üreten Docker tabanlı IOC Gateway.
</p>

<p align="center">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white">
  <img alt="PostgreSQL" src="https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Windows-2F3437">
</p>

Genel Bakış

USOM IOC Gateway, USOM tarafından yayımlanan domain, IPv4, IPv6 ve URL tehdit göstergelerini düzenli olarak senkronize eder.

Toplanan IOC kayıtları merkezi olarak saklanır, web arayüzü üzerinden yönetilir ve firewall, SIEM, güvenlik ağ geçidi veya benzeri ürünlerin kullanabileceği TXT feed'leri halinde yayımlanır.

Öne Çıkanlar

Otomatik USOM IOC senkronizasyonu

Domain, IPv4, IPv6 ve URL için ayrı worker yapısı

Web tabanlı yönetim paneli

TXT feed üretimi ve yayını

PostgreSQL tabanlı kalıcı veri saklama

Docker Compose ile hızlı kurulum

Servis durumu ve senkronizasyon takibi

Hızlı Kurulum

Ubuntu

Temiz bir Ubuntu sunucuda:

curl -fsSL https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/bootstrap-ubuntu.sh -o bootstrap-ubuntu.sh
chmod +x bootstrap-ubuntu.sh
sudo ./bootstrap-ubuntu.sh

Kurulum tamamlandığında:

http://SUNUCU_IP_ADRESI

Windows 10 / 11

PowerShell'i Yönetici olarak açın ve çalıştırın:

irm "https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/install-windows.ps1?v=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" | iex

Kurulum tamamlandığında:

http://localhost:8080

Varsayılan kullanıcı adı admin'dir. Admin parolası kurulum sırasında güvenli şekilde oluşturulur ve işlem sonunda ekranda gösterilir.

Sistem Gereksinimleri

Kaynak

Önerilen

CPU

2 vCPU

RAM

4 GB

Disk

40 GB

İnternet erişimi ve Docker çalışma ortamı gereklidir. Windows kurulum aracı gerekli bileşenleri kontrol eder.

Mimari

Servis

Görev

db

PostgreSQL veritabanı

web

Yönetim paneli ve API

orchestrator

Senkronizasyon zamanlayıcısı

worker-domain

Domain IOC işlemleri

worker-ip

IPv4 IOC işlemleri

worker-url

URL IOC işlemleri

worker-ipv6

IPv6 IOC işlemleri

nginx

Web erişimi ve feed yayını

Feed Erişimi

Ubuntu:

http://SUNUCU_IP_ADRESI/feeds/

Windows:

http://localhost:8080/feeds/

Yapılandırma

Kurulum sırasında .env.example dosyasından yerel bir .env dosyası oluşturulur.

Başlıca değişkenler:

Değişken

Açıklama

TFG_HTTP_PORT

Web ve feed yayın portu

DJANGO_ALLOWED_HOSTS

İzin verilen adresler

ORCHESTRATOR_INTERVAL_SECONDS

Senkronizasyon aralığı

USOM_FETCH_CONCURRENCY

Eş zamanlı veri çekme değeri

DJANGO_SUPERUSER_USERNAME

Yönetici kullanıcı adı

.env dosyası parola ve secret bilgileri içerir. GitHub'a yüklenmemelidir.

Temel Yönetim Komutları

Ubuntu proje dizini:

cd /opt/usom-ioc-gateway

Windows proje dizini:

Set-Location "C:\USOM\usom-ioc-gateway"

Servis durumu:

docker compose ps

Son loglar:

docker compose logs --tail=100

Canlı log takibi:

docker compose logs -f

Güncelleme ve yeniden başlatma:

docker compose pull
docker compose up -d --remove-orphans

Ubuntu Kaldırma

cd /opt/usom-ioc-gateway
sudo ./uninstall.sh

Docker Engine dahil kapsamlı kaldırma:

sudo ./uninstall.sh --purge-docker

Aynı sunucuda başka Docker servisleri çalışıyorsa --purge-docker kullanılmamalıdır.
