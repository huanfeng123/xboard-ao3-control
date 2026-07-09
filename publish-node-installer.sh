#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="/root/xboard-only/runtime/Xboard"
SOURCE_DIR="/root/Xboard-Node"
PUBLIC_DIR="$ROOT_DIR/storage/app/public/xboard-node"
LATEST_DIR="$PUBLIC_DIR/releases/latest/download"
CONTAINER_NAME="xboard-xboard-1"
VERSION=""
REBUILD_PANEL=0
SKIP_BUILD=0

log() {
  printf '[publish-node] %s\n' "$*"
}

copy_into_container_public() {
  local src="$1"
  local rel="$2"
  local tmp="/tmp/$(basename "$src").$$"
  docker cp "$src" "$CONTAINER_NAME:$tmp"
  docker exec "$CONTAINER_NAME" sh -lc "mkdir -p '/www/storage/app/public/$(dirname "$rel")' && install -m 755 '$tmp' '/www/storage/app/public/$rel' && rm -f '$tmp'"
}

usage() {
  cat <<'EOF'
Usage:
  publish-node-installer.sh [--version VERSION] [--rebuild-panel] [--skip-build]

Options:
  --version VERSION   Publish artifacts into releases/download/VERSION
                      Default: git describe from /root/Xboard-Node
  --rebuild-panel     Run docker compose up -d in the Xboard runtime after publish
  --skip-build        Reuse existing binaries in /root/Xboard-Node
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --rebuild-panel)
      REBUILD_PANEL=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Missing source dir: $SOURCE_DIR" >&2
  exit 1
fi

if [ -z "$VERSION" ]; then
  VERSION="$(git -C "$SOURCE_DIR" describe --tags --always --dirty 2>/dev/null || echo dev)"
fi

mkdir -p "$LATEST_DIR" "$PUBLIC_DIR/releases/download/$VERSION"

if [ "$SKIP_BUILD" -ne 1 ]; then
  log "Building patched xboard-node binaries for amd64 and arm64"
  docker run --rm -v "$SOURCE_DIR:/src" -w /src golang:1.26 make build-all
else
  log "Skipping build; using existing binaries in $SOURCE_DIR"
fi

for file in \
  install.sh \
  xboard-node-linux-amd64 \
  xbctl-linux-amd64 \
  xboard-node-linux-arm64 \
  xbctl-linux-arm64
do
  if [ ! -f "$SOURCE_DIR/$file" ]; then
    echo "Missing required artifact: $SOURCE_DIR/$file" >&2
    exit 1
  fi
done

log "Publishing installer script"
copy_into_container_public "$SOURCE_DIR/install.sh" "xboard-node/install.sh"

log "Publishing latest release artifacts"
copy_into_container_public "$SOURCE_DIR/xboard-node-linux-amd64" "xboard-node/releases/latest/download/xboard-node-linux-amd64"
copy_into_container_public "$SOURCE_DIR/xbctl-linux-amd64" "xboard-node/releases/latest/download/xbctl-linux-amd64"
copy_into_container_public "$SOURCE_DIR/xboard-node-linux-arm64" "xboard-node/releases/latest/download/xboard-node-linux-arm64"
copy_into_container_public "$SOURCE_DIR/xbctl-linux-arm64" "xboard-node/releases/latest/download/xbctl-linux-arm64"

VERSION_DIR="$PUBLIC_DIR/releases/download/$VERSION"
log "Publishing versioned artifacts to $VERSION_DIR"
copy_into_container_public "$SOURCE_DIR/xboard-node-linux-amd64" "xboard-node/releases/download/$VERSION/xboard-node-linux-amd64"
copy_into_container_public "$SOURCE_DIR/xbctl-linux-amd64" "xboard-node/releases/download/$VERSION/xbctl-linux-amd64"
copy_into_container_public "$SOURCE_DIR/xboard-node-linux-arm64" "xboard-node/releases/download/$VERSION/xboard-node-linux-arm64"
copy_into_container_public "$SOURCE_DIR/xbctl-linux-arm64" "xboard-node/releases/download/$VERSION/xbctl-linux-arm64"

if [ "$REBUILD_PANEL" -eq 1 ]; then
  log "Rebuilding panel container"
  docker compose up -d
fi

log "Done"
log "Installer: https://web.ao3l.live/storage/xboard-node/install.sh"
log "Latest amd64 binary: https://web.ao3l.live/storage/xboard-node/releases/latest/download/xboard-node-linux-amd64"
log "Version: $VERSION"
