# Client Pack Updates

This folder contains client release inputs for Prism/Freesm.

The preferred client path is a one-time Prism/Freesm updater instance: friends import the instance once, then Packwiz updates mods, config, and global Paxi datapacks before each launch.

Files here are intentionally ignored by Packwiz's normal index so server sync does not copy them into the server runtime. `task pack:export-client` injects the selected client defaults into the generated `.mrpack` as `overrides/options.txt`.

The short guide to send to players is [../docs/client-install.md](../docs/client-install.md).

## Stable Auto-Updating Client

The stable updater URL is:

```txt
https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml
```

Create the friend-facing updater instance like this:

1. Export a QWERTY or AZERTY `.mrpack` with `task pack:export-client`.
2. Import that `.mrpack` into Prism or Freesm once so the client defaults are seeded.
3. Put `packwiz-installer-bootstrap.jar` in that instance's Minecraft folder.
4. Add this pre-launch command:

    ```bash
    "$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" -g -s client "https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml"
    ```

5. Export that configured launcher instance as a zip and send it to friends.

After that first import, friends should launch through that instance. New mods, removed mods, defaultconfigs, Packwiz-managed config, and `config/paxi/datapacks/` are pulled from the hosted stable Packwiz site before Minecraft starts.

## Manual Export Fallback

Run from the repo root:

```bash
task pack:export-client
```

If your Go Task binary is named `go-task`, run `go-task pack:export-client` instead.

The task defaults to the QWERTY control profile. For AZERTY:

```bash
task pack:export-client KEYBOARD=azerty
```

The task refreshes Packwiz, derives the Minecraft and pack versions from `pack.toml`, creates `dist/`, and writes one of:

```txt
dist/mc-fantasy-1.21.1-v1.0.0-qwerty.mrpack
dist/mc-fantasy-1.21.1-v1.0.0-azerty.mrpack
```

The generated `.mrpack` files are ignored by Git because `dist/` and `*.mrpack` are runtime/release outputs. Use them for initial updater-instance creation or as a manual fallback when a friend cannot use the updater instance.

## Client Defaults

`options-qwerty.txt` or `options-azerty.txt` is exported into the `.mrpack` as `overrides/options.txt`. Modrinth `.mrpack` importers copy `overrides/` into the Minecraft instance root, which is where Minecraft reads `options.txt`.

Those files are intentionally controls-only, with one required metadata line: `version:3955`. The version line prevents Minecraft 1.21.1 from treating modern key names as legacy LWJGL numeric key codes during option-file data fixing. After that first line, the profiles keep only `key_...` lines from the captured launcher profile, so mod keybind groups stay coherent while unrelated graphics, audio, chat, resource pack, and other personal settings stay out of the repo. Minecraft fills missing non-key option lines with defaults when the imported instance first launches.

Current control defaults include the changed Vampirism action wheel keys, Iron's Spells spell controls, Dragon Mounts Remastered dragon command key, and the other keybind adjustments from the captured launcher profile.

The keyboard profiles differ only on the layout-sensitive bindings:

```txt
QWERTY:
key_key.forward:key.keyboard.w
key_key.left:key.keyboard.a
key_key.drop:key.keyboard.q
key_keys.werewolves.bite:key.keyboard.z
key_keys.vampirism.suck:key.keyboard.z

AZERTY:
key_key.forward:key.keyboard.z
key_key.left:key.keyboard.q
key_key.drop:key.keyboard.a
key_keys.werewolves.bite:key.keyboard.w
key_keys.vampirism.suck:key.keyboard.w
```

## Release Checklist

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
- `mods/`, `defaultconfigs/`, and `config/paxi/datapacks/` are present
- `Configured` and `More Dragon Eggs` resolve from their current CurseForge metadata

When local smoke testing passes, push to `main`. GitHub Actions rebuilds `dist/site/stable/`, serves it locally, runs the same smoke update against it, and deploys GitHub Pages only after that succeeds.

Update/restart the dedicated server from the same pack version during the same release window.

## Send To Friends

For the updater path, send the exported Prism/Freesm instance zip after you configure the pre-launch command.

