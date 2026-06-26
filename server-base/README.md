# Fantasy LAN Server Runtime Template

This folder is the tracked dedicated-server base template. `task server:setup` copies it into the real runtime folder:

```txt
/data/games/servers/minecraft/fantasy-lan/
```

Files here are part of the repo and should be committed:

- `server.properties`
- `user_jvm_args.txt`

Setup copies these only when they do not exist, so local runtime config edits are not overwritten. Use `FORCE=true task server:setup` to overwrite them during setup.

After setup, use `task server:update` for normal ongoing Packwiz/runtime updates. That task syncs mods, `defaultconfigs/`, Packwiz-managed `config/`, and global Paxi datapacks, but it does not overwrite runtime `server.properties` or `user_jvm_args.txt`.

Use `task server:diff-base` to compare runtime base files with this folder. Use `task server:apply-base` when you intentionally want this template to overwrite runtime base files; it creates a runtime backup first.

Do not put downloaded mod jars, NeoForge libraries, world saves, logs, backups, datapacks, or `eula.txt` in this folder.

This folder is server-only and is intentionally excluded from client `.mrpack` exports. Shared datapacks belong in `../config/paxi/datapacks/`, not here. See `../client/README.md` for the Prism/Freesm client-pack flow.
