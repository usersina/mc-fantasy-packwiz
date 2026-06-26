# Fantasy LAN Server Runtime Template

This folder is the tracked base server template. `server/setup-fantasy-server.sh` copies it into the real runtime folder:

```txt
/data/games/servers/minecraft/fantasy-lan/
```

Files here are part of the repo and should be committed:

- `server.properties`
- `user_jvm_args.txt`
- `start-packwiz-server.sh`

Setup copies these with `rsync --ignore-existing` by default, so local runtime config edits are not overwritten. It still updates `start-packwiz-server.sh` so launcher fixes are applied. Use `FORCE=true ACCEPT_EULA=true ./server/setup-fantasy-server.sh` from the repo root when you want this template to replace every existing runtime copy.

Do not put downloaded mod jars, NeoForge libraries, world saves, logs, backups, datapacks, or `eula.txt` in this folder.

This folder is server-only and is intentionally excluded from client `.mrpack` exports. Shared datapacks belong in `../../config/paxi/datapacks/`, not here. See `../../client/README.md` for the Prism/Freesm client-pack flow.
