#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/huanfeng123/xboard-ao3-control/main/deploy/npm}"
INSTALL_DIR="${INSTALL_DIR:-/root/npm-only}"
SUDO_CMD=()
DOWNLOADER=""

log() {
  printf '[npm-bootstrap] %s\n' "$*"
}

die() {
  printf '[npm-bootstrap][WARN] %s\n' "$*" >&2
  exit 1
}

init_privilege_helper() {
  if [ "$(id -u)" -eq 0 ]; then
    SUDO_CMD=()
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    SUDO_CMD=(sudo)
    return 0
  fi

  die "请使用 root 运行，或先安装 sudo"
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

  if ! command -v apt-get >/dev/null 2>&1; then
    die "缺少 curl/wget，且无法自动安装"
  fi

  log "未检测到 curl/wget，尝试安装 curl"
  run_privileged apt-get update
  run_privileged apt-get install -y curl
  DOWNLOADER="curl"
}

download_file() {
  local url="$1"
  local output="$2"

  if [ "$DOWNLOADER" = "curl" ]; then
    run_privileged curl -fsSL "$url" -o "$output"
    return 0
  fi

  run_privileged wget -qO "$output" "$url"
}

prepare_dir() {
  log "准备安装目录: $INSTALL_DIR"
  run_privileged mkdir -p "$INSTALL_DIR"
}

download_package() {
  local file
  local files=(
    "bootstrap-npm.sh"
    "install-npm.sh"
    "update-npm.sh"
    "menu-npm.sh"
    "npm-common.sh"
    "npm-extra.sh"
    "firewall.sh"
  )

  for file in "${files[@]}"; do
    log "下载 ${file}"
    download_file "${BASE_URL}/${file}" "${INSTALL_DIR}/${file}"
  done

}

set_permissions() {
  run_privileged chmod +x \
    "$INSTALL_DIR/bootstrap-npm.sh" \
    "$INSTALL_DIR/install-npm.sh" \
    "$INSTALL_DIR/update-npm.sh" \
    "$INSTALL_DIR/menu-npm.sh" \
    "$INSTALL_DIR/npm-common.sh" \
    "$INSTALL_DIR/npm-extra.sh" \
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
    exec bash "$INSTALL_DIR/install-npm.sh" --interactive
  fi

  exec "${SUDO_CMD[@]}" bash "$INSTALL_DIR/install-npm.sh" --interactive
}

main "$@"
