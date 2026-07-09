#!/usr/bin/env bash
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-${COMMON_DIR}/runtime}"
NPM_DIR="${NPM_DIR:-${WORK_DIR}/nginx-proxy-manager}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-${COMMON_DIR}/deploy.env}"
FIREWALL_HELPER_FILE="${FIREWALL_HELPER_FILE:-${COMMON_DIR}/firewall.sh}"

DEFAULT_NPM_HTTP_PORT=80
DEFAULT_NPM_HTTPS_PORT=443
DEFAULT_NPM_ADMIN_PORT=81
DEFAULT_EXTRA_NPM_HTTPS_PORTS=""
DEFAULT_ENABLE_FIREWALL_OPEN=1
DEFAULT_AUTO_WRITE_DEPLOY_ENV=1
DEFAULT_AUTO_INSTALL_DEPS=1
DEFAULT_MENU_COMMAND="xbn"

INPUT_SERVER_IP="${SERVER_IP:-}"
INPUT_NPM_HTTP_PORT="${NPM_HTTP_PORT:-}"
INPUT_NPM_HTTPS_PORT="${NPM_HTTPS_PORT:-}"
INPUT_NPM_ADMIN_PORT="${NPM_ADMIN_PORT:-}"
INPUT_EXTRA_NPM_HTTPS_PORTS="${EXTRA_NPM_HTTPS_PORTS:-}"
INPUT_ENABLE_FIREWALL_OPEN="${ENABLE_FIREWALL_OPEN:-}"
INPUT_AUTO_WRITE_DEPLOY_ENV="${AUTO_WRITE_DEPLOY_ENV:-}"
INPUT_AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-}"
INPUT_MENU_COMMAND="${MENU_COMMAND:-}"
INPUT_CLOUD_FIREWALL_PROVIDER="${CLOUD_FIREWALL_PROVIDER:-}"
INPUT_CLOUD_FIREWALL_REGION="${CLOUD_FIREWALL_REGION:-}"
INPUT_CLOUD_FIREWALL_GROUP_ID="${CLOUD_FIREWALL_GROUP_ID:-}"
INPUT_CLOUD_FIREWALL_PROJECT_ID="${CLOUD_FIREWALL_PROJECT_ID:-}"
INPUT_CLOUD_FIREWALL_NETWORK="${CLOUD_FIREWALL_NETWORK:-}"
INPUT_CLOUD_FIREWALL_TARGET_TAGS="${CLOUD_FIREWALL_TARGET_TAGS:-}"
INPUT_CLOUD_FIREWALL_NSG_ID="${CLOUD_FIREWALL_NSG_ID:-}"
INPUT_CLOUD_FIREWALL_SOURCE_CIDR="${CLOUD_FIREWALL_SOURCE_CIDR:-}"
INPUT_CLOUD_FIREWALL_RULE_PREFIX="${CLOUD_FIREWALL_RULE_PREFIX:-}"

SERVER_IP="${SERVER_IP:-}"
NPM_HTTP_PORT="${NPM_HTTP_PORT:-}"
NPM_HTTPS_PORT="${NPM_HTTPS_PORT:-}"
NPM_ADMIN_PORT="${NPM_ADMIN_PORT:-}"
EXTRA_NPM_HTTPS_PORTS="${EXTRA_NPM_HTTPS_PORTS:-}"
ENABLE_FIREWALL_OPEN="${ENABLE_FIREWALL_OPEN:-}"
AUTO_WRITE_DEPLOY_ENV="${AUTO_WRITE_DEPLOY_ENV:-}"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-}"
MENU_COMMAND="${MENU_COMMAND:-}"
CLOUD_FIREWALL_PROVIDER="${CLOUD_FIREWALL_PROVIDER:-}"
CLOUD_FIREWALL_REGION="${CLOUD_FIREWALL_REGION:-}"
CLOUD_FIREWALL_GROUP_ID="${CLOUD_FIREWALL_GROUP_ID:-}"
CLOUD_FIREWALL_PROJECT_ID="${CLOUD_FIREWALL_PROJECT_ID:-}"
CLOUD_FIREWALL_NETWORK="${CLOUD_FIREWALL_NETWORK:-}"
CLOUD_FIREWALL_TARGET_TAGS="${CLOUD_FIREWALL_TARGET_TAGS:-}"
CLOUD_FIREWALL_NSG_ID="${CLOUD_FIREWALL_NSG_ID:-}"
CLOUD_FIREWALL_SOURCE_CIDR="${CLOUD_FIREWALL_SOURCE_CIDR:-}"
CLOUD_FIREWALL_RULE_PREFIX="${CLOUD_FIREWALL_RULE_PREFIX:-}"

COMPOSE_CMD=()
SUDO_CMD=()
DETECTED_SERVER_IP=""

