# MC Fantasy Packwiz

End-to-end Packwiz repo for the 1.21.1 Fantasy NeoForge pack. The repo owns the pack definition, client export defaults, and the small server bootstrap; the generated Minecraft server runtime lives outside Git.

The main entry point is the Taskfile. Server tasks call one script, `scripts/server.sh`.

## Quick Start

Run these from the repo root.

Prerequisites:

- Java 21 at `/usr/lib/jvm/java-21-openjdk/bin/java`
- `packwiz`
- Go Task, exposed as `task` or `go-task`
- `curl`
- `zip` for client exports
- `tar` with zstd support for backups

Examples use `task`. If your binary is named `go-task`, replace `task` with `go-task`.

Set up the generated server runtime once:

```bash
task server:setup
```

Then keep Terminal 1 open to serve the Packwiz pack:

```bash
task pack:serve
```

Then use Terminal 2 to sync the runtime and start NeoForge:

```bash
task server:start
```

The generated server runtime is:

```txt
/data/games/servers/minecraft/fantasy-lan/
```

## Server Workflow

`task server:setup` creates the runtime, installs NeoForge, downloads the Packwiz installer, accepts the EULA for this local runtime, and copies the base templates from `server-base/`.

It only copies these base files when they are missing, unless you pass `FORCE=true`:

- `server-base/server.properties`
- `server-base/user_jvm_args.txt`

For normal ongoing changes, use:

```bash
task server:update
```

That syncs Packwiz-managed files into the existing runtime without starting the server. It requires `task pack:serve` to be running in another terminal unless `PACK_URL` points at another reachable `pack.toml`.

`task server:start` does the same sync first, then starts NeoForge.

## Runtime Ownership

| Files                                                                                  | Owner                               | Normal update path                                                      |
| -------------------------------------------------------------------------------------- | ----------------------------------- | ----------------------------------------------------------------------- |
| `mods/`, `defaultconfigs/`, `config/paxi/datapacks/`, and Packwiz-indexed `config/...` | Packwiz                             | `task server:update` or `task server:start`                             |
| Runtime `server.properties` and `user_jvm_args.txt`                                    | runtime, seeded from `server-base/` | `task server:diff-base`, then `task server:apply-base` when intentional |
| `world/`, `logs/`, `eula.txt`, generated libraries, generated configs                  | runtime                             | never committed, never overwritten by normal updates                    |

`server-base/server.properties` is tracked on purpose. A generated `server.properties` at the repo root or inside the runtime is not.

To review base-template drift:

```bash
task server:diff-base
```

To intentionally overwrite the runtime base files from `server-base/`:

```bash
task server:apply-base
```

That creates a timestamped backup under:

```txt
/data/games/servers/minecraft/fantasy-lan/base-template-backups/
```

## Datapacks

Put shared global datapacks in:

```txt
config/paxi/datapacks/<datapack-name>/
```

Paxi loads those datapacks for every world. Because they are Packwiz-managed files, they are included in:

- dedicated server syncs via `task server:update` and `task server:start`
- Prism/Freesm `.mrpack` exports via `task pack:export-client`

Do not put shared datapacks under `server-base/`; that folder is only for the dedicated server base templates.

## Client Pack

For Prism Launcher or Freesm Launcher:

```bash
task pack:export-client
```

That writes a QWERTY `.mrpack` into `dist/`, deriving the Minecraft and pack versions from `pack.toml` and injecting `client/options-qwerty.txt`.

For AZERTY:

```bash
task pack:export-client KEYBOARD=azerty
```

See [client/README.md](client/README.md) for the full manual export flow, what goes into the `.mrpack`, and the deferred auto-updating path.

## Useful Tasks

Task names use `domain:action`: `pack:*` for Packwiz work and `server:*` for runtime work.

```bash
task server:setup          # create/install the runtime once
task pack:serve            # serve pack.toml locally on port 8080
task server:update         # sync Packwiz-managed files without starting
task server:start          # sync, then start NeoForge
task server:diff-base      # compare runtime base files with server-base
task server:apply-base     # back up and overwrite runtime base files
task server:backup         # back up the active world and runtime config
task pack:refresh          # refresh packwiz index files
task pack:export-client    # export the QWERTY Prism/Freesm .mrpack
```

Rebuild the generated runtime from scratch:

```bash
rm -rf /data/games/servers/minecraft/fantasy-lan
task server:setup
```

Then run `task pack:serve` and `task server:start` again.

## Overrides

Override Taskfile defaults for one run:

```bash
task server:start SERVER_DIR=/path/to/server JAVA21=/path/to/java21
```

Or call the single server script directly:

```bash
SERVER_DIR=/path/to/server JAVA21=/path/to/java21 ACCEPT_EULA=true ./scripts/server.sh setup
```

## Troubleshooting

If startup fails with `Unsupported class file major version 70`, the server launched with Java 26. Use the Taskfile path or set `JAVA21` to a Java 21 executable:

```bash
task server:start JAVA21=/path/to/java21
```

The startup log should show Java 21. If the runtime has not been created yet, run `task server:setup` first.

If `task server:update` or `task server:start` cannot reach `pack.toml`, make sure `task pack:serve` is still running in another terminal.

## Packwiz Notes

After editing pack files directly, run:

```bash
task pack:refresh
```

Add new mods through Packwiz so metadata stays correct:

```bash
packwiz modrinth install jei
packwiz curseforge install configured
```
