# USOM IOC Gateway

<p align="center">
  <b>USOM tehdit göstergelerini senkronize eden ve güvenlik ürünleri için TXT formatında IOC feed yayınlayan Docker tabanlı gateway.</b>
</p>

<p align="center">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-ready-blue">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Windows%20%7C%20macOS-lightgrey">
  <img alt="Database" src="https://img.shields.io/badge/Database-PostgreSQL-blue">
  <img alt="Project Type" src="https://img.shields.io/badge/Type-Deploy--only-success">
</p>

---

## Genel Bakış

**USOM IOC Gateway**, USOM tarafından yayınlanan tehdit göstergelerini otomatik olarak senkronize eden ve bu verileri firewall, güvenlik ağ geçidi, SIEM ve benzeri güvenlik ürünlerinin tüketebileceği sade TXT feed formatında yayınlayan Docker tabanlı bir kurulum paketidir.

Bu proje, USOM IOC verilerini manuel olarak indirmek, ayrıştırmak ve güncel tutmak yerine kurum içinde merkezi ve yönetilebilir bir IOC feed servisi oluşturmak isteyen ekipler için geliştirilmiştir.

> Bu repository bir **deploy-only** pakettir.
> Uygulama kaynak kodlarını içermez. Sistem, `hguler07/usom-ioc-gateway` altında yayınlanan hazır Docker imajları ile çalışır.

---

## Ne İşe Yarar?

USOM IOC Gateway aşağıdaki tehdit göstergelerini ayrı feed formatlarında toplar ve yayınlar:

* Domain IOC kayıtları
* IPv4 IOC kayıtları
* IPv6 IOC kayıtları
* URL IOC kayıtları
* Firewall uyumlu TXT feed çıktıları
* Web tabanlı yönetim arayüzü
* PostgreSQL tabanlı IOC veritabanı
* Otomatik senkronizasyon motoru
* Worker tabanlı işleme mimarisi
* Temel sistem sağlık görünürlüğü

---

## Mimari

Kurulum Docker Compose ile çalışır ve aşağıdaki servisleri ayağa kaldırır:

| Bileşen         | Açıklama                             |
| --------------- | ------------------------------------ |
| `db`            | PostgreSQL veritabanı                |
| `web`           | Django web uygulaması ve API servisi |
| `orchestrator`  | IOC senkronizasyon zamanlayıcısı     |
| `worker-domain` | Domain IOC işleyici                  |
| `worker-ip`     | IPv4 IOC işleyici                    |
| `worker-url`    | URL IOC işleyici                     |
| `worker-ipv6`   | IPv6 IOC işleyici                    |
| `nginx`         | Web arayüzü ve feed yayın katmanı    |

Kullanılan uygulama imajları `compose.yaml` dosyası içerisinde tanımlıdır.

---

## Minimum Sistem Gereksinimleri

| Ortam                  |    CPU |  RAM |  Disk |
| ---------------------- | -----: | ---: | ----: |
| Önerilen küçük kurulum | 2 vCPU | 4 GB | 40 GB |

Önerilen işletim sistemi:

* Ubuntu Server 22.04 LTS veya üzeri
* Docker Engine
* Docker Compose Plugin
* USOM API ve Docker Hub erişimi
* TCP `80` portu veya özel bir HTTP portu

> Kaynak kullanımı IOC hacmine, senkronizasyon sıklığına, feed boyutuna, log saklama süresine ve Change History verisinin büyümesine göre değişebilir.

---

## Ubuntu Hızlı Kurulum

Temiz bir Ubuntu sunucu üzerinde aşağıdaki komutları çalıştırabilirsiniz:

```bash
curl -fsSL https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/bootstrap-ubuntu.sh -o bootstrap-ubuntu.sh
chmod +x bootstrap-ubuntu.sh
sudo ./bootstrap-ubuntu.sh
```

Bootstrap kurulumu aşağıdaki işlemleri yapar:

* Gerekli paketleri kurar
* Docker yüklü değilse kurar
* Docker Compose Plugin yüklü değilse kurar
* Repository dosyalarını `/opt/usom-ioc-gateway` dizinine indirir
* `.env` dosyasını oluşturur
* Gerekli secret ve parolaları üretir
* Docker imajlarını indirir
* Servisleri başlatır

Kurulumdan sonra web arayüzüne aşağıdaki adresten erişebilirsiniz:

```text
http://SUNUCU_IP_ADRESI
```

Varsayılan admin kullanıcı adı:

```text
admin
```

Admin parolası kurulum sonunda otomatik olarak üretilir ve ekranda bir kez gösterilir.

---

## Ubuntu Manuel Kurulum

Docker zaten kuruluysa aşağıdaki yöntemi kullanabilirsiniz:

```bash
git clone https://github.com/hguler07/usom-ioc-gateway.git
cd usom-ioc-gateway
chmod +x install.sh
sudo ./install.sh
```

Servis durumunu kontrol etmek için:

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

PowerShell’i Yönetici olarak açın ve aşağıdaki komutları çalıştırın:

```powershell
git clone https://github.com/hguler07/usom-ioc-gateway.git
cd usom-ioc-gateway
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

Varsayılan erişim adresi:

```text
http://localhost:8080
```

---

## macOS Kurulumu

Gereksinimler:

* Docker Desktop for Mac
* Git
* Terminal

Kurulum:

```bash
git clone https://github.com/hguler07/usom-ioc-gateway.git
cd usom-ioc-gateway
cp .env.example .env
echo "TFG_HTTP_PORT=8080" >> .env
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d
```

Varsayılan erişim adresi:

```text
http://localhost:8080
```

---

## Feed Adresleri

IOC feed çıktıları aşağıdaki dizin altında yayınlanır:

```text
/feeds/
```

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

Kurulum sırasında `.env.example` dosyasından lokal bir `.env` dosyası oluşturulur.

Önemli değişkenler:

| Değişken                        | Açıklama                                  |
| ------------------------------- | ----------------------------------------- |
| `TFG_HTTP_PORT`                 | Nginx tarafından dışarı açılan HTTP portu |
| `DJANGO_ALLOWED_HOSTS`          | İzin verilen hostname veya IP adresleri   |
| `POSTGRES_DB`                   | PostgreSQL veritabanı adı                 |
| `POSTGRES_USER`                 | PostgreSQL kullanıcı adı                  |
| `POSTGRES_PASSWORD`             | PostgreSQL kullanıcı parolası             |
| `DJANGO_SUPERUSER_USERNAME`     | İlk admin kullanıcı adı                   |
| `DJANGO_SUPERUSER_PASSWORD`     | İlk admin kullanıcı parolası              |
| `USOM_FETCH_CONCURRENCY`        | USOM veri çekme eşzamanlılık değeri       |
| `ORCHESTRATOR_INTERVAL_SECONDS` | Senkronizasyon aralığı                    |

Placeholder değerler tespit edilirse kurulum sırasında gerekli parola ve secret değerleri otomatik olarak üretilir.

> `.env` dosyasını GitHub’a yüklemeyin.

---

## Sık Kullanılan Komutlar

Çalışan servisleri kontrol etmek için:

```bash
docker compose -f compose.yaml ps
```

Logları görüntülemek için:

```bash
docker compose -f compose.yaml logs --tail=100
```

Canlı log izlemek için:

```bash
docker compose -f compose.yaml logs -f
```

Servisleri yeniden başlatmak için:

```bash
docker compose -f compose.yaml up -d
```

Servisleri durdurmak için:

```bash
docker compose -f compose.yaml down
```

Son imajları çekip sistemi güncellemek için:

```bash
git pull
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d --remove-orphans
```

---

## Kaldırma

Yalnızca USOM IOC Gateway container, volume, image ve uygulama dosyalarını kaldırmak için:

```bash
cd /opt/usom-ioc-gateway
sudo ./uninstall.sh
```

USOM IOC Gateway ile birlikte Docker Engine’i de kaldırmak için:

```bash
cd /opt/usom-ioc-gateway
sudo ./uninstall.sh --purge-docker
```

> Dikkat: `--purge-docker` Docker Engine’i ve Docker sistem verilerini kaldırır.
> Aynı sunucuda başka Docker servisleri çalışıyorsa bu parametreyi kullanmayın.

---

## Güvenlik Notları

* Web arayüzünü doğrudan internete açmanız önerilmez.
* Erişimi VPN, firewall kuralı veya güvenilir reverse proxy arkasından sağlayın.
* Üretim ortamında `DJANGO_ALLOWED_HOSTS=*` yerine açık hostname veya IP adresleri tanımlayın.
* Kurulumda üretilen admin parolasını güvenli bir parola yöneticisinde saklayın.
* `.env` dosyasını gizli tutun.
* Feed adreslerini kurum dışına açmadan önce firewall kurallarını gözden geçirin.

---

## Sorumluluk Reddi

Bu proje bağımsız bir topluluk projesidir.

Resmi bir USOM ürünü değildir. USOM veya herhangi bir kamu kurumu tarafından geliştirilmemiş, desteklenmemiş veya onaylanmamıştır.

Kullanım sorumluluğu kullanıcıya aittir. Kurumunuzun güvenlik politikalarına, yasal yükümlülüklerine ve operasyonel prosedürlerine uygun şekilde kullanmanız önerilir.

---

## Proje Durumu

Bu proje şu anda deploy-only paket olarak yayınlanmaktadır ve aktif olarak geliştirilmektedir.

Planlanan geliştirme alanları:

* Daha detaylı sistem sağlık kontrolleri
* Senkronizasyon durumunun daha görünür hale getirilmesi
* Bakım ve kurtarma işlemlerinin iyileştirilmesi
* Feed doğrulama ve last-known-good feed yapısı
* Daha kapsamlı kurulum ve kullanım dokümantasyonu

---

## Repository

```text
https://github.com/hguler07/usom-ioc-gateway
```

Geliştirici:

```text
Hüseyin Güler
```