log() { printf '[npm-only] %s\n' "$*"; }
warn() { printf '[npm-only][WARN] %s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }

restore_input_overrides() {
  [ -z "$INPUT_SERVER_IP" ] || SERVER_IP="$INPUT_SERVER_IP"
  [ -z "$INPUT_NPM_HTTP_PORT" ] || NPM_HTTP_PORT="$INPUT_NPM_HTTP_PORT"
  [ -z "$INPUT_NPM_HTTPS_PORT" ] || NPM_HTTPS_PORT="$INPUT_NPM_HTTPS_PORT"
  [ -z "$INPUT_NPM_ADMIN_PORT" ] || NPM_ADMIN_PORT="$INPUT_NPM_ADMIN_PORT"
  [ -z "$INPUT_EXTRA_NPM_HTTPS_PORTS" ] || EXTRA_NPM_HTTPS_PORTS="$INPUT_EXTRA_NPM_HTTPS_PORTS"
  [ -z "$INPUT_ENABLE_FIREWALL_OPEN" ] || ENABLE_FIREWALL_OPEN="$INPUT_ENABLE_FIREWALL_OPEN"
  [ -z "$INPUT_AUTO_WRITE_DEPLOY_ENV" ] || AUTO_WRITE_DEPLOY_ENV="$INPUT_AUTO_WRITE_DEPLOY_ENV"
  [ -z "$INPUT_AUTO_INSTALL_DEPS" ] || AUTO_INSTALL_DEPS="$INPUT_AUTO_INSTALL_DEPS"
  [ -z "$INPUT_MENU_COMMAND" ] || MENU_COMMAND="$INPUT_MENU_COMMAND"
  [ -z "$INPUT_CLOUD_FIREWALL_PROVIDER" ] || CLOUD_FIREWALL_PROVIDER="$INPUT_CLOUD_FIREWALL_PROVIDER"
  [ -z "$INPUT_CLOUD_FIREWALL_REGION" ] || CLOUD_FIREWALL_REGION="$INPUT_CLOUD_FIREWALL_REGION"
  [ -z "$INPUT_CLOUD_FIREWALL_GROUP_ID" ] || CLOUD_FIREWALL_GROUP_ID="$INPUT_CLOUD_FIREWALL_GROUP_ID"
  [ -z "$INPUT_CLOUD_FIREWALL_PROJECT_ID" ] || CLOUD_FIREWALL_PROJECT_ID="$INPUT_CLOUD_FIREWALL_PROJECT_ID"
  [ -z "$INPUT_CLOUD_FIREWALL_NETWORK" ] || CLOUD_FIREWALL_NETWORK="$INPUT_CLOUD_FIREWALL_NETWORK"
  [ -z "$INPUT_CLOUD_FIREWALL_TARGET_TAGS" ] || CLOUD_FIREWALL_TARGET_TAGS="$INPUT_CLOUD_FIREWALL_TARGET_TAGS"
  [ -z "$INPUT_CLOUD_FIREWALL_NSG_ID" ] || CLOUD_FIREWALL_NSG_ID="$INPUT_CLOUD_FIREWALL_NSG_ID"
  [ -z "$INPUT_CLOUD_FIREWALL_SOURCE_CIDR" ] || CLOUD_FIREWALL_SOURCE_CIDR="$INPUT_CLOUD_FIREWALL_SOURCE_CIDR"
  [ -z "$INPUT_CLOUD_FIREWALL_RULE_PREFIX" ] || CLOUD_FIREWALL_RULE_PREFIX="$INPUT_CLOUD_FIREWALL_RULE_PREFIX"
}

apply_defaults() {
  NPM_HTTP_PORT="${NPM_HTTP_PORT:-${DEFAULT_NPM_HTTP_PORT}}"
  NPM_HTTPS_PORT="${NPM_HTTPS_PORT:-${DEFAULT_NPM_HTTPS_PORT}}"
  NPM_ADMIN_PORT="${NPM_ADMIN_PORT:-${DEFAULT_NPM_ADMIN_PORT}}"
  EXTRA_NPM_HTTPS_PORTS="${EXTRA_NPM_HTTPS_PORTS:-${DEFAULT_EXTRA_NPM_HTTPS_PORTS}}"
  ENABLE_FIREWALL_OPEN="${ENABLE_FIREWALL_OPEN:-${DEFAULT_ENABLE_FIREWALL_OPEN}}"
  AUTO_WRITE_DEPLOY_ENV="${AUTO_WRITE_DEPLOY_ENV:-${DEFAULT_AUTO_WRITE_DEPLOY_ENV}}"
  AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-${DEFAULT_AUTO_INSTALL_DEPS}}"
  MENU_COMMAND="${MENU_COMMAND:-${DEFAULT_MENU_COMMAND}}"
}

