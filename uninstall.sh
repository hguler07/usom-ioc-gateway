#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/usom-ioc-gateway}"
COMPOSE_FILE="$APP_DIR/compose.yaml"
PURGE_DOCKER=0
ASSUME_YES=0

for arg in "$@"; do
  case "$arg" in
    --purge-docker)
      PURGE_DOCKER=1
      ;;
    --yes|-y)
      ASSUME_YES=1
      ;;
    *)
      echo "Bilinmeyen parametre: $arg"
      echo "Kullanım:"
      echo "  sudo ./uninstall.sh"
      echo "  sudo ./uninstall.sh --purge-docker"
      exit 1
      ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "HATA: Bu script root yetkisi ile çalıştırılmalıdır."
  echo "Örnek: sudo ./uninstall.sh"
  exit 1
fi

echo "USOM IOC Gateway kaldırma işlemi başlıyor."
echo
echo "Silinecekler:"
echo "- USOM IOC Gateway container'ları"
echo "- USOM IOC Gateway Docker volume'ları"
echo "- USOM IOC Gateway image'ları"
echo "- $APP_DIR klasörü"
echo "- .env dosyası ve veritabanı dahil tüm uygulama verileri"
echo

if [ "$PURGE_DOCKER" = "1" ]; then
  echo "EK OLARAK:"
  echo "- Docker Engine"
  echo "- Docker Compose plugin"
  echo "- Docker sistem verileri"
  echo
  echo "UYARI: Bu sunucuda başka Docker container/image/volume varsa onlar da etkilenebilir."
fi

if [ "$ASSUME_YES" != "1" ]; then
  echo
  read -r -p "Devam etmek için DELETE_USOM_IOC_GATEWAY yazın: " CONFIRM
  if [ "$CONFIRM" != "DELETE_USOM_IOC_GATEWAY" ]; then
    echo "İşlem iptal edildi."
    exit 0
  fi

  if [ "$PURGE_DOCKER" = "1" ]; then
    read -r -p "Docker da silinsin istiyorsanız DELETE_DOCKER_TOO yazın: " CONFIRM_DOCKER
    if [ "$CONFIRM_DOCKER" != "DELETE_DOCKER_TOO" ]; then
      echo "Docker silme onayı verilmedi. İşlem iptal edildi."
      exit 0
    fi
  fi
fi

DOCKER_CMD=""

if command -v docker >/dev/null 2>&1; then
  DOCKER_CMD="docker"
fi

if [ -n "$DOCKER_CMD" ]; then
  if [ -f "$COMPOSE_FILE" ]; then
    echo
    echo "USOM IOC Gateway servisleri durduruluyor ve volume'lar siliniyor..."
    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || true
  else
    echo
    echo "compose.yaml bulunamadı, container isimleri üzerinden temizlik deneniyor..."
    docker ps -a --format '{{.Names}}' | grep -E '^usom-ioc-gateway-|^threat-feed-gateway-' | xargs -r docker rm -f || true
  fi

  echo
  echo "USOM IOC Gateway image'ları siliniyor..."
  docker image ls --format '{{.Repository}}:{{.Tag}}' \
    | grep -E '^hguler07/usom-ioc-gateway:' \
    | xargs -r docker image rm -f || true

  echo
  echo "USOM IOC Gateway isimli volume/network kalıntıları temizleniyor..."
  docker volume ls --format '{{.Name}}' \
    | grep -E 'usom-ioc-gateway|threat-feed-gateway' \
    | xargs -r docker volume rm -f || true

  docker network ls --format '{{.Name}}' \
    | grep -E 'usom-ioc-gateway|threat-feed-gateway' \
    | xargs -r docker network rm || true
fi

echo
echo "Uygulama klasörü siliniyor: $APP_DIR"
cd /
rm -rf "$APP_DIR"

if [ "$PURGE_DOCKER" = "1" ]; then
  echo
  echo "Docker tamamen kaldırılıyor..."

  if command -v docker >/dev/null 2>&1; then
    docker ps -aq | xargs -r docker rm -f || true
    docker system prune -af --volumes || true
  fi

  systemctl disable --now docker 2>/dev/null || true
  systemctl disable --now containerd 2>/dev/null || true

  apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true
  apt autoremove -y || true

  rm -rf /var/lib/docker
  rm -rf /var/lib/containerd
  rm -rf /etc/docker
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/keyrings/docker.asc
fi

echo
echo "Kaldırma işlemi tamamlandı."