For manual fallback, send the `.mrpack` matching their keyboard layout:

```txt
dist/mc-fantasy-1.21.1-v1.0.0-qwerty.mrpack
dist/mc-fantasy-1.21.1-v1.0.0-azerty.mrpack
```

In Prism Launcher or Freesm Launcher, they should import it roughly like this:

```txt
Add Instance
Import
Select the .mrpack file
Launch with Java 21
Multiplayer -> connect to the server IP
```

Prism supports `.mrpack` imports directly. Freesm is Prism-derived, so it should usually behave the same way. If Freesm refuses the file, import with Prism or export a Prism instance zip after import.

## What Belongs In The Client Pack

The client export should include:

- client-side mods
- shared `both` mods
- gameplay/worldgen mods needed for local singleplayer, even when they are conceptually server-side
- `config/paxi/datapacks/`, `defaultconfigs/`, resource packs, shaders, or client options when they are intentionally included

The client export should not include:

- the generated server runtime
- `server-base/`
- server world saves
- logs, crash reports, libraries, installers, or NeoForge runtime files
- repo docs and Taskfile plumbing

`.packwizignore` keeps repo/server-only files out of the Packwiz index and out of `.mrpack` exports. `client/**` is also ignored by Packwiz's normal index; the export task adds the selected profile to the `.mrpack` explicitly.

The current export shape has been smoke-tested. The `.mrpack` contains:

- `modrinth.index.json` for downloadable mods
- `overrides/options.txt` for client keybind defaults
- `overrides/defaultconfigs/...`
- `overrides/config/paxi/datapacks/...`
- embedded jars for current non-Modrinth export cases:
  - `More Dragon Eggs`
  - `Configured`

It does not contain `server-base/`, `scripts/`, `docs/`, `Taskfile.yml`, or `README.md`.

The hosted stable Packwiz site is even smaller: it contains `pack.toml`, `index.toml`, and the files listed in `index.toml`.

## Side Policy For Singleplayer

The Packwiz project currently contains every mod from the original source list by project ID.

The Prism/Freesm export is intended to work as a complete playable instance, including local singleplayer. In Modrinth `.mrpack` metadata, `server` means a dedicated server, not Minecraft's integrated singleplayer server. Because of that, mods needed for world generation, gameplay rules, login/skin behavior, or local integrated-server behavior should be marked `side = "both"` here so launchers install them into the client instance.

Use `side = "server"` only for something that truly belongs on the dedicated server and should not be present in a player/imported instance. The dedicated server still gets `both` mods because `task server:start` runs packwiz-installer in server mode.

## Global Datapacks

Datapacks in `config/paxi/datapacks/` are managed by this repo and loaded globally by Paxi.

That means the same convenience recipes are available on the dedicated server and in local Prism/Freesm singleplayer worlds created from the exported `.mrpack`.

## If Export Fails

Most mods are Modrinth-backed. If export prints `added to zip` for a small number of non-Modrinth-compatible files, that can be OK; those jars are embedded in the `.mrpack`.

If export fails because of a restricted download or missing metadata, check the failing mod metadata first. The manual fallback is to import the pack locally in Prism, repair whatever download/import issue appears there, then export a Prism instance zip for friends.

## GitHub Pages Publishing

GitHub Pages should be configured to use GitHub Actions as its source. The workflow publishes:

```txt
dist/site/stable/
```

to:

```txt
https://usersina.github.io/mc-fantasy-packwiz/stable/
```

Minecraft or NeoForge version changes still require a new launcher instance zip. Normal mod/config/datapack updates should flow through the hosted Packwiz updater.

## References

- [packwiz `modrinth export`](https://packwiz.infra.link/reference/commands/packwiz/modrinth/export/)
- [Paxi](https://modrinth.com/mod/paxi)
- [Prism Launcher import](https://prismlauncher.org/wiki/help-pages/zip-import/)
- [packwiz-installer distribution](https://packwiz.infra.link/tutorials/installing/packwiz-installer/)
- [Prism Launcher custom commands](https://prismlauncher.org/wiki/help-pages/custom-commands/)
