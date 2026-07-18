#!/usr/bin/env bash
set -e
echo "USOM IOC Gateway kurulumu başlıyor..."
if [ ! -f ".env" ]; then
  cp .env.example .env
  echo ".env oluşturuldu."
fi
gen_secret() { openssl rand -base64 32 | tr -d "\n"; }
sed -i "s|^SECRET_KEY=CHANGE_ME|SECRET_KEY=$(gen_secret)|g" .env
sed -i "s|^POSTGRES_PASSWORD=CHANGE_ME|POSTGRES_PASSWORD=$(gen_secret)|g" .env
sed -i "s|^DJANGO_SUPERUSER_PASSWORD=CHANGE_ME|DJANGO_SUPERUSER_PASSWORD=$(gen_secret)|g" .env
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d
docker compose -f compose.yaml ps
ADMIN_USER=$(grep "^DJANGO_SUPERUSER_USERNAME=" .env | cut -d= -f2-)
ADMIN_PASS=$(grep "^DJANGO_SUPERUSER_PASSWORD=" .env | cut -d= -f2-)
HTTP_PORT=$(grep "^TFG_HTTP_PORT=" .env | cut -d= -f2-)
echo "Kurulum tamamlandı."
echo "Adres: http://SUNUCU_IP:${HTTP_PORT:-80}"
echo "Admin kullanıcı: $ADMIN_USER"
echo "Admin şifre: $ADMIN_PASS"
