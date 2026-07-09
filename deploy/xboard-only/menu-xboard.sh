#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/xboard-common.sh"

info() { printf '[INFO] %s\n' "$*"; }
success() { printf '[OK] %s\n' "$*"; }
pause() { read -r -p "按回车继续..." _; }

require_root() {
  [ "${TEST_MODE:-0}" = "1" ] && return 0
  [ "${EUID}" -eq 0 ] || die "请使用 root 用户运行菜单脚本"
}

show_service_status() {
  ensure_compose_ready
  run_compose "$XBOARD_DIR" ps
}

show_access_info() {
  load_deploy_env
  resolve_server_ip
  resolve_xboard_admin_path
  echo "- Xboard 对外端口: ${XBOARD_PORT}"
  echo "- Xboard 管理员邮箱: ${XBOARD_ADMIN_EMAIL}"
  echo "- Xboard 目录: ${XBOARD_DIR}"
  echo "- 配置文件: ${DEPLOY_ENV_FILE}"
  echo "- Xboard 首页: http://${DETECTED_SERVER_IP}:${XBOARD_PORT}"
  if [ -n "$XBOARD_ADMIN_PATH" ]; then
    echo "- Xboard 管理面板: http://${DETECTED_SERVER_IP}:${XBOARD_PORT}/${XBOARD_ADMIN_PATH}"
  else
    echo "- Xboard 管理面板: 安装完成后会自动生成安全路径"
  fi
  echo "- 管理快捷命令: ${MENU_COMMAND}"
}

service_action() {
  local action="$1"
  ensure_compose_ready
  case "$action" in
    up) run_compose "$XBOARD_DIR" up -d; success "Xboard 已启动" ;;
    restart) run_compose "$XBOARD_DIR" restart; success "Xboard 已重启" ;;
    logs) run_compose "$XBOARD_DIR" logs -f --tail=100 ;;
    *) die "不支持的操作: $action" ;;
  esac
}

open_custom_ports() {
  local raw token
  local ports=()
  [ -f "$FIREWALL_HELPER_FILE" ] || die "未找到防火墙助手脚本"
  # shellcheck disable=SC1090
  . "$FIREWALL_HELPER_FILE"
  read -r -p "请输入要放行的端口（空格或逗号分隔）: " raw
  raw="${raw//,/ }"
  for token in $raw; do
    is_valid_port "$token" || continue
    ports+=("$token")
  done
  [ ${#ports[@]} -gt 0 ] || die "没有可用端口"
  open_all_firewall_ports "${ports[@]}"
}

show_menu() {
  echo "=========================================="
  echo "      Xboard Only 管理菜单"
  echo "=========================================="
  echo "1.  安装 / 重新配置 Xboard（交互式）"
  echo "2.  更新 Xboard"
  echo "3.  查看 Xboard 状态"
  echo "4.  查看访问信息"
  echo "5.  放行额外端口"
  echo "6.  重启 Xboard"
  echo "7.  启动 Xboard"
  echo "8.  查看 Xboard 日志"
  echo "0.  退出"
  echo "=========================================="
}

main() {
  local choice
  require_root
  while true; do
    load_deploy_env
    show_menu
    read -r -p "请输入选项: " choice
    echo
    case "$choice" in
      1) bash "${SCRIPT_DIR}/install-xboard.sh" --interactive; pause ;;
      2) bash "${SCRIPT_DIR}/update-xboard.sh"; pause ;;
      3) show_service_status; pause ;;
      4) show_access_info; pause ;;
      5) open_custom_ports; pause ;;
      6) service_action restart; pause ;;
      7) service_action up; pause ;;
      8) service_action logs; pause ;;
      0) success "已退出"; exit 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
