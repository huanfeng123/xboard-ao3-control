# xboard-ao3-control

Customized XBoard control-plane deployment for self-hosted node installation and AO3-only routing.

## What is included

- Docker-based XBoard runtime
- Panel override for machine install commands
- Self-hosted `xboard-node` installer and release files
- AO3-only route helper scripts
- One-command publish script for patched node builds

## Important paths

- Runtime: `/root/xboard-only/runtime/Xboard`
- Patched node source: `/root/Xboard-Node`
- Hosted installer: `storage/app/public/xboard-node/install.sh`
- Hosted release files: `storage/app/public/xboard-node/releases/`

## Publish patched node builds

```bash
/root/xboard-only/runtime/Xboard/publish-node-installer.sh
```

Common variants:

```bash
/root/xboard-only/runtime/Xboard/publish-node-installer.sh --skip-build
/root/xboard-only/runtime/Xboard/publish-node-installer.sh --rebuild-panel
```

## Machine install command pattern

```bash
curl -fsSL https://web.ao3l.live/storage/xboard-node/install.sh | sudo bash -s -- --mode machine --panel 'https://web.ao3l.live' --token 'TOKEN' --machine-id N
```

## Notes

- Real runtime secrets stay in `.env` and are intentionally not tracked.
- Release binaries under `storage/app/public/xboard-node/releases/` are ignored and should be published by script, not committed manually.
- See `NODE_INSTALLER_NOTES.md` for maintenance details.
