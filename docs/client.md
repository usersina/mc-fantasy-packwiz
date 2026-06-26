# Fantasy Pack Client Guide

Use this guide if you are joining the Fantasy Minecraft server with Prism Launcher or Freesm Launcher.

## Initial Setup

Start here for every setup. This creates the Prism/Freesm instance you will use to join the server.

```txt
https://github.com/usersina/mc-fantasy-packwiz/releases/download/client-stable/mc-fantasy-stable.mrpack
```

1. Install Prism Launcher or Freesm Launcher.
2. Make sure the launcher can use Java 21.
3. In the launcher, choose:

    ```txt
    Add Instance
    Import
    ```

4. Paste this `.mrpack` URL:

    ```txt
    https://github.com/usersina/mc-fantasy-packwiz/releases/download/client-stable/mc-fantasy-stable.mrpack
    ```

5. Launch the imported instance.
6. Wait for the launcher to finish downloading the pack.
7. Join the multiplayer server with the server address you were given.

At this point the pack is installed. For future server updates, choose one of the update methods below.

## Updates

There are two update methods:

- **Manual update:** re-import the `.mrpack` when the server owner publishes a new client release.
- **Automatic update:** add Packwiz Installer Bootstrap and a pre-launch command to the same instance.

The manual update method is the currently tested path. The automatic update method is documented below, but treat it as experimental until we test it with a real Prism/Freesm client instance.

## Update Method 1: Manual Re-Import (Tested)

Use this if you want the simplest and safest process.

When the server owner says the pack changed:

1. Close Minecraft.
2. In Prism Launcher or Freesm Launcher, choose:

    ```txt
    Add Instance
    Import
    ```

3. Paste the same stable `.mrpack` URL:

    ```txt
    https://github.com/usersina/mc-fantasy-packwiz/releases/download/client-stable/mc-fantasy-stable.mrpack
    ```

4. Import it as the updated client instance.
5. Launch the updated instance.

This is a snapshot update. Restarting an old `.mrpack` instance does not automatically check for new releases.

## Update Method 2: Automatic Packwiz Updater (Experimental)

Use this if you want the same instance to update itself before Minecraft starts.

Status: documented, but not fully tested yet with a real client instance.

This method continues from **Initial Setup**. Start with the instance you already imported from the `.mrpack`, then add the updater pieces.

You will use this Packwiz URL:

```txt
https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml
```

1. Close Minecraft.
2. Right-click the imported instance and choose:

    ```txt
    Edit
    ```

3. Open the instance Minecraft folder from the launcher. In Prism this is usually available from the instance edit window as:

    ```txt
    Folder
    Minecraft
    ```

4. Download Packwiz Installer Bootstrap:

    ```txt
    https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar
    ```

5. Put the downloaded file directly in the instance Minecraft folder. The final path must look like:

    ```txt
    <instance Minecraft folder>/packwiz-installer-bootstrap.jar
    ```

6. In the instance settings, open:

    ```txt
    Settings
    Custom commands
    ```

7. Add this as the pre-launch command:

    ```bash
    "$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" -g -s client "https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml"
    ```

8. Save the instance settings.
9. Launch the same instance.
10. Wait for Packwiz to finish, then Minecraft will start.

After this, keep using the same instance. When the server owner publishes a pack update, close Minecraft and launch this same instance again. Packwiz should update it before Minecraft starts.

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

## Troubleshooting

If Minecraft does not start, set the instance to Java 21 in the launcher settings.

If the `.mrpack` import fails, check that you are online, then try again. If it still fails, send the launcher log.

If you expected automatic updates but the instance launches without updating, check that the instance has this pre-launch command:

```bash
"$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" -g -s client "https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml"
```

If Freesm refuses an import, try importing with Prism Launcher.

## Singleplayer

The pack is intended to work in local singleplayer too. The same mods and global datapacks are included for local worlds.

## Maintainer: Updater Instance

The public `.mrpack` release is the default player-facing bootstrap. It does not auto-update by itself. A manually prepared Prism/Freesm updater instance is still useful for friends who should receive automatic Packwiz updates on every launch.

Create the friend-facing updater instance like this:

1. Export the bootstrap `.mrpack` with `task pack:export-client`.
2. Import that `.mrpack` into Prism or Freesm once so mods and defaults are seeded.
3. Put `packwiz-installer-bootstrap.jar` in that instance's Minecraft folder.
4. Add this pre-launch command:

    ```bash
    "$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" -g -s client "https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml"
    ```

5. Export that configured launcher instance as a zip if you want a one-import auto-updating instance for friends.

After that first import, friends should launch through that instance. New mods, removed mods, defaultconfigs, Packwiz-managed config, `config/defaultoptions/keybindings.txt`, and `config/paxi/datapacks/` are pulled from the hosted stable Packwiz site before Minecraft starts.

## Maintainer: Manual Export

Run from the repo root:

```bash
task pack:export-client
```

If your Go Task binary is named `go-task`, run `go-task pack:export-client` instead.

The task refreshes Packwiz, derives the Minecraft and pack versions from `pack.toml`, creates `dist/`, and writes:

```txt
dist/mc-fantasy-stable.mrpack
```

The stable filename gives players a URL that does not change when the pack version changes.

The generated `.mrpack` file is ignored by Git because `dist/` and `*.mrpack` are runtime/release outputs. Use it as the public bootstrap client pack and for initial updater-instance creation.

CI publishes the exported `.mrpack` to the `client-stable` GitHub Release after the updater smoke test passes:

```txt
https://github.com/usersina/mc-fantasy-packwiz/releases/latest
```

The stable direct import URL is:

```txt
https://github.com/usersina/mc-fantasy-packwiz/releases/download/client-stable/mc-fantasy-stable.mrpack
```

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

The same workflow exports the manual `.mrpack` and updates the `client-stable` GitHub Release only after the smoke test succeeds.

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

If export fails because of a restricted download or missing metadata, check the failing mod metadata first. A manual recovery path is to import the pack locally in Prism, repair whatever download/import issue appears there, then export a Prism instance zip.

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
