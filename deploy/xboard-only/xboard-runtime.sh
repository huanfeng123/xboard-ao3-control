#!/usr/bin/env bash
set -euo pipefail

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
updates = {'APP_URL': f'http://localhost:{port}', 'DB_CONNECTION': 'sqlite',
           'DB_DATABASE': '/www/.docker/.data/database.sqlite', 'REDIS_HOST': '127.0.0.1',
           'REDIS_PASSWORD': 'null', 'REDIS_PORT': '6379', 'BROADCAST_DRIVER': 'log',
           'CACHE_DRIVER': 'redis', 'QUEUE_CONNECTION': 'redis'}
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
  [ -f "$XBOARD_DIR/.docker/.data/database.sqlite" ] || : >"$XBOARD_DIR/.docker/.data/database.sqlite"
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
  grep -Fq "\"${XBOARD_PORT}:7001\"" "$XBOARD_DIR/compose.yaml" || die "compose.yaml 端口映射校验失败"
}

should_install_xboard() {
  [ "$FORCE_XBOARD_INSTALL" = "1" ] && return 0
  [ ! -s "$XBOARD_DIR/.docker/.data/database.sqlite" ] && return 0
  return 1
}

wait_for_xboard_redis() {
  local attempt=1
  while [ "$attempt" -le 30 ]; do
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
    run_compose "$XBOARD_DIR" exec -T -e ENABLE_SQLITE=true -e ENABLE_REDIS=true \
      -e ADMIN_ACCOUNT="$XBOARD_ADMIN_EMAIL" xboard php artisan xboard:install
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
