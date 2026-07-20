# USOM IOC Gateway

<p align="center">
  <b>USOM IOC verilerini senkronize ederek güvenlik ürünleri için TXT formatında feed oluşturan Docker tabanlı IOC Gateway.</b>
</p>

<p align="center">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-ready-blue">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Windows%20%7C%20macOS-lightgrey">
  <img alt="Database" src="https://img.shields.io/badge/Database-PostgreSQL-blue">
</p>

---

## Genel Bakış

**USOM IOC Gateway**, USOM tarafından yayınlanan tehdit göstergelerini düzenli olarak senkronize eden ve bu verileri güvenlik ürünlerinin kullanabileceği sade TXT feed formatında yayınlayan bir Docker Compose kurulumudur.

Amaç; domain, IP, IPv6 ve URL IOC kayıtlarını merkezi olarak takip etmek ve firewall, güvenlik ağ geçidi, SIEM veya benzeri sistemlere kolayca aktarılabilecek feed çıktıları üretmektir.

---

## Özellikler

* USOM IOC verilerini otomatik senkronize eder
* Domain, IPv4, IPv6 ve URL kayıtlarını ayrı ayrı işler
* TXT formatında feed çıktısı üretir
* Web tabanlı yönetim arayüzü sunar
* PostgreSQL veritabanı kullanır
* Docker Compose ile kolay kurulum sağlar
* Worker tabanlı arka plan işlem yapısı kullanır
* Temel sistem durumu ve servis kontrolü sağlar

---

## Mimari

Kurulum aşağıdaki servislerden oluşur:

| Servis          | Açıklama                          |
| --------------- | --------------------------------- |
| `db`            | PostgreSQL veritabanı             |
| `web`           | Web arayüzü ve API servisi        |
| `orchestrator`  | Senkronizasyon zamanlayıcısı      |
| `worker-domain` | Domain IOC işleyici               |
| `worker-ip`     | IPv4 IOC işleyici                 |
| `worker-url`    | URL IOC işleyici                  |
| `worker-ipv6`   | IPv6 IOC işleyici                 |
| `nginx`         | Web arayüzü ve feed yayın katmanı |

---

## Minimum Sistem Gereksinimleri

| Kaynak | Önerilen |
| ------ | -------: |
| CPU    |   2 vCPU |
| RAM    |     4 GB |
| Disk   |    40 GB |

Önerilen ortam:

* Ubuntu Server 22.04 LTS veya üzeri
* Docker Engine
* Docker Compose Plugin
* İnternet erişimi
* TCP `80` portu veya özel HTTP portu

> Kaynak ihtiyacı IOC sayısına, senkronizasyon sıklığına, log boyutuna ve saklanan geçmiş veriye göre değişebilir.

---

## Ubuntu Hızlı Kurulum

Temiz bir Ubuntu sunucu üzerinde aşağıdaki komutları çalıştırabilirsiniz:

```bash
curl -fsSL https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/bootstrap-ubuntu.sh -o bootstrap-ubuntu.sh
chmod +x bootstrap-ubuntu.sh
sudo ./bootstrap-ubuntu.sh
```

Kurulum tamamlandıktan sonra web arayüzüne aşağıdaki adresten erişebilirsiniz:

```text
http://SUNUCU_IP_ADRESI
```

Varsayılan kullanıcı adı:

```text
admin
```

Admin parolası kurulum sırasında otomatik oluşturulur ve kurulum sonunda ekranda gösterilir.

---

## Manuel Kurulum

Docker kurulu bir sistemde manuel kurulum için:

```bash
git clone https://github.com/hguler07/usom-ioc-gateway.git
cd usom-ioc-gateway
chmod +x install.sh
sudo ./install.sh
```

Servisleri kontrol etmek için:

```bash
docker compose -f compose.yaml ps
```

---

## Windows Kurulumu

Gereksinimler:

* Windows 10/11
* Docker Desktop
* Git for Windows
* PowerShell

PowerShell’i Yönetici olarak açıp aşağıdaki komutları çalıştırabilirsiniz:

```mkdir C:\USOM -Force
cd C:\USOM
git clone https://github.com/hguler07/usom-ioc-gateway.git
cd .\usom-ioc-gateway
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-windows.ps1
```

Varsayılan erişim adresi:

```text
http://localhost:8080
```
---
## Feed Adresleri

IOC feed çıktıları `/feeds/` altında yayınlanır.

Ubuntu sunucu örneği:

```text
http://SUNUCU_IP_ADRESI/feeds/
```

Lokal Docker Desktop örneği:

```text
http://localhost:8080/feeds/
```

---

## Yapılandırma

Kurulum sırasında `.env.example` dosyasından `.env` dosyası oluşturulur.

Öne çıkan ayarlar:

| Değişken                        | Açıklama                                   |
| ------------------------------- | ------------------------------------------ |
| `TFG_HTTP_PORT`                 | Web arayüzü ve feed yayını için HTTP portu |
| `DJANGO_ALLOWED_HOSTS`          | İzin verilen hostname veya IP adresleri    |
| `POSTGRES_DB`                   | PostgreSQL veritabanı adı                  |
| `POSTGRES_USER`                 | PostgreSQL kullanıcı adı                   |
| `POSTGRES_PASSWORD`             | PostgreSQL kullanıcı parolası              |
| `DJANGO_SUPERUSER_USERNAME`     | Admin kullanıcı adı                        |
| `DJANGO_SUPERUSER_PASSWORD`     | Admin kullanıcı parolası                   |
| `USOM_FETCH_CONCURRENCY`        | USOM veri çekme eşzamanlılık değeri        |
| `ORCHESTRATOR_INTERVAL_SECONDS` | Senkronizasyon aralığı                     |

> `.env` dosyası parola ve secret bilgileri içerdiği için GitHub’a yüklenmemelidir.

---

## Sık Kullanılan Komutlar

Servis durumunu görüntüleme:

```bash
docker compose -f compose.yaml ps
```

Son logları görüntüleme:

```bash
docker compose -f compose.yaml logs --tail=100
```

Canlı log izleme:

```bash
docker compose -f compose.yaml logs -f
```

Servisleri yeniden başlatma:

```bash
docker compose -f compose.yaml up -d
```

Servisleri durdurma:

```bash
docker compose -f compose.yaml down
```

Güncel imajları çekip yeniden başlatma:

```bash
git pull
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d --remove-orphans
```

---

## Ubuntu Kaldırma

USOM IOC Gateway servislerini kaldırmak için:

```bash
cd /opt/usom-ioc-gateway
sudo ./uninstall.sh
```

Docker Engine dahil daha kapsamlı kaldırma için:

```bash
cd /opt/usom-ioc-gateway
sudo ./uninstall.sh --purge-docker
```

> Aynı sunucuda başka Docker servisleri çalışıyorsa `--purge-docker` parametresi kullanılmamalıdır.

---
## Windows Kaldırma
```mkdir C:\USOM -Force
cd C:\USOM
git clone https://github.com/hguler07/usom-ioc-gateway.git
cd .\usom-ioc-gateway
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```
---
