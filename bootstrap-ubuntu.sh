#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/hguler07/usom-ioc-gateway.git"
APP_DIR="/opt/usom-ioc-gateway"

echo "USOM IOC Gateway Ubuntu kurulumu başlıyor..."

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "Gerekli paketler kontrol ediliyor..."
$SUDO apt update
$SUDO apt install -y ca-certificates curl git openssl

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker bulunamadı. Docker kuruluyor..."

  $SUDO install -m 0755 -d /etc/apt/keyrings
  $SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt update
  $SUDO apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "Docker zaten kurulu."
fi

$SUDO systemctl enable --now docker

if ! docker compose version >/dev/null 2>&1 && ! sudo docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin eksik. Kuruluyor..."
  $SUDO apt install -y docker-compose-plugin
fi

if [ ! -d "$APP_DIR" ]; then
  echo "Repo indiriliyor: $APP_DIR"
  $SUDO git clone "$REPO_URL" "$APP_DIR"
else
  echo "Repo zaten var. Güncelleniyor..."

  if [ ! -d "$APP_DIR/.git" ]; then
    echo "HATA: $APP_DIR klasörü var ama Git reposu değil."
    echo "Güvenlik için otomatik silme yapılmadı."
    echo "Temiz kurulum için ayrı uninstall/cleanup komutu kullanılmalı."
    exit 1
  fi

  $SUDO git config --global --add safe.directory "$APP_DIR" || true
  cd "$APP_DIR"
  $SUDO git pull
fi

cd "$APP_DIR"
chmod +x install.sh

if [ "$(id -u)" -eq 0 ]; then
  ./install.sh
else
  sudo ./install.sh
fi
