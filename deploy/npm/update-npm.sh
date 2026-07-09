#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/npm-common.sh"

main() {
  load_deploy_env
  validate_config
  ensure_compose_ready
  prepare_dirs
  [ -f "$NPM_DIR/compose.yaml" ] || die "未找到 NPM 部署目录，请先执行 ./install-npm.sh"
  write_npm_compose
  log "更新 Nginx Proxy Manager 镜像"
  run_compose "$NPM_DIR" pull
  run_compose "$NPM_DIR" up -d
  install_menu_shortcut
  log "NPM 更新完成"
}

main "$@"
