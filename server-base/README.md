# Server Base Template

Tracked base files for the dedicated server runtime.

`task server:setup` copies this folder into:

```txt
/data/games/servers/minecraft/fantasy-lan/
```

## Tracked Here

- `server.properties`
- `user_jvm_args.txt`

## Copy Rules

During setup:

- files are copied only when missing
- existing runtime edits are preserved
- `FORCE=true task server:setup` overwrites during setup

After setup:

- use `task server:update` for normal Packwiz updates
- use `task server:diff-base` to compare runtime files with this folder
- use `task server:apply-base` to overwrite runtime base files intentionally
- `server:apply-base` creates a runtime backup first

## Do Not Put Here

- downloaded mod jars
- NeoForge libraries
- world saves
- logs
- backups
- datapacks
- `eula.txt`

Shared datapacks belong in:

```txt
../config/paxi/datapacks/
```

This folder is server-only and excluded from client `.mrpack` exports.
