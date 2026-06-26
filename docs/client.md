# Fantasy Pack Client Guide

Use this guide if you are joining the Fantasy Minecraft server with Prism Launcher or Freesm Launcher.

## Recommended: Updater Instance

Ask for the Fantasy Pack updater instance zip.

This is the best option because it updates itself every time you launch. New mods, config changes, key-default updates, and datapacks are downloaded before Minecraft starts.

1. Install Prism Launcher or Freesm Launcher.
2. Make sure the launcher can use Java 21.
3. In the launcher, choose:

    ```txt
    Add Instance
    Import
    ```

4. Select the updater instance zip you were sent.
5. Launch the imported instance.
6. Wait for the updater to finish downloading the pack.
7. Join the multiplayer server with the server address you were given.

Keep using this same imported instance. Do not reinstall the pack for normal updates.

## How Updates Work

The instance runs Packwiz before Minecraft starts. It updates from:

```txt
https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml
```

If the server pack changes, close Minecraft and launch the same instance again. The update should happen automatically.

Do not manually add, remove, or update mods in this instance unless asked. Manual changes can make your client different from the server.

## Controls

The pack provides default key mappings through the Default Options mod. This helps new mods get sane keybinds without replacing your personal `options.txt` every time you launch.

You can still change controls locally in Minecraft. If a key feels wrong, change it in:

```txt
Options
Controls
Key Binds
```

This pack intentionally has one shared default keybinding profile. We do not maintain separate keyboard-layout variants; each player can tweak controls locally.

## Manual Fallback: `.mrpack`

If the updater instance zip does not work, ask for:

```txt
mc-fantasy-1.21.1-v1.0.0.mrpack
```

Import it with:

```txt
Add Instance
Import
Select the .mrpack file
```

This fallback does not auto-update by itself. If the server pack changes later, you may need a newer file or the updater instance zip.

## Troubleshooting

If Minecraft does not start, set the instance to Java 21 in the launcher settings.

If the updater fails, check that you are online, then launch again. If it still fails, send the launcher log.

If the instance launches but does not update, check that the instance has this pre-launch command:

```bash
"$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" -g -s client "https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml"
```

If Freesm refuses an import, try importing with Prism Launcher.

## Singleplayer

The pack is intended to work in local singleplayer too. The same mods and global datapacks are included for local worlds.

## Maintainer: Updater Instance

The preferred client path is a one-time Prism/Freesm updater instance: friends import the instance once, then Packwiz updates mods, config, key defaults, and global Paxi datapacks before each launch.

Create the friend-facing updater instance like this:

1. Export the bootstrap `.mrpack` with `task pack:export-client`.
2. Import that `.mrpack` into Prism or Freesm once so mods and defaults are seeded.
3. Put `packwiz-installer-bootstrap.jar` in that instance's Minecraft folder.
4. Add this pre-launch command:

    ```bash
    "$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" -g -s client "https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml"
    ```

5. Export that configured launcher instance as a zip and send it to friends.

After that first import, friends should launch through that instance. New mods, removed mods, defaultconfigs, Packwiz-managed config, `config/defaultoptions/keybindings.txt`, and `config/paxi/datapacks/` are pulled from the hosted stable Packwiz site before Minecraft starts.

## Maintainer: Manual Export

Run from the repo root:

```bash
task pack:export-client
```

If your Go Task binary is named `go-task`, run `go-task pack:export-client` instead.

The task refreshes Packwiz, derives the Minecraft and pack versions from `pack.toml`, creates `dist/`, and writes:

```txt
dist/mc-fantasy-1.21.1-v1.0.0.mrpack
```

The generated `.mrpack` is ignored by Git because `dist/` and `*.mrpack` are runtime/release outputs. Use it for initial updater-instance creation or as a manual fallback when a friend cannot use the updater instance.

## Maintainer: Key Defaults

This pack does not ship a live `options.txt`. Minecraft owns each player's local `options.txt`, and the updater should not overwrite personal controls, video, audio, chat, or resource-pack settings on every launch.

Default key mappings live in:

```txt
config/defaultoptions/keybindings.txt
```

The Default Options mod reads that file from the instance config folder and applies those defaults for keys that have not already been customized by the player. That gives the pack a safe way to add defaults for new mods without replacing the whole local options file.

When changing controls for a new mod:

1. Open the maintainer client instance.
2. Change the controls in Minecraft.
3. Run:

    ```txt
    /defaultoptions saveKeys
    ```

4. Commit the generated `config/defaultoptions/keybindings.txt`.
5. Run `task pack:site` and `task pack:smoke-update` before publishing.

