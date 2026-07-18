#!/usr/bin/env bash
set -e

echo "USOM IOC Gateway kurulumu başlıyor..."

if docker ps >/dev/null 2>&1; then
  DC="docker compose"
elif sudo docker ps >/dev/null 2>&1; then
  DC="sudo docker compose"
else
  echo "HATA: Docker çalışmıyor veya erişilemiyor."
  echo "Çözüm: sudo systemctl enable --now docker"
  exit 1
fi

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo ".env oluşturuldu."
else
  echo ".env zaten var. Mevcut ayarlar korunacak."
fi

gen_secret() {
  openssl rand -base64 32 | tr -d "\n"
}

replace_if_needed() {
  KEY="$1"
  VALUE="$2"

  if grep -q "^${KEY}=CHANGE_ME" .env; then
    sed -i "s|^${KEY}=CHANGE_ME|${KEY}=${VALUE}|g" .env
    echo "$KEY otomatik üretildi."
  fi
}

replace_if_needed "SECRET_KEY" "$(gen_secret)"
replace_if_needed "POSTGRES_PASSWORD" "$(gen_secret)"
replace_if_needed "DJANGO_SUPERUSER_PASSWORD" "$(gen_secret)"

echo
echo "Docker image'ları kontrol ediliyor..."
$DC -f compose.yaml pull

echo
echo "Servisler başlatılıyor / güncelleniyor..."
$DC -f compose.yaml up -d

echo
echo "Servis durumu:"
$DC -f compose.yaml ps

ADMIN_USER=$(grep "^DJANGO_SUPERUSER_USERNAME=" .env | cut -d= -f2-)
ADMIN_PASS=$(grep "^DJANGO_SUPERUSER_PASSWORD=" .env | cut -d= -f2-)
HTTP_PORT=$(grep "^TFG_HTTP_PORT=" .env | cut -d= -f2-)

echo
echo "Kurulum tamamlandı."
echo "Adres: http://SUNUCU_IP:${HTTP_PORT:-80}"
echo "Admin kullanıcı: ${ADMIN_USER:-admin}"
echo "Admin şifre: ${ADMIN_PASS}"
echo
echo "Not: Bu script tekrar çalıştırılırsa mevcut .env ve veritabanı korunur."
