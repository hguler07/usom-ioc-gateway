# USOM IOC Gateway

USOM IOC Gateway, USOM IOC verilerini alıp güvenlik cihazları için TXT feed olarak yayınlayan Docker tabanlı bağımsız bir IOC gateway projesidir.

> Bu proje resmi USOM ürünü değildir.

## Tek Komut Ubuntu Kurulumu

Sıfır Ubuntu sunucuda Docker yoksa kurar, repo dosyalarını indirir ve sistemi başlatır:

curl -fsSL https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/bootstrap-ubuntu.sh -o bootstrap-ubuntu.sh
chmod +x bootstrap-ubuntu.sh
./bootstrap-ubuntu.sh

## Manuel Kurulum

Docker zaten kuruluysa:

git clone https://github.com/hguler07/usom-ioc-gateway.git
cd usom-ioc-gateway
chmod +x install.sh
./install.sh

## Kurulum Mantığı

Bu repo kaynak kod içermez. Sadece kurulum dosyalarını içerir.

Uygulama Docker Hub üzerindeki hazır image sürümleriyle çalışır:

- Backend: hguler07/usom-ioc-gateway:backend-0.1.9
- Nginx/UI: hguler07/usom-ioc-gateway:nginx-0.1.14

install.sh ilk çalıştırmada .env dosyasını oluşturur ve şu değerleri otomatik üretir:

- SECRET_KEY
- POSTGRES_PASSWORD
- DJANGO_SUPERUSER_PASSWORD

Kurulum sonunda admin kullanıcı adı ve admin şifresi ekranda gösterilir.

## Erişim

Varsayılan adres:
http://SUNUCU_IP

Varsayılan kullanıcı adı: admin

## Feed Adresi

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
