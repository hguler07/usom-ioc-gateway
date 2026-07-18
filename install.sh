#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "USOM IOC Gateway kurulumu başlıyor..."

if docker ps >/dev/null 2>&1; then
  DC="docker compose"
elif sudo docker ps >/dev/null 2>&1; then
  DC="sudo docker compose"
else
  echo "HATA: Docker çalışmıyor veya bu kullanıcı Docker kullanamıyor."
  echo "Çözüm: sudo systemctl enable --now docker"
  exit 1
fi

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo ".env oluşturuldu."
else
  echo ".env zaten var. Mevcut ayarlar korunacak."
fi

while IFS= read -r line; do
  case "$line" in
    ""|"#"*) continue ;;
  esac

  if echo "$line" | grep -qE '^[A-Z0-9_]+='; then
    key="${line%%=*}"
    if ! grep -q "^${key}=" .env; then
      echo "$line" >> .env
      echo "$key eklendi."
    fi
  fi
done < .env.example

gen_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32 | tr -d "\n"
  else
    tr -dc 'A-Za-z0-9_@%+=:.,-' < /dev/urandom | head -c 48
  fi
}

replace_if_needed() {
  key="$1"

  if grep -q "^${key}=CHANGE_ME" .env || grep -q "^${key}=$" .env; then
    value="$(gen_secret)"
    sed -i "s|^${key}=.*|${key}=${value}|g" .env
    echo "$key otomatik üretildi."
  fi
}

replace_if_needed "SECRET_KEY"
replace_if_needed "POSTGRES_PASSWORD"
replace_if_needed "DJANGO_SUPERUSER_PASSWORD"

echo
echo "Docker image'ları indiriliyor/güncelleniyor..."
$DC -f compose.yaml pull

echo
echo "Servisler başlatılıyor/güncelleniyor..."
$DC -f compose.yaml up -d

echo
echo "Servis durumu:"
$DC -f compose.yaml ps

ADMIN_USER=$(grep "^DJANGO_SUPERUSER_USERNAME=" .env | cut -d= -f2- || true)
ADMIN_PASS=$(grep "^DJANGO_SUPERUSER_PASSWORD=" .env | cut -d= -f2- || true)
HTTP_PORT=$(grep "^TFG_HTTP_PORT=" .env | cut -d= -f2- || true)

echo
echo "Kurulum tamamlandı."
echo "Adres: http://SUNUCU_IP:${HTTP_PORT:-80}"
echo "Admin kullanıcı: ${ADMIN_USER:-admin}"
echo "Admin şifre: ${ADMIN_PASS}"
echo
echo "Not: Script tekrar çalıştırılırsa .env ve veritabanı korunur."
