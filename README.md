# USOM IOC Gateway

USOM IOC Gateway, USOM IOC verilerini alıp güvenlik cihazları için TXT feed olarak yayınlayan Docker tabanlı bağımsız bir IOC gateway projesidir.

Bu proje resmi USOM ürünü değildir.

## Kurulum Mantığı

Bu repo kaynak kod içermez. Sadece kurulum dosyalarını içerir.

Uygulama Docker Hub üzerindeki hazır image sürümleriyle çalışır:

- Backend: hguler07/usom-ioc-gateway:backend-0.1.9
- Nginx/UI: hguler07/usom-ioc-gateway:nginx-0.1.14

Kullanıcı bu repoyu indirir, install.sh çalıştırır. Script Docker image dosyalarını Docker Hub üzerinden otomatik indirir ve sistemi başlatır.

## Gereksinimler

- Docker
- Docker Compose plugin

Kontrol:
docker --version
docker compose version

## Hızlı Kurulum

git clone https://github.com/hguler07/usom-ioc-gateway.git
cd usom-ioc-gateway
chmod +x install.sh
./install.sh

install.sh ilk çalıştırmada .env dosyasını oluşturur ve aşağıdaki değerleri otomatik üretir:

- SECRET_KEY
- POSTGRES_PASSWORD
- DJANGO_SUPERUSER_PASSWORD

Kurulum sonunda admin kullanıcı adı ve admin şifresi ekranda gösterilir.

## Erişim

Varsayılan adres:
http://SUNUCU_IP

Varsayılan kullanıcı adı:
admin

Admin şifresi kurulum sırasında otomatik üretilir.

## Port Değiştirme

Varsayılan port 80dir.

Farklı port için .env dosyasında şu değeri değiştirin veya ekleyin:
TFG_HTTP_PORT=8080

Sonra yeniden başlatın:
docker compose -f compose.yaml up -d

Yeni erişim örneği:
http://SUNUCU_IP:8080

## Feed Adresi

Feed dosyaları şu path altında yayınlanır:
/feeds/

Örnek:
http://SUNUCU_IP/feeds/

## Servis Komutları

Durum kontrolü:
docker compose -f compose.yaml ps

Log kontrolü:
docker compose -f compose.yaml logs --tail=100

Durdurma:
docker compose -f compose.yaml down

## Güvenlik Notları

- .env dosyasını GitHub reposuna yüklemeyin.
- Web arayüzünü doğrudan internete açık bırakmayın.
- Firewall veya reverse proxy arkasında yayınlayın.
- Kurulumda üretilen admin şifresini güvenli yerde saklayın.
- Üretim ortamında düzenli PostgreSQL yedeği alın.

## Tek Komut Ubuntu Kurulumu

Sıfır Ubuntu sunucuda Docker yoksa otomatik kurulum yapar, repo dosyalarını indirir ve sistemi başlatır:

curl -fsSL https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/bootstrap-ubuntu.sh -o bootstrap-ubuntu.sh
chmod +x bootstrap-ubuntu.sh
./bootstrap-ubuntu.sh
