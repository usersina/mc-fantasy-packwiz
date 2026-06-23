# Client Pack Export

This folder contains client release inputs and the manual Prism/Freesm `.mrpack` export flow.

Files here are intentionally ignored by Packwiz's normal index so server sync does not copy them into the server runtime. `task pack:export-client` injects the selected client defaults into the generated `.mrpack` as `client-overrides/options.txt`.

Full release automation is intentionally deferred; the future path should probably attach generated `.mrpack` files to a GitHub Release.

## Manual Export

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

The generated `.mrpack` files are ignored by Git because `dist/` and `*.mrpack` are runtime/release outputs.

## Client Defaults

`options-qwerty.txt` or `options-azerty.txt` is exported into the `.mrpack` as `client-overrides/options.txt`.

Those files are intentionally controls-only: they keep all `key_...` lines from the captured launcher profile so mod keybind groups stay coherent, while unrelated graphics, audio, chat, resource pack, and other personal settings stay out of the repo. Minecraft fills missing non-key option lines with defaults when the imported instance first launches.

Current control defaults include the changed Vampirism action wheel keys, Iron's Spells spell controls, Dragon Mounts Remastered dragon command key, and the other keybind adjustments from the captured launcher profile.

The keyboard profiles differ only on the layout-sensitive bindings:

```txt
QWERTY:
key_key.forward:key.keyboard.w
key_key.drop:key.keyboard.q
key_keys.werewolves.bite:key.keyboard.z
key_keys.vampirism.suck:key.keyboard.z

AZERTY:
key_key.forward:key.keyboard.z
key_key.drop:key.keyboard.a
key_keys.werewolves.bite:key.keyboard.w
key_keys.vampirism.suck:key.keyboard.w
```

## Release Checklist

Every time the pack changes and friends need new client files:

```bash
task pack:export-client
task pack:export-client KEYBOARD=azerty
```

Then upload the generated `.mrpack` files to a GitHub Release or send them directly.

## Send To Friends

Send the file matching their keyboard layout:

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
- `config/`, `defaultconfigs/`, resource packs, shaders, or client options when they are intentionally included

The client export should not include:

- the generated server runtime
- `server/base/`
- server world saves
- logs, crash reports, libraries, installers, or NeoForge runtime files
- repo docs and Taskfile plumbing
- repo-managed server datapacks

`.packwizignore` keeps repo/server-only files out of the Packwiz index and out of `.mrpack` exports. `client/**` is also ignored by Packwiz's normal index; the export task adds the selected profile to the `.mrpack` explicitly.

The current export shape has been smoke-tested. The `.mrpack` contains:

- `modrinth.index.json` for downloadable mods
- `client-overrides/options.txt` for client keybind defaults
- `overrides/defaultconfigs/...`
- embedded jars for current non-Modrinth export cases:
  - `More Dragon Eggs`
  - `Configured`

It does not contain `server/`, `docs/`, `Taskfile.yml`, `README.md`, or repo-managed `datapacks/`.

## Side Policy For Singleplayer

The Packwiz project currently contains every mod from the original source list by project ID.

The Prism/Freesm export is intended to work as a complete playable instance, including local singleplayer. In Modrinth `.mrpack` metadata, `server` means a dedicated server, not Minecraft's integrated singleplayer server. Because of that, mods needed for world generation, gameplay rules, login/skin behavior, or local integrated-server behavior should be marked `side = "both"` here so launchers install them into the client instance.

Use `side = "server"` only for something that truly belongs on the dedicated server and should not be present in a player/imported instance. The dedicated server still gets `both` mods because `task server:start` runs packwiz-installer in server mode.

## Current Server Datapack Split

Datapacks in `datapacks/` are managed by this repo for the server. They are copied into the runtime by `task server:start` and `task server:sync`, then mirrored into the configured world folder before NeoForge starts.

Friends do not need those datapacks in their launcher instance to join the server.

## If Export Fails

Most mods are Modrinth-backed. If export prints `added to zip` for a small number of non-Modrinth-compatible files, that can be OK; those jars are embedded in the `.mrpack`.

If export fails because of a restricted download or missing metadata, check the failing mod metadata first. The manual fallback is to import the pack locally in Prism, repair whatever download/import issue appears there, then export a Prism instance zip for friends.

## Deferred Auto-Updating Path

The second path is a packwiz-installer pre-launch instance:

1. Host `pack.toml` somewhere friends can reach, not `127.0.0.1`.
2. Create a Prism/Freesm instance with Minecraft `1.21.1`, NeoForge `21.1.233`, and Java 21.
3. Put `packwiz-installer-bootstrap.jar` in the instance `.minecraft` folder.
4. Add a pre-launch command that runs packwiz-installer against the hosted `pack.toml`.
5. Export that configured launcher instance as a zip.

This is better for frequent updates, but it needs hosting and instance-template decisions, so it is only documented for now.

## References

- [packwiz `modrinth export`](https://packwiz.infra.link/reference/commands/packwiz/modrinth/export/)
- [Prism Launcher import](https://prismlauncher.org/wiki/help-pages/zip-import/)
- [packwiz-installer distribution](https://packwiz.infra.link/tutorials/installing/packwiz-installer/)
- [Prism Launcher custom commands](https://prismlauncher.org/wiki/help-pages/custom-commands/)