load_deploy_env() {
  if [ -f "$DEPLOY_ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$DEPLOY_ENV_FILE"
    set +a
  fi
  restore_input_overrides
  apply_defaults
}

is_valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

normalize_port_csv() {
  printf '%s' "$1" | tr ', ' '\n\n' | awk 'NF && !seen[$0]++ {printf("%s%s", sep, $0); sep=","}'
}

extra_https_ports_to_array() {
  local normalized
  normalized="$(normalize_port_csv "$EXTRA_NPM_HTTPS_PORTS")"
  EXTRA_NPM_HTTPS_PORTS="$normalized"
  if [ -n "$normalized" ]; then
    IFS=',' read -r -a EXTRA_HTTPS_PORTS_ARRAY <<< "$normalized"
  else
    EXTRA_HTTPS_PORTS_ARRAY=()
  fi
}

validate_extra_https_ports() {
  local port
  extra_https_ports_to_array
  for port in "${EXTRA_HTTPS_PORTS_ARRAY[@]}"; do
    is_valid_port "$port" || die "额外 HTTPS 端口无效: $port"
    [ "$port" != "$NPM_HTTP_PORT" ] || die "额外 HTTPS 端口不能与 HTTP 端口重复"
    [ "$port" != "$NPM_HTTPS_PORT" ] || die "额外 HTTPS 端口不能与 HTTPS 端口重复"
    [ "$port" != "$NPM_ADMIN_PORT" ] || die "额外 HTTPS 端口不能与管理端口重复"
  done
}

validate_config() {
  local port
  for port in "$NPM_HTTP_PORT" "$NPM_HTTPS_PORT" "$NPM_ADMIN_PORT"; do
    is_valid_port "$port" || die "端口无效: $port"
  done
  [ "$NPM_HTTP_PORT" != "$NPM_HTTPS_PORT" ] || die "HTTP 与 HTTPS 端口不能相同"
  [ "$NPM_HTTP_PORT" != "$NPM_ADMIN_PORT" ] || die "HTTP 与管理端口不能相同"
  [ "$NPM_HTTPS_PORT" != "$NPM_ADMIN_PORT" ] || die "HTTPS 与管理端口不能相同"
  validate_extra_https_ports
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

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

can_use_apt() {
  command -v apt-get >/dev/null 2>&1 && [ -f /etc/os-release ]
}

install_missing_dependencies() {
  local need_compose=0
  local packages=(ca-certificates curl python3)
  [ "$AUTO_INSTALL_DEPS" = "1" ] || return 0
  can_use_apt || return 0
  command -v docker >/dev/null 2>&1 || packages+=(docker.io)
  if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
    need_compose=1
  fi
  [ "$need_compose" = "0" ] && [ ${#packages[@]} -eq 3 ] && return 0
  log "尝试自动安装 NPM 所需依赖"
  run_privileged apt-get update
  if [ "$need_compose" = "1" ]; then
    if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
      packages+=(docker-compose-plugin)
    elif apt-cache show docker-compose-v2 >/dev/null 2>&1; then
      packages+=(docker-compose-v2)
    else
      packages+=(docker-compose)
    fi
  fi
  run_privileged apt-get install -y "${packages[@]}"
  if command -v systemctl >/dev/null 2>&1; then
    run_privileged systemctl enable --now docker || true
  fi
}

ensure_compose_ready() {
  need_cmd docker
  need_cmd python3
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
  else
    die "未找到 docker compose / docker-compose"
  fi
  docker info >/dev/null 2>&1 || die "当前用户无法访问 Docker daemon"
}

has_compose_file() {
  [ -f "$1/compose.yaml" ] || [ -f "$1/docker-compose.yml" ] || [ -f "$1/docker-compose.yaml" ]
}

run_compose() {
  local dir="$1"
  shift
  has_compose_file "$dir" || die "未找到 Compose 配置目录: $dir"
  (cd "$dir" && "${COMPOSE_CMD[@]}" "$@")
}

prepare_dirs() {
  mkdir -p "$WORK_DIR" "$NPM_DIR/data" "$NPM_DIR/letsencrypt"
}

write_npm_compose() {
  local port
  extra_https_ports_to_array
  {
    cat <<EOF
services:
  app:
    image: jc21/nginx-proxy-manager:latest
    restart: unless-stopped
    ports:
      - "${NPM_HTTP_PORT}:80"
      - "${NPM_HTTPS_PORT}:443"
      - "${NPM_ADMIN_PORT}:81"
EOF
    for port in "${EXTRA_HTTPS_PORTS_ARRAY[@]}"; do
      printf '      - "%s:443"\n' "$port"
    done
    cat <<'EOF'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF
  } >"$NPM_DIR/compose.yaml"
}

install_menu_shortcut() {
  local target="/usr/local/bin/${MENU_COMMAND}"
  local menu_file="${COMMON_DIR}/menu-npm.sh"
  [ -f "$menu_file" ] || return 0
  run_privileged tee "$target" >/dev/null <<EOF
#!/usr/bin/env bash
exec bash "${menu_file}" "\$@"
EOF
  run_privileged chmod +x "$target"
  log "已安装快捷命令: ${MENU_COMMAND} -> ${menu_file}"
}

# shellcheck disable=SC1091
. "${COMMON_DIR}/npm-extra.sh"
