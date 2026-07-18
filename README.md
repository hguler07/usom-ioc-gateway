# USOM IOC Gateway

**USOM IOC Gateway**, USOM IOC verilerini senkronize ederek güvenlik cihazları için firewall uyumlu TXT feed dosyaları yayınlayan Docker tabanlı bağımsız bir IOC gateway projesidir.

> Bu proje bağımsız olarak geliştirilmiştir. Resmi USOM ürünü değildir.

---

## Genel Bakış

Bu repository kaynak kod içermez. Kurulum ve çalıştırma dosyalarını içeren **deploy paketi** olarak hazırlanmıştır.

Uygulama Docker Hub üzerindeki hazır image sürümleriyle çalışır:

```text
Backend : hguler07/usom-ioc-gateway:backend-0.1.15
Nginx/UI: hguler07/usom-ioc-gateway:nginx-0.1.17
```

---

## Özellikler

```text
- USOM IOC senkronizasyonu
- Domain, IPv4, IPv6 ve URL feed üretimi
- Firewall uyumlu TXT feed çıktıları
- Web yönetim paneli
- Feed güncelleme zaman çizelgesi
- Sistem sağlık durumu ekranı
- PostgreSQL veritabanı
- Docker Compose ile kolay kurulum
- Non-root backend ve nginx container yapısı
```

---

## Hızlı Ubuntu Kurulumu

Temiz Ubuntu sunucuda aşağıdaki tek komut yeterlidir:

```bash
curl -fsSL https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/bootstrap-ubuntu.sh -o bootstrap-ubuntu.sh && chmod +x bootstrap-ubuntu.sh && sudo ./bootstrap-ubuntu.sh
```

Bu komut otomatik olarak:

```text
- Docker yoksa kurar
- Docker Compose plugin yoksa kurar
- Repository dosyalarını /opt/usom-ioc-gateway altına indirir
- .env dosyasını oluşturur
- Gerekli şifre ve secret değerlerini üretir
- Docker Hub image dosyalarını indirir
- Servisleri başlatır
```

---

## Manuel Ubuntu Kurulumu

Docker zaten kuruluysa:

```bash
git clone https://github.com/hguler07/usom-ioc-gateway.git
cd usom-ioc-gateway
chmod +x install.sh
sudo ./install.sh
```

---

## Windows Kurulumu

Gereksinimler:

```text
- Windows 10/11
- Docker Desktop
- Git for Windows
- PowerShell
```

PowerShell’i yönetici olarak açın:

```powershell
git clone https://github.com/hguler07/usom-ioc-gateway.git
cd usom-ioc-gateway
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

Varsayılan erişim:

```text
http://localhost:8080
```

---

## macOS Kurulumu

Gereksinimler:

```text
- Docker Desktop for Mac
- Git
- Terminal
```

Kurulum:

```bash
git clone https://github.com/hguler07/usom-ioc-gateway.git
cd usom-ioc-gateway
cp .env.example .env
echo "TFG_HTTP_PORT=8080" >> .env
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d
```

Varsayılan erişim:

```text
http://localhost:8080
```

---

## Erişim Bilgileri

Ubuntu varsayılan erişim:

```text
http://SUNUCU_IP
```

Windows/macOS varsayılan erişim:

```text
http://localhost:8080
```

Varsayılan kullanıcı adı:

```text
admin
```

Admin şifresi kurulum sırasında otomatik üretilir ve kurulum sonunda ekranda gösterilir.

---

## Feed Adresleri

Feed dosyaları aşağıdaki path altında yayınlanır:

```text
/feeds/
```

Örnek:

```text
http://SUNUCU_IP/feeds/
```

Lokal Docker Desktop kurulumlarında:

```text
http://localhost:8080/feeds/
```

---

## Servis Komutları

Servis durumunu kontrol etme:

```bash
docker compose -f compose.yaml ps
```

Logları görüntüleme:

```bash
docker compose -f compose.yaml logs --tail=100
```

Servisleri yeniden başlatma:

```bash
docker compose -f compose.yaml up -d
```

Servisleri durdurma:

```bash
docker compose -f compose.yaml down
```

---

## Kaldırma

Sadece USOM IOC Gateway container, volume, image ve uygulama dosyalarını kaldırmak için:

```bash
cd /opt/usom-ioc-gateway
sudo ./uninstall.sh
```

Docker Engine dahil tam temizlik için:

```bash
cd /opt/usom-ioc-gateway
sudo ./uninstall.sh --purge-docker
```

> Dikkat: `--purge-docker` Docker Engine’i ve Docker sistem verilerini kaldırır. Aynı sunucuda başka Docker uygulamaları varsa kullanmayın.

---

## İlk Başlatma Notu

İlk kurulumdan sonra backend servisleri ayağa kalkarken web panel kısa süreliğine `502 Bad Gateway` gösterebilir.

```text
1-2 dakika bekleyip sayfayı yenileyin.
```
