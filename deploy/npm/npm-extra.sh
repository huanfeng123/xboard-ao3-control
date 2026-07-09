#!/usr/bin/env bash
set -euo pipefail

is_ipv4() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

first_nonempty_line() {
  awk 'NF {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print; exit}'
}

fetch_public_ip() {
  local value
  for url in https://api.ipify.org https://ipv4.icanhazip.com https://ifconfig.me/ip; do
    value="$(curl -4fsSL --max-time 5 "$url" 2>/dev/null | first_nonempty_line || true)"
    if is_ipv4 "$value"; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 1
}

fetch_local_ip() {
  local value
  if command -v ip >/dev/null 2>&1; then
    value="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' || true)"
    is_ipv4 "$value" && printf '%s' "$value" && return 0
  fi
  value="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  is_ipv4 "$value" && printf '%s' "$value" && return 0
  return 1
}

resolve_server_ip() {
  if is_ipv4 "$SERVER_IP"; then
    DETECTED_SERVER_IP="$SERVER_IP"
  elif DETECTED_SERVER_IP="$(fetch_public_ip || true)"; is_ipv4 "$DETECTED_SERVER_IP"; then
    :
  elif DETECTED_SERVER_IP="$(fetch_local_ip || true)"; is_ipv4 "$DETECTED_SERVER_IP"; then
    :
  else
    DETECTED_SERVER_IP="服务器IP"
  fi
}

set_deploy_env_value() {
  local key="$1"
  local value="$2"
  python3 - "$DEPLOY_ENV_FILE" "$key" "$value" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
prefix = f"{key}="
if path.exists():
    lines = path.read_text().splitlines()
else:
    lines = ["# xboard-one-click local config", "# 由 npm 脚本自动补充/更新"]
updated = []
found = False
for line in lines:
    if line.startswith(prefix):
        updated.append(f"{key}={value}")
        found = True
    else:
        updated.append(line)
if not found:
    updated.append(f"{key}={value}")
path.write_text("\n".join(updated).rstrip("\n") + "\n")
PY
}

save_extra_https_ports() {
  set_deploy_env_value "EXTRA_NPM_HTTPS_PORTS" "$EXTRA_NPM_HTTPS_PORTS"
}

port_conflicts_with_main_services() {
  local port="$1"
  [ "$port" = "$NPM_HTTP_PORT" ] && return 0
  [ "$port" = "$NPM_HTTPS_PORT" ] && return 0
  [ "$port" = "$NPM_ADMIN_PORT" ] && return 0
  return 1
}

apply_npm_https_mapping_changes() {
  ensure_compose_ready
  prepare_dirs
  write_npm_compose
  run_compose "$NPM_DIR" up -d
}

open_ports() {
  local ports=("$@")
  [ -f "$FIREWALL_HELPER_FILE" ] || return 1
  # shellcheck disable=SC1090
  . "$FIREWALL_HELPER_FILE"
  open_all_firewall_ports "${ports[@]}"
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
  [ "${INTERACTIVE_CONFIG:-0}" = "1" ] || return 0
  [ -t 0 ] || die "交互模式需要 TTY"
  log "进入 NPM 交互式配置"
  NPM_HTTP_PORT="$(prompt_port 'NPM HTTP 端口' "$NPM_HTTP_PORT")"
  NPM_HTTPS_PORT="$(prompt_port 'NPM HTTPS 端口' "$NPM_HTTPS_PORT")"
  NPM_ADMIN_PORT="$(prompt_port 'NPM 管理后台端口' "$NPM_ADMIN_PORT")"
  EXTRA_NPM_HTTPS_PORTS="$(prompt_value '额外 HTTPS 端口(逗号分隔，可空)' "$EXTRA_NPM_HTTPS_PORTS")"
  validate_config
}

write_deploy_env() {
  [ "$AUTO_WRITE_DEPLOY_ENV" = "1" ] || return 0
  cat >"$DEPLOY_ENV_FILE" <<EOF
# xboard-one-click local config
# 由 install-npm.sh 自动生成/更新
SERVER_IP=${SERVER_IP}
NPM_HTTP_PORT=${NPM_HTTP_PORT}
NPM_HTTPS_PORT=${NPM_HTTPS_PORT}
NPM_ADMIN_PORT=${NPM_ADMIN_PORT}
EXTRA_NPM_HTTPS_PORTS=${EXTRA_NPM_HTTPS_PORTS}
ENABLE_FIREWALL_OPEN=${ENABLE_FIREWALL_OPEN}
AUTO_INSTALL_DEPS=${AUTO_INSTALL_DEPS}
CLOUD_FIREWALL_PROVIDER=${CLOUD_FIREWALL_PROVIDER}
CLOUD_FIREWALL_REGION=${CLOUD_FIREWALL_REGION}
CLOUD_FIREWALL_GROUP_ID=${CLOUD_FIREWALL_GROUP_ID}
CLOUD_FIREWALL_PROJECT_ID=${CLOUD_FIREWALL_PROJECT_ID}
CLOUD_FIREWALL_NETWORK=${CLOUD_FIREWALL_NETWORK}
CLOUD_FIREWALL_TARGET_TAGS=${CLOUD_FIREWALL_TARGET_TAGS}
CLOUD_FIREWALL_NSG_ID=${CLOUD_FIREWALL_NSG_ID}
CLOUD_FIREWALL_SOURCE_CIDR=${CLOUD_FIREWALL_SOURCE_CIDR}
CLOUD_FIREWALL_RULE_PREFIX=${CLOUD_FIREWALL_RULE_PREFIX}
EOF
  log "已写入配置文件: $DEPLOY_ENV_FILE"
}
