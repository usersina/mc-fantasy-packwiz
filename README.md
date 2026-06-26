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

## Client Updates

The preferred client path is now a Prism/Freesm updater instance. Friends import the instance once, and a pre-launch Packwiz installer updates mods, config, and global Paxi datapacks from:

```txt
https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml
```

The Pages root, `https://usersina.github.io/mc-fantasy-packwiz/`, is a human-readable explainer. Launchers and Packwiz should use the `stable/pack.toml` URL above.

Build the hosted Packwiz site locally:

```bash
task pack:site
```

Smoke-test the client updater against a served copy before release:

```bash
cd dist/site
python3 -m http.server 8081
```

Then in another terminal:

```bash
PACK_URL=http://127.0.0.1:8081/stable/pack.toml task pack:smoke-update
```

The manual `.mrpack` export still exists as the first-import/bootstrap path and as a fallback. Ongoing keybind defaults are handled by Default Options through `config/defaultoptions/keybindings.txt`, without replacing each player's live `options.txt` on every launch.

```bash
task pack:export-client
```

That writes `dist/mc-fantasy-1.21.1-v1.0.0.mrpack`, deriving the Minecraft and pack versions from `pack.toml`.

See [docs/client.md](docs/client.md) for the player setup guide, updater instance setup, manual `.mrpack` fallback, and release checklist.

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
task pack:site             # build dist/site/stable for GitHub Pages
task pack:smoke-update     # verify client updater installs successfully
task pack:export-client    # export the Prism/Freesm .mrpack fallback
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
