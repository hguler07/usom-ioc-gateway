#!/usr/bin/env bash
set -e

echo "USOM IOC Gateway kurulumu başlıyor..."

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo ".env oluşturuldu."
  echo "Lütfen .env içindeki CHANGE_ME değerlerini değiştirip tekrar ./install.sh çalıştırın."
  exit 0
fi

if grep -q "CHANGE_ME" .env; then
  echo "UYARI: .env içinde CHANGE_ME değerleri var. Önce bunları değiştirin."
  exit 0
fi

docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d

docker compose -f compose.yaml ps

echo "Kurulum tamamlandı."
echo "Adres: http://SUNUCU_IP"
