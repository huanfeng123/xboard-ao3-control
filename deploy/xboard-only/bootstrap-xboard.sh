#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/huanfeng123/xboard-ao3-control/main/deploy/xboard-only}"
INSTALL_DIR="${INSTALL_DIR:-/root/xboard-only}"
SUDO_CMD=()
DOWNLOADER=""

log() { printf '[xboard-bootstrap] %s\n' "$*"; }
die() { printf '[xboard-bootstrap][WARN] %s\n' "$*" >&2; exit 1; }

init_privilege_helper() {
  if [ "$(id -u)" -eq 0 ]; then
    SUDO_CMD=()
  elif command -v sudo >/dev/null 2>&1; then
    SUDO_CMD=(sudo)
  else
    die "请使用 root 运行，或先安装 sudo"
  fi
}

run_privileged() {
  "${SUDO_CMD[@]}" "$@"
}

ensure_downloader() {
  if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
    return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
    return 0
  fi
  command -v apt-get >/dev/null 2>&1 || die "缺少 curl/wget，且无法自动安装"
  run_privileged apt-get update
  run_privileged apt-get install -y curl
  DOWNLOADER="curl"
}

download_file() {
  local url="$1"
  local output="$2"
  if [ "$DOWNLOADER" = "curl" ]; then
    run_privileged curl -fsSL "$url" -o "$output"
  else
    run_privileged wget -qO "$output" "$url"
  fi
}

prepare_dir() {
  log "准备安装目录: $INSTALL_DIR"
  run_privileged mkdir -p "$INSTALL_DIR"
}

download_package() {
  local file
  local files=(
    "bootstrap-xboard.sh"
    "install-xboard.sh"
    "update-xboard.sh"
    "menu-xboard.sh"
    "xboard-common.sh"
    "xboard-extra.sh"
    "xboard-runtime.sh"
    "firewall.sh"
    "README.md"
  )
  for file in "${files[@]}"; do
    log "下载 ${file}"
    download_file "${BASE_URL}/${file}" "${INSTALL_DIR}/${file}"
  done
}

set_permissions() {
  run_privileged chmod +x \
    "$INSTALL_DIR/bootstrap-xboard.sh" \
    "$INSTALL_DIR/install-xboard.sh" \
    "$INSTALL_DIR/update-xboard.sh" \
    "$INSTALL_DIR/menu-xboard.sh" \
    "$INSTALL_DIR/xboard-common.sh" \
    "$INSTALL_DIR/firewall.sh"
}

main() {
  init_privilege_helper
  ensure_downloader
  prepare_dir
  download_package
  set_permissions
  log "开始执行交互式安装"
  if [ "$(id -u)" -eq 0 ]; then
    exec bash "$INSTALL_DIR/install-xboard.sh" --interactive
  fi
  exec "${SUDO_CMD[@]}" bash "$INSTALL_DIR/install-xboard.sh" --interactive
}

main "$@"
