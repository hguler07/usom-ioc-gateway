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

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin eksik. Kuruluyor..."
  $SUDO apt install -y docker-compose-plugin
fi

if [ ! -d "$APP_DIR" ]; then
  echo "Repo indiriliyor: $APP_DIR"
  $SUDO git clone "$REPO_URL" "$APP_DIR"
else
  echo "Repo zaten var. Güncelleniyor..."
  cd "$APP_DIR"
  $SUDO git pull
fi

$SUDO chown -R "$USER":"$USER" "$APP_DIR" 2>/dev/null || true
cd "$APP_DIR"
chmod +x install.sh
./install.sh
