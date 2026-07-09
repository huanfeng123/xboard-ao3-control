#!/usr/bin/env bash
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-${COMMON_DIR}/runtime}"
XBOARD_DIR="${XBOARD_DIR:-${WORK_DIR}/Xboard}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-${COMMON_DIR}/deploy.env}"
FIREWALL_HELPER_FILE="${FIREWALL_HELPER_FILE:-${COMMON_DIR}/firewall.sh}"

DEFAULT_XBOARD_PORT=7001
DEFAULT_XBOARD_ADMIN_EMAIL="admin@demo.com"
DEFAULT_XBOARD_REPO="https://github.com/huanfeng123/xboard-ao3-control"
DEFAULT_XBOARD_BRANCH="main"
DEFAULT_ENABLE_FIREWALL_OPEN=1
DEFAULT_FORCE_XBOARD_INSTALL=0
DEFAULT_AUTO_WRITE_DEPLOY_ENV=1
DEFAULT_AUTO_INSTALL_DEPS=1
DEFAULT_MENU_COMMAND="xbo"

INPUT_SERVER_IP="${SERVER_IP:-}"
INPUT_XBOARD_PORT="${XBOARD_PORT:-}"
INPUT_XBOARD_ADMIN_EMAIL="${XBOARD_ADMIN_EMAIL:-}"
INPUT_XBOARD_REPO="${XBOARD_REPO:-}"
INPUT_XBOARD_BRANCH="${XBOARD_BRANCH:-}"
INPUT_ENABLE_FIREWALL_OPEN="${ENABLE_FIREWALL_OPEN:-}"
INPUT_FORCE_XBOARD_INSTALL="${FORCE_XBOARD_INSTALL:-}"
INPUT_AUTO_WRITE_DEPLOY_ENV="${AUTO_WRITE_DEPLOY_ENV:-}"
INPUT_AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-}"
INPUT_MENU_COMMAND="${MENU_COMMAND:-}"

SERVER_IP="${SERVER_IP:-}"
XBOARD_PORT="${XBOARD_PORT:-}"
XBOARD_ADMIN_EMAIL="${XBOARD_ADMIN_EMAIL:-}"
XBOARD_REPO="${XBOARD_REPO:-}"
XBOARD_BRANCH="${XBOARD_BRANCH:-}"
ENABLE_FIREWALL_OPEN="${ENABLE_FIREWALL_OPEN:-}"
FORCE_XBOARD_INSTALL="${FORCE_XBOARD_INSTALL:-}"
AUTO_WRITE_DEPLOY_ENV="${AUTO_WRITE_DEPLOY_ENV:-}"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-}"
MENU_COMMAND="${MENU_COMMAND:-}"

COMPOSE_CMD=()
SUDO_CMD=()
DETECTED_SERVER_IP=""
XBOARD_ADMIN_PATH=""

