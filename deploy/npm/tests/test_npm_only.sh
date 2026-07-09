#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export DEPLOY_ENV_FILE="$TMP_DIR/deploy.env"
export WORK_DIR="$TMP_DIR/runtime"
export NPM_DIR="$WORK_DIR/nginx-proxy-manager"

# shellcheck disable=SC1091
. "${ROOT_DIR}/npm-common.sh"

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq "$expected" "$file" || {
    echo "断言失败: $file 缺少 $expected" >&2
    exit 1
  }
}

test_write_npm_compose() {
  NPM_HTTP_PORT=8080
  NPM_HTTPS_PORT=4443
  NPM_ADMIN_PORT=8081
  EXTRA_NPM_HTTPS_PORTS="8443,9443"
  prepare_dirs
  write_npm_compose
  assert_contains "$NPM_DIR/compose.yaml" '"8080:80"'
  assert_contains "$NPM_DIR/compose.yaml" '"4443:443"'
  assert_contains "$NPM_DIR/compose.yaml" '"8081:81"'
  assert_contains "$NPM_DIR/compose.yaml" '"8443:443"'
  assert_contains "$NPM_DIR/compose.yaml" '"9443:443"'
}

test_set_deploy_env_value() {
  set_deploy_env_value "EXTRA_NPM_HTTPS_PORTS" "7443,8443"
  set_deploy_env_value "NPM_ADMIN_PORT" "18081"
  assert_contains "$DEPLOY_ENV_FILE" 'EXTRA_NPM_HTTPS_PORTS=7443,8443'
  assert_contains "$DEPLOY_ENV_FILE" 'NPM_ADMIN_PORT=18081'
}

test_menu_render() {
  local output
  output="$(TEST_MODE=1 bash -lc ". '${ROOT_DIR}/menu-npm.sh'; show_menu")"
  case "$output" in
    *"更新 NPM"* ) ;;
    * ) echo "断言失败: 菜单缺少更新项" >&2; exit 1 ;;
  esac
  case "$output" in
    *"添加 NPM 额外 HTTPS 端口映射"* ) ;;
    * ) echo "断言失败: 菜单缺少 HTTPS 映射项" >&2; exit 1 ;;
  esac
}

test_write_npm_compose
test_set_deploy_env_value
test_menu_render
echo "tests passed"