Do not create QWERTY/AZERTY variants. Keep one shared default and let players adjust controls locally.

## Maintainer: Release Checklist

Before publishing a client update:

```bash
task pack:site
```

Then serve the generated site locally:

```bash
cd dist/site
python3 -m http.server 8081
```

In another terminal:

```bash
PACK_URL=http://127.0.0.1:8081/stable/pack.toml task pack:smoke-update
```

The smoke test installs a clean temp client and verifies:

- Packwiz installer exits successfully
- `mods/`, `defaultconfigs/`, `config/defaultoptions/keybindings.txt`, and `config/paxi/datapacks/` are present
- `Configured`, `Default Options`, and `More Dragon Eggs` resolve from their current metadata

When local smoke testing passes, push to `main`. GitHub Actions rebuilds `dist/site/stable/`, serves it locally, runs the same smoke update against it, and deploys GitHub Pages only after that succeeds.

Update/restart the dedicated server from the same pack version during the same release window.

## Maintainer: Pack Contents

The client export should include:

- client-side mods
- shared `both` mods
- gameplay/worldgen mods needed for local singleplayer, even when they are conceptually server-side
- `config/defaultoptions/keybindings.txt`
- `config/paxi/datapacks/`, `defaultconfigs/`, resource packs, or shaders when they are intentionally included

The client export should not include:

- the generated server runtime
- `server-base/`
- server world saves
- logs, crash reports, libraries, installers, or NeoForge runtime files
- repo docs and Taskfile plumbing
- live launcher `options.txt`

`.packwizignore` keeps repo/server-only files out of the Packwiz index and out of `.mrpack` exports.

The current export shape should contain:

- `modrinth.index.json` for downloadable mods
- `overrides/config/defaultoptions/keybindings.txt`
- `overrides/defaultconfigs/...`
- `overrides/config/paxi/datapacks/...`
- embedded jars for current non-Modrinth export cases:
  - `More Dragon Eggs`
  - `Configured`

It should not contain `overrides/options.txt`, `server-base/`, `scripts/`, `docs/`, `Taskfile.yml`, or `README.md`.

The hosted stable Packwiz site is even smaller: it contains `pack.toml`, `index.toml`, and the files listed in `index.toml`.

## Maintainer: Side Policy

The Packwiz project currently contains every mod from the original source list by project ID.

The Prism/Freesm export is intended to work as a complete playable instance, including local singleplayer. In Modrinth `.mrpack` metadata, `server` means a dedicated server, not Minecraft's integrated singleplayer server. Because of that, mods needed for world generation, gameplay rules, login/skin behavior, or local integrated-server behavior should be marked `side = "both"` here so launchers install them into the client instance.

Use `side = "server"` only for something that truly belongs on the dedicated server and should not be present in a player/imported instance. The dedicated server still gets `both` mods because `task server:start` runs packwiz-installer in server mode.

## Maintainer: Global Datapacks

Datapacks in `config/paxi/datapacks/` are managed by this repo and loaded globally by Paxi.

That means the same convenience recipes are available on the dedicated server and in local Prism/Freesm singleplayer worlds created from the exported `.mrpack`.

## Maintainer: If Export Fails

Most mods are Modrinth-backed. If export prints `added to zip` for a small number of non-Modrinth-compatible files, that can be OK; those jars are embedded in the `.mrpack`.

If export fails because of a restricted download or missing metadata, check the failing mod metadata first. The manual fallback is to import the pack locally in Prism, repair whatever download/import issue appears there, then export a Prism instance zip for friends.

## Maintainer: GitHub Pages

GitHub Pages should be configured to use GitHub Actions as its source. The workflow publishes:

```txt
dist/site/stable/
```

to:

```txt
https://usersina.github.io/mc-fantasy-packwiz/stable/
```

The human-readable Pages root is built from `site/index.html` and published as:

```txt
https://usersina.github.io/mc-fantasy-packwiz/
```

Minecraft or NeoForge version changes still require a new launcher instance zip. Normal mod/config/datapack/key-default updates should flow through the hosted Packwiz updater.

## References

- [Default Options](https://mods.twelveiterations.com/minecraft/default-options)
- [packwiz `modrinth export`](https://packwiz.infra.link/reference/commands/packwiz/modrinth/export/)
- [Paxi](https://modrinth.com/mod/paxi)
- [Prism Launcher import](https://prismlauncher.org/wiki/help-pages/zip-import/)
- [packwiz-installer distribution](https://packwiz.infra.link/tutorials/installing/packwiz-installer/)
- [Prism Launcher custom commands](https://prismlauncher.org/wiki/help-pages/custom-commands/)