log() { printf '[xboard-only] %s\n' "$*"; }
warn() { printf '[xboard-only][WARN] %s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }

restore_input_overrides() {
  [ -z "$INPUT_SERVER_IP" ] || SERVER_IP="$INPUT_SERVER_IP"
  [ -z "$INPUT_XBOARD_PORT" ] || XBOARD_PORT="$INPUT_XBOARD_PORT"
  [ -z "$INPUT_XBOARD_ADMIN_EMAIL" ] || XBOARD_ADMIN_EMAIL="$INPUT_XBOARD_ADMIN_EMAIL"
  [ -z "$INPUT_XBOARD_REPO" ] || XBOARD_REPO="$INPUT_XBOARD_REPO"
  [ -z "$INPUT_XBOARD_BRANCH" ] || XBOARD_BRANCH="$INPUT_XBOARD_BRANCH"
  [ -z "$INPUT_ENABLE_FIREWALL_OPEN" ] || ENABLE_FIREWALL_OPEN="$INPUT_ENABLE_FIREWALL_OPEN"
  [ -z "$INPUT_FORCE_XBOARD_INSTALL" ] || FORCE_XBOARD_INSTALL="$INPUT_FORCE_XBOARD_INSTALL"
  [ -z "$INPUT_AUTO_WRITE_DEPLOY_ENV" ] || AUTO_WRITE_DEPLOY_ENV="$INPUT_AUTO_WRITE_DEPLOY_ENV"
  [ -z "$INPUT_AUTO_INSTALL_DEPS" ] || AUTO_INSTALL_DEPS="$INPUT_AUTO_INSTALL_DEPS"
  [ -z "$INPUT_MENU_COMMAND" ] || MENU_COMMAND="$INPUT_MENU_COMMAND"
}

apply_defaults() {
  XBOARD_PORT="${XBOARD_PORT:-${DEFAULT_XBOARD_PORT}}"
  XBOARD_ADMIN_EMAIL="${XBOARD_ADMIN_EMAIL:-${DEFAULT_XBOARD_ADMIN_EMAIL}}"
  XBOARD_REPO="${XBOARD_REPO:-${DEFAULT_XBOARD_REPO}}"
  XBOARD_BRANCH="${XBOARD_BRANCH:-${DEFAULT_XBOARD_BRANCH}}"
  ENABLE_FIREWALL_OPEN="${ENABLE_FIREWALL_OPEN:-${DEFAULT_ENABLE_FIREWALL_OPEN}}"
  FORCE_XBOARD_INSTALL="${FORCE_XBOARD_INSTALL:-${DEFAULT_FORCE_XBOARD_INSTALL}}"
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

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

is_valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

validate_email() {
  [[ "$1" == *"@"* ]]
}

validate_config() {
  is_valid_port "$XBOARD_PORT" || die "端口无效: $XBOARD_PORT"
  validate_email "$XBOARD_ADMIN_EMAIL" || die "XBOARD_ADMIN_EMAIL 格式看起来不对: $XBOARD_ADMIN_EMAIL"
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
  [ "$AUTO_INSTALL_DEPS" = "1" ] || return 0
  can_use_apt || return 0

  local packages=(ca-certificates curl git python3)
  command -v docker >/dev/null 2>&1 || packages+=(docker.io)

  if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
    if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
      packages+=(docker-compose-plugin)
    elif apt-cache show docker-compose-v2 >/dev/null 2>&1; then
      packages+=(docker-compose-v2)
    else
      packages+=(docker-compose)
    fi
  fi

  log "尝试自动安装 Xboard 所需依赖"
  run_privileged apt-get update
  run_privileged apt-get install -y "${packages[@]}"
  if command -v systemctl >/dev/null 2>&1; then
    run_privileged systemctl enable --now docker || true
  fi
}

ensure_compose_ready() {
  need_cmd git
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
  mkdir -p "$WORK_DIR"
}

clone_or_update_xboard() {
  if [ ! -d "$XBOARD_DIR/.git" ]; then
    log "拉取 Xboard (${XBOARD_BRANCH} 分支)"
    git clone -b "$XBOARD_BRANCH" --depth 1 "$XBOARD_REPO" "$XBOARD_DIR"
  else
    log "检测到已存在 Xboard 仓库，执行更新"
    git -C "$XBOARD_DIR" fetch origin "$XBOARD_BRANCH" --depth 1
    git -C "$XBOARD_DIR" checkout "$XBOARD_BRANCH"
    git -C "$XBOARD_DIR" reset --hard "origin/$XBOARD_BRANCH"
  fi
}

prepare_xboard_env() {
  mkdir -p "$XBOARD_DIR/.docker/.data" "$XBOARD_DIR/storage/logs" \
    "$XBOARD_DIR/storage/theme" "$XBOARD_DIR/plugins"

  if [ -f "$XBOARD_DIR/.env.example" ] && [ ! -f "$XBOARD_DIR/.env" ]; then
    cp "$XBOARD_DIR/.env.example" "$XBOARD_DIR/.env"
  fi

  if [ ! -f "$XBOARD_DIR/.env" ]; then
    cat >"$XBOARD_DIR/.env" <<EOF
APP_NAME=XBoard
APP_ENV=local
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost
APP_RUNNING_IN_CONSOLE=true
LOG_CHANNEL=stack
DB_CONNECTION=sqlite
DB_DATABASE=/www/.docker/.data/database.sqlite
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
BROADCAST_DRIVER=log
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
MAIL_DRIVER=smtp
MAIL_HOST=
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=
MAIL_FROM_NAME=
ENABLE_AUTO_BACKUP_AND_UPDATE=false
INSTALLED=false
EOF
  fi

  python3 - "$XBOARD_DIR/.env" "$XBOARD_PORT" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
port = sys.argv[2]
text = path.read_text()
lines = text.splitlines()
updates = {
    'APP_URL': f'http://localhost:{port}',
    'DB_CONNECTION': 'sqlite',
    'DB_DATABASE': '/www/.docker/.data/database.sqlite',
    'REDIS_HOST': '127.0.0.1',
    'REDIS_PASSWORD': 'null',
    'REDIS_PORT': '6379',
    'BROADCAST_DRIVER': 'log',
    'CACHE_DRIVER': 'redis',
    'QUEUE_CONNECTION': 'redis',
}
seen = set()
out = []
for line in lines:
    if '=' in line and not line.lstrip().startswith('#'):
        key = line.split('=', 1)[0]
        if key in updates:
            out.append(f'{key}={updates[key]}')
            seen.add(key)
            continue
    out.append(line)
for key, value in updates.items():
    if key not in seen:
        out.append(f'{key}={value}')
path.write_text('\n'.join(out) + '\n')
PY

  if [ ! -f "$XBOARD_DIR/.docker/.data/database.sqlite" ]; then
    : >"$XBOARD_DIR/.docker/.data/database.sqlite"
  fi
}

ensure_xboard_port_mapping() {
  python3 - "$XBOARD_DIR/compose.yaml" "$XBOARD_PORT" <<'PY'
from pathlib import Path
import re
import sys
path = Path(sys.argv[1])
port = sys.argv[2]
text = path.read_text()
text_new = text.replace('"7001:7001"', f'"{port}:7001"', 1)
if text_new == text:
    text_new = re.sub(r'-\s*"\d+:7001"', f'- "{port}:7001"', text, count=1)
if text_new == text:
    raise SystemExit('未在 compose.yaml 中找到可替换的 Xboard 端口映射，已停止以避免误改。')
path.write_text(text_new)
PY

  grep -Fq "\"${XBOARD_PORT}:7001\"" "$XBOARD_DIR/compose.yaml" || \
    die "compose.yaml 端口映射校验失败，未发现 ${XBOARD_PORT}:7001"
}

should_install_xboard() {
  [ "$FORCE_XBOARD_INSTALL" = "1" ] && return 0
  [ ! -s "$XBOARD_DIR/.docker/.data/database.sqlite" ] && return 0
  return 1
}

wait_for_xboard_redis() {
  local attempt=1
  local max_attempts=30
  while [ "$attempt" -le "$max_attempts" ]; do
    if run_compose "$XBOARD_DIR" exec -T xboard sh -lc 'test -S /data/redis.sock'; then
      log "检测到 Xboard 内置 Redis 已就绪"
      return 0
    fi
    sleep 2
    attempt=$((attempt + 1))
  done
  run_compose "$XBOARD_DIR" logs --tail=80 xboard || true
  die "Xboard 内置 Redis 未能及时启动，已停止安装"
}

install_xboard() {
  clone_or_update_xboard
  ensure_xboard_port_mapping
  prepare_xboard_env
  log "先启动 Xboard 容器，确保内置 Redis 正常就绪"
  run_compose "$XBOARD_DIR" up -d
  wait_for_xboard_redis

  if should_install_xboard; then
    log "在已启动的 Xboard 容器内执行初始化"
    run_compose "$XBOARD_DIR" exec -T \
      -e ENABLE_SQLITE=true \
      -e ENABLE_REDIS=true \
      -e ADMIN_ACCOUNT="$XBOARD_ADMIN_EMAIL" \
      xboard php artisan xboard:install
  else
    log "检测到现有 SQLite 数据，跳过 Xboard 初始化"
  fi

  run_compose "$XBOARD_DIR" up -d
  run_compose "$XBOARD_DIR" port xboard 7001
}

install_menu_shortcut() {
  local target="/usr/local/bin/${MENU_COMMAND}"
  local menu_file="${COMMON_DIR}/menu-xboard.sh"
  [ -f "$menu_file" ] || return 0
  run_privileged tee "$target" >/dev/null <<EOF
#!/usr/bin/env bash
exec bash "${menu_file}" "\$@"
EOF
  run_privileged chmod +x "$target"
  log "已安装快捷命令: ${MENU_COMMAND} -> ${menu_file}"
}

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

resolve_xboard_admin_path() {
  if [ ! -f "$XBOARD_DIR/.env" ]; then
    XBOARD_ADMIN_PATH=""
    return 0
  fi

  XBOARD_ADMIN_PATH="$(python3 - "$XBOARD_DIR/.env" <<'PY'
from pathlib import Path
import binascii
import sys
path = Path(sys.argv[1])
app_key = ""
for line in path.read_text().splitlines():
    if line.startswith("APP_KEY="):
        app_key = line.split("=", 1)[1].strip()
        break
if app_key:
    print(f"{binascii.crc32(app_key.encode()) & 0xffffffff:08x}")
PY
)"
}

open_firewall_ports() {
  [ "$ENABLE_FIREWALL_OPEN" = "1" ] || return 0
  [ -f "$FIREWALL_HELPER_FILE" ] || return 1
  # shellcheck disable=SC1090
  . "$FIREWALL_HELPER_FILE"
  open_all_firewall_ports "$XBOARD_PORT"
}
