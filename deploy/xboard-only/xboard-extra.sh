#!/usr/bin/env bash
set -euo pipefail

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
