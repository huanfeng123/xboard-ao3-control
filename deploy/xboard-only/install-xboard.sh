#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERACTIVE_CONFIG=0

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/xboard-common.sh"

print_usage() {
  cat <<EOF
用法：
  ./install-xboard.sh [--interactive|-i] [--non-interactive]

说明：
  仅安装新版 Xboard，不安装 NPM。
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --interactive|-i) INTERACTIVE_CONFIG=1 ;;
      --non-interactive) INTERACTIVE_CONFIG=0 ;;
      --help|-h) print_usage; exit 0 ;;
      *) die "不支持的参数: $1" ;;
    esac
    shift
  done
}

prompt_value() {
  local label="$1"
  local current="$2"
  local answer
  printf '%s [%s]: ' "$label" "$current" >&2
  read -r answer || true
  [ -n "$answer" ] && printf '%s' "$answer" || printf '%s' "$current"
}

prompt_port() {
  local label="$1"
  local current="$2"
  local value
  while true; do
    value="$(prompt_value "$label" "$current")"
    if is_valid_port "$value"; then
      printf '%s' "$value"
      return 0
    fi
    warn "请输入 1-65535 之间的端口号"
  done
}

configure_interactively() {
  [ "$INTERACTIVE_CONFIG" = "1" ] || return 0
  [ -t 0 ] || die "交互模式需要 TTY"
  log "进入 Xboard 交互式配置"
  XBOARD_PORT="$(prompt_port 'Xboard 对外端口' "$XBOARD_PORT")"
  XBOARD_ADMIN_EMAIL="$(prompt_value 'Xboard 管理员邮箱' "$XBOARD_ADMIN_EMAIL")"
}

write_deploy_env() {
  [ "$AUTO_WRITE_DEPLOY_ENV" = "1" ] || return 0
  cat >"$DEPLOY_ENV_FILE" <<EOF
# xboard-only local config
# 由 install-xboard.sh 自动生成/更新
SERVER_IP=${SERVER_IP}
XBOARD_PORT=${XBOARD_PORT}
XBOARD_ADMIN_EMAIL=${XBOARD_ADMIN_EMAIL}
XBOARD_REPO=${XBOARD_REPO}
XBOARD_BRANCH=${XBOARD_BRANCH}
ENABLE_FIREWALL_OPEN=${ENABLE_FIREWALL_OPEN}
FORCE_XBOARD_INSTALL=${FORCE_XBOARD_INSTALL}
AUTO_INSTALL_DEPS=${AUTO_INSTALL_DEPS}
EOF
}

print_summary() {
  printf '\n部署完成。\n\n'
  printf '当前配置：\n'
  printf -- '- Xboard 对外端口: %s\n' "$XBOARD_PORT"
  printf -- '- Xboard 管理员邮箱: %s\n' "$XBOARD_ADMIN_EMAIL"
  printf '\n目录：\n'
  printf -- '- Xboard: %s\n' "$XBOARD_DIR"
  printf -- '- 配置文件: %s\n' "$DEPLOY_ENV_FILE"
  printf -- '- 管理快捷命令: %s\n' "$MENU_COMMAND"
  printf '\n访问入口：\n'
  printf -- '- Xboard 首页: http://%s:%s\n' "$DETECTED_SERVER_IP" "$XBOARD_PORT"
  if [ -n "$XBOARD_ADMIN_PATH" ]; then
    printf -- '- Xboard 管理面板: http://%s:%s/%s\n' \
      "$DETECTED_SERVER_IP" "$XBOARD_PORT" "$XBOARD_ADMIN_PATH"
  else
    printf -- '- Xboard 管理面板: 安装完成后会自动生成安全路径\n'
  fi
  printf '\n已尝试放行端口：\n'
  printf -- '- %s/tcp\n' "$XBOARD_PORT"
  printf '\n建议下一步：\n'
  printf -- '1. 打开 Xboard 管理面板完成后续配置\n'
  printf -- '2. 如需域名反代，可使用 NPM 或其他反代工具转发到 http://%s:%s\n' \
    "$DETECTED_SERVER_IP" "$XBOARD_PORT"
}

main() {
  parse_args "$@"
  load_deploy_env
  configure_interactively
  validate_config
  write_deploy_env
  resolve_server_ip
  init_privilege_helper
  install_missing_dependencies
  ensure_compose_ready
  prepare_dirs
  install_xboard
  install_menu_shortcut
  resolve_xboard_admin_path
  open_firewall_ports || warn "防火墙未自动放行，请手动检查"
  print_summary
}

main "$@"
