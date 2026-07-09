#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERACTIVE_CONFIG=0

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/npm-common.sh"

print_usage() {
  cat <<EOF
用法：
  ./install-npm.sh [--interactive|-i] [--non-interactive]

说明：
  仅安装 Nginx Proxy Manager，不安装 Xboard。
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

open_firewall_ports_if_enabled() {
  [ "$ENABLE_FIREWALL_OPEN" = "1" ] || return 0
  local ports=("$NPM_HTTP_PORT" "$NPM_HTTPS_PORT" "$NPM_ADMIN_PORT")
  extra_https_ports_to_array
  ports+=("${EXTRA_HTTPS_PORTS_ARRAY[@]}")
  open_ports "${ports[@]}" || warn "防火墙未自动放行，请手动检查"
}

detect_docker_host_ip() {
  ip -4 addr show docker0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1
}

show_access_info() {
  resolve_server_ip
  printf '\n'
  printf 'NPM 管理后台: http://%s:%s\n' "$DETECTED_SERVER_IP" "$NPM_ADMIN_PORT"
  printf 'HTTP 入口: http://%s:%s\n' "$DETECTED_SERVER_IP" "$NPM_HTTP_PORT"
  printf 'HTTPS 入口: https://%s:%s\n' "$DETECTED_SERVER_IP" "$NPM_HTTPS_PORT"
  printf '快捷命令: %s\n' "$MENU_COMMAND"
}

show_reverse_proxy_tips() {
  local docker_host_ip
  docker_host_ip="$(detect_docker_host_ip || true)"

  printf '\n'
  printf 'NPM 反代提示:\n'
  if [ -n "$docker_host_ip" ]; then
    printf -- '- Docker 宿主机地址: %s\n' "$docker_host_ip"
    printf -- '- 在 NPM 的 Forward Hostname/IP 中优先填写这个地址，不要直接填 127.0.0.1\n'
  else
    printf -- '- 未检测到 docker0 地址，请手动执行: ip -4 addr show docker0 | awk '\''/inet /{print $2}'\'' | cut -d/ -f1\n'
  fi
  printf -- '- 如果节点客户端连接端口不是 443，请在菜单里添加 NPM HTTPS 映射端口，例如: 7892 -> 443\n'
  printf -- '- Xboard 常见填写: 连接端口 = 客户端访问端口，服务端口 = 节点实际监听端口\n'
}

main() {
  parse_args "$@"
  load_deploy_env
  validate_config
  configure_interactively
  validate_config
  init_privilege_helper
  install_missing_dependencies
  ensure_compose_ready
  prepare_dirs
  write_npm_compose
  write_deploy_env
  run_compose "$NPM_DIR" up -d
  install_menu_shortcut
  open_firewall_ports_if_enabled
  show_access_info
  show_reverse_proxy_tips
}

main "$@"
