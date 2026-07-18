# USOM IOC Gateway Deploy Package

USOM IOC Gateway, USOM IOC verilerini Docker üzerinden çalıştırıp güvenlik cihazları için TXT feed olarak yayınlayan bir IOC gateway projesidir.

Bu paket deploy-only hazırlanmıştır. Kaynak kod içermez. Kurulum Docker Hub üzerindeki hazır image sürümleri ile yapılır.

Bu proje bağımsızdır. Resmi USOM ürünü değildir.

## Kullanılan Image Sürümleri

- Backend: hguler07/usom-ioc-gateway:backend-0.1.9
- Nginx/UI: hguler07/usom-ioc-gateway:nginx-0.1.14

## Kurulum

1. Dosyaları sunucuya indirin.
2. .env.example dosyasını .env olarak kopyalayın.
3. CHANGE_ME değerlerini değiştirin.
4. install.sh dosyasını çalıştırın.

Komutlar:

cp .env.example .env
chmod +x install.sh
./install.sh

Varsayılan erişim:

http://SUNUCU_IP

Port değiştirmek için .env içine örnek olarak şunu ekleyebilirsiniz:

TFG_HTTP_PORT=8080

Bu durumda erişim adresi:

http://SUNUCU_IP:8080

## Feed Adresi

Feed dosyaları şu path altında yayınlanır:

/feeds/

## Güvenlik Notları

- Kurulumdan önce .env içindeki CHANGE_ME değerlerini değiştirin.
- Web arayüzünü internete açık bırakmayın.
- Firewall veya reverse proxy arkasında yayınlayın.
- Üretim ortamında düzenli veritabanı yedeği alın.
