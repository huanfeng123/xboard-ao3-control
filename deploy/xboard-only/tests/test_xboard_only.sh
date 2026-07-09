#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export DEPLOY_ENV_FILE="$TMP_DIR/deploy.env"
export WORK_DIR="$TMP_DIR/runtime"
export XBOARD_DIR="$WORK_DIR/Xboard"

# shellcheck disable=SC1091
. "${ROOT_DIR}/xboard-common.sh"

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq "$expected" "$file" || {
    echo "断言失败: $file 缺少 $expected" >&2
    exit 1
  }
}

test_validate_config() {
  XBOARD_PORT=9664
  XBOARD_ADMIN_EMAIL="admin@example.com"
  validate_config
}

test_menu_render() {
  local output
  output="$(TEST_MODE=1 bash -lc ". '${ROOT_DIR}/menu-xboard.sh'; show_menu")"
  case "$output" in
    *"更新 Xboard"* ) ;;
    * ) echo "断言失败: 菜单缺少更新项" >&2; exit 1 ;;
  esac
  case "$output" in
    *"查看访问信息"* ) ;;
    * ) echo "断言失败: 菜单缺少访问信息项" >&2; exit 1 ;;
  esac
}

test_write_deploy_env() {
  XBOARD_PORT=9777
  XBOARD_ADMIN_EMAIL="owner@example.com"
  cat >"$DEPLOY_ENV_FILE" <<EOF
XBOARD_PORT=${XBOARD_PORT}
XBOARD_ADMIN_EMAIL=${XBOARD_ADMIN_EMAIL}
EOF
  assert_contains "$DEPLOY_ENV_FILE" 'XBOARD_PORT=9777'
  assert_contains "$DEPLOY_ENV_FILE" 'XBOARD_ADMIN_EMAIL=owner@example.com'
}

test_validate_config
test_menu_render
test_write_deploy_env
echo "tests passed"
