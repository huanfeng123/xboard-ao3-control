#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/xboard-common.sh"

main() {
  load_deploy_env
  validate_config
  ensure_compose_ready
  [ -d "$XBOARD_DIR/.git" ] || die "未找到 Xboard 运行目录，请先执行 ./install-xboard.sh"
  clone_or_update_xboard
  ensure_xboard_port_mapping
  prepare_xboard_env
  log "更新 Xboard 镜像并重建容器"
  run_compose "$XBOARD_DIR" pull
  run_compose "$XBOARD_DIR" up -d
  run_compose "$XBOARD_DIR" port xboard 7001
  install_menu_shortcut
  resolve_server_ip
  resolve_xboard_admin_path
  printf '更新完成: http://%s:%s\n' "$DETECTED_SERVER_IP" "$XBOARD_PORT"
}

main "$@"
