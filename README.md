# MC Fantasy Packwiz

End-to-end Packwiz repo for the 1.21.1 Fantasy NeoForge pack. The repo owns the pack definition, client export defaults, and the small server bootstrap; the generated Minecraft server runtime lives outside Git.

The main entry point is the Taskfile. Pack tasks call `scripts/pack.sh`; server tasks call `scripts/server.sh`.

## Quick Start

Run these from the repo root.

Prerequisites:

- Java 21 JDK at `/usr/lib/jvm/java-21-openjdk/bin/java`
- `packwiz`
- Go Task, exposed as `task` or `go-task`
- `curl`
- `jq` and `unzip`
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

## Config Folders

Use `config/` for files that should exist at the Minecraft instance root on clients, the dedicated server, or both. Packwiz installs these files directly and updates them on `task server:update`, `task server:start`, client updater launches, and `.mrpack` exports. Examples in this pack are `config/paxi/datapacks/...` and `config/defaultoptions/keybindings.txt`.

Use `defaultconfigs/` for NeoForge config defaults that should seed missing generated configs. On this NeoForge 1.21.1 setup, the server loads these defaults and creates matching active files under the runtime root `config/` folder, not under `world/serverconfig/`.

Use `world/serverconfig/` only as a runtime world-specific override folder. It is not the normal place for this repo's shared Packwiz-managed defaults.

`config/defaultoptions/keybindings.txt` belongs to the Default Options mod. It provides client keybinding defaults without replacing each player's normal `options.txt` every launch.

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

## Inspecting Mods and Packs

Use the inspector when adding a mod and you need to discover keybindings, likely generated config files, or what the Packwiz client actually installs.

Inspect one Packwiz mod metadata file or jar:

```bash
task pack:inspect INSPECT=mod MOD=mods/beltborne-lanterns.pw.toml
```

Inspect a real Prism/Freesm instance after launching it once:

```bash
task pack:inspect INSPECT=instance INSTANCE_MC_DIR=/path/to/instance/minecraft
```

Materialize the Packwiz client into an ignored inspection folder and scan it:

```bash
task pack:inspect INSPECT=pack PACK_URL=http://127.0.0.1:8081/stable/pack.toml
```

Generate a temporary dedicated server runtime under `dist/inspect/` and report generated configs:

```bash
task pack:inspect INSPECT=server-generated
```

Inspection reports are written to `dist/inspect/`. They are intentionally read-only reports: use them to decide what to commit, then update `config/`, `defaultconfigs/`, or `config/defaultoptions/keybindings.txt` yourself.

## When a Mod Adds Config or Controls

When adding a mod, first add it through Packwiz and refresh:

```bash
packwiz modrinth add <mod-slug>
task pack:refresh
```

Then inspect the mod for likely controls and config files:

```bash
task pack:inspect INSPECT=mod MOD=mods/<mod-file>.pw.toml
```

If the mod has controls, prefer Default Options:

1. Use the inspection report to find keybinding IDs and default keys.
2. Open the maintainer client instance when you need to confirm names in Minecraft.
3. Change the controls in Minecraft.
4. Run `/defaultoptions saveKeys`.
5. Commit the updated `config/defaultoptions/keybindings.txt`.

Do not commit a full `options.txt`; it would overwrite player preferences such as controls, video, audio, and resource packs.

If the mod has config files, decide ownership before copying anything:

| Generated file kind        | Commit where            | Use when                                                                         |
| -------------------------- | ----------------------- | -------------------------------------------------------------------------------- |
| Client/shared live config  | `config/<file>`         | The file should be installed and updated directly on clients and/or the server.  |
| NeoForge generated default | `defaultconfigs/<file>` | The file should seed missing generated server/common configs on a fresh runtime. |
| Runtime-only local state   | nowhere                 | The file is a cache, log, generated world data, or personal/local setting.       |

To discover generated server configs, run:

```bash
task pack:inspect INSPECT=server-generated
```

That creates a temporary server under `dist/inspect/server-generated/runtime`, launches it once, stops it, and writes `dist/inspect/server-generated.md`. Compare generated files from that temp runtime, then copy only intentional defaults into `config/` or `defaultconfigs/`.

To discover client-side generated configs, launch a real maintainer Prism/Freesm instance once, then scan its Minecraft folder:

```bash
task pack:inspect INSPECT=instance INSTANCE_MC_DIR=/path/to/instance/minecraft
```

For this pack, a successful generated-server inspection should show:

- Packwiz-managed datapacks under `config/paxi/datapacks/`
- committed defaults under `defaultconfigs/`
- generated active server configs under runtime `config/`
- `world/serverconfig/readme.txt`, unless you intentionally add world-specific overrides

## Mod Notes

Carry On uses the unofficial patched `carryon-neoforge-1.21.1-2.2.4.4-patched-no-slowness.jar` intentionally because the official 1.21.1 build hit server stability problems in this pack. Player pickup remains enabled, but it has an intermittent `carryon:sync_carry_data` disconnect risk, so do not update or swap Carry On casually without retesting multiplayer player pickup.

## Client Updates

The public client bootstrap is the `.mrpack` published on GitHub Releases. The recommended player flow is to import the `.mrpack` once, then add the tested Packwiz pre-launch updater to that same Prism/Freesm instance. The launcher's Modrinth **Update Pack** tab is the fallback manual update path.

The stable player import URL is:

```txt
https://github.com/usersina/mc-fantasy-packwiz/releases/download/client-stable/mc-fantasy-stable.mrpack
```

A prepared Prism/Freesm updater instance can use the live Packwiz channel:

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

The `.mrpack` export is the public bootstrap client pack. Ongoing keybind defaults are handled by Default Options through `config/defaultoptions/keybindings.txt`, without replacing each player's live `options.txt` on every launch.

```bash
task pack:export-client
```

That writes `dist/mc-fantasy-stable.mrpack`, deriving the Minecraft and pack versions from `pack.toml`.

CI publishes the exported `.mrpack` to the `client-stable` GitHub Release after the updater smoke test passes:

```txt
https://github.com/usersina/mc-fantasy-packwiz/releases/latest
```

See [docs/client.md](docs/client.md) for the player setup guide, updater instance setup, `.mrpack` release flow, and release checklist.

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
task pack:export-client    # export the Prism/Freesm .mrpack bootstrap
task pack:inspect          # inspect mods, packs, instances, or generated server config
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

Pack maintenance commands can also call the single pack script directly:

```bash
INSPECT=mod MOD=mods/beltborne-lanterns.pw.toml ./scripts/pack.sh inspect
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
packwiz modrinth add jei
packwiz curseforge add configured
```
