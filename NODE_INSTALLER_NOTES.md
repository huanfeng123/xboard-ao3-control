# Xboard Node Installer Notes

Patched node source:
`/root/Xboard-Node`

Patched behaviors:
- `sing-box` inbound enables `sniff`, `sniff_override_destination`, `sniff_timeout`
- `xray` inbound enables `sniffing` with `routeOnly`

Hosted installer files on panel:
- `/root/xboard-only/runtime/Xboard/storage/app/public/xboard-node/install.sh`
- `/root/xboard-only/runtime/Xboard/storage/app/public/xboard-node/releases/latest/download/*`
- `/root/xboard-only/runtime/Xboard/storage/app/public/xboard-node/releases/download/v1.13-dirty/*`

Panel override for machine install command:
- `/root/xboard-only/runtime/Xboard/overrides/app/Http/Controllers/V2/Admin/Server/MachineController.php`

Container mounts required:
- `./overrides/app/Http/Controllers/V2/Admin/Server/MachineController.php:/www/app/Http/Controllers/V2/Admin/Server/MachineController.php`
- `./storage/app/public:/www/storage/app/public`

Current install command pattern:
`curl -fsSL https://web.ao3l.live/storage/xboard-node/install.sh | sudo bash -s -- --mode machine --panel 'https://web.ao3l.live' --token '...' --machine-id N`

How to publish a new patched node build:
Preferred publish command:
`/root/xboard-only/runtime/Xboard/publish-node-installer.sh`

Examples:
- rebuild + publish:
  `/root/xboard-only/runtime/Xboard/publish-node-installer.sh`
- publish existing artifacts only:
  `/root/xboard-only/runtime/Xboard/publish-node-installer.sh --skip-build`
- rebuild + publish + recreate panel:
  `/root/xboard-only/runtime/Xboard/publish-node-installer.sh --rebuild-panel`

Current service-side AO3-only node policy:
- managed in XBoard database for node IDs `1` and `2`
- currently uses `custom_routes` with AO3 allow rules and global deny rules

Rollback on a machine:
- previous binaries were backed up on each node as:
  - `/usr/local/bin/xboard-node.bak-<timestamp>`
  - `/usr/local/bin/xbctl.bak-<timestamp>`
