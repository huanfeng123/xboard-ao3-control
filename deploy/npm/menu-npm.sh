#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/npm-common.sh"

info() { printf '[INFO] %s\n' "$*"; }
success() { printf '[OK] %s\n' "$*"; }
pause() { read -r -p "按回车继续..." _; }

require_root() {
  [ "${TEST_MODE:-0}" = "1" ] && return 0
  [ "${EUID}" -eq 0 ] || die "请使用 root 用户运行菜单脚本"
}

show_extra_https_mappings() {
  local port
  extra_https_ports_to_array
  if [ ${#EXTRA_HTTPS_PORTS_ARRAY[@]} -eq 0 ]; then
    echo "- NPM 额外 HTTPS 端口: 无"
    return 0
  fi
  echo "- NPM 额外 HTTPS 端口:"
  for port in "${EXTRA_HTTPS_PORTS_ARRAY[@]}"; do
    echo "  - ${port} -> 443"
  done
}

show_access_info() {
  load_deploy_env
  resolve_server_ip
  echo "- NPM HTTP 端口: ${NPM_HTTP_PORT}"
  echo "- NPM HTTPS 端口: ${NPM_HTTPS_PORT}"
  echo "- NPM 管理后台端口: ${NPM_ADMIN_PORT}"
  show_extra_https_mappings
  echo "- NPM 目录: ${NPM_DIR}"
  echo "- 配置文件: ${DEPLOY_ENV_FILE}"
  echo "- 管理后台: http://${DETECTED_SERVER_IP}:${NPM_ADMIN_PORT}"
}

show_service_status() {
  ensure_compose_ready
  run_compose "$NPM_DIR" ps
}

service_action() {
  local action="$1"
  ensure_compose_ready
  case "$action" in
    up) run_compose "$NPM_DIR" up -d; success "NPM 已启动" ;;
    restart) run_compose "$NPM_DIR" restart; success "NPM 已重启" ;;
    logs) run_compose "$NPM_DIR" logs -f --tail=100 ;;
    *) die "不支持的操作: $action" ;;
  esac
}

open_custom_ports() {
  local raw token
  local ports=()
  read -r -p "请输入要放行的端口（空格或逗号分隔）: " raw
  raw="${raw//,/ }"
  for token in $raw; do
    is_valid_port "$token" || continue
    ports+=("$token")
  done
  [ ${#ports[@]} -gt 0 ] || die "没有可用端口"
  open_ports "${ports[@]}" || warn "防火墙未自动放行，请手动检查"
}

add_npm_https_mapping() {
  local port
  load_deploy_env
  extra_https_ports_to_array
  read -r -p "请输入要额外映射到 443 的主机端口: " port
  is_valid_port "$port" || die "端口无效: $port"
  port_conflicts_with_main_services "$port" && die "端口 ${port} 与主配置冲突"
  [[ ",${EXTRA_NPM_HTTPS_PORTS}," == *",${port},"* ]] && die "端口 ${port} 已存在"
  EXTRA_NPM_HTTPS_PORTS="$(normalize_port_csv "${EXTRA_NPM_HTTPS_PORTS:+${EXTRA_NPM_HTTPS_PORTS},}${port}")"
  save_extra_https_ports
  apply_npm_https_mapping_changes
  open_ports "$port" || true
  success "已添加额外 HTTPS 端口映射：${port} -> 443"
}

remove_npm_https_mapping() {
  local port existing
  local remaining=()
  load_deploy_env
  extra_https_ports_to_array
  [ ${#EXTRA_HTTPS_PORTS_ARRAY[@]} -gt 0 ] || die "当前没有额外 HTTPS 端口映射"
  read -r -p "请输入要删除的额外 HTTPS 主机端口: " port
  is_valid_port "$port" || die "端口无效: $port"
  [[ ",${EXTRA_NPM_HTTPS_PORTS}," == *",${port},"* ]] || die "端口 ${port} 不在映射列表中"
  for existing in "${EXTRA_HTTPS_PORTS_ARRAY[@]}"; do
    [ "$existing" = "$port" ] || remaining+=("$existing")
  done
  EXTRA_NPM_HTTPS_PORTS="$(printf '%s\n' "${remaining[@]}" | awk 'NF && !seen[$0]++ {printf("%s%s", sep, $0); sep=","}')"
  save_extra_https_ports
  apply_npm_https_mapping_changes
  success "已删除额外 HTTPS 端口映射：${port} -> 443"
}

manage_npm_https_mappings() {
  while true; do
    load_deploy_env
    echo
    info "当前 NPM HTTPS 端口映射"
    echo "- 主 HTTPS 端口: ${NPM_HTTPS_PORT} -> 443"
    show_extra_https_mappings
    echo "1. 添加额外 HTTPS 端口映射到 443"
    echo "2. 删除额外 HTTPS 端口映射"
    echo "0. 返回上一级"
    read -r -p "请输入选项: " subchoice
    case "$subchoice" in
      1) add_npm_https_mapping; pause ;;
      2) remove_npm_https_mapping; pause ;;
      0) return 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}

show_menu() {
  echo "=========================================="
  echo "      NPM One Click 管理菜单"
  echo "=========================================="
  echo "1.  安装 / 重新配置 NPM（交互式）"
  echo "2.  更新 NPM"
  echo "3.  查看 NPM 状态"
  echo "4.  查看访问信息"
  echo "5.  放行额外端口"
  echo "6.  添加 NPM 额外 HTTPS 端口映射"
  echo "7.  重启 NPM"
  echo "8.  启动 NPM"
  echo "9.  查看 NPM 日志"
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
      1) bash "${SCRIPT_DIR}/install-npm.sh" --interactive; pause ;;
      2) bash "${SCRIPT_DIR}/update-npm.sh"; pause ;;
      3) show_service_status; pause ;;
      4) show_access_info; pause ;;
      5) open_custom_ports; pause ;;
      6) manage_npm_https_mappings ;;
      7) service_action restart; pause ;;
      8) service_action up; pause ;;
      9) service_action logs; pause ;;
      0) success "已退出"; exit 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
