# Client Pack Export

This repo currently supports the manual client-pack path: export a Modrinth `.mrpack` and send it to friends for Prism Launcher or Freesm Launcher import.

The local export is automated by `task pack:export-client`. Full release automation is intentionally deferred; that future path should probably attach the generated `.mrpack` to a GitHub Release.

## Manual Export

Run from the repo root:

```bash
task pack:export-client
```

If your Go Task binary is named `go-task`, run `go-task pack:export-client` instead.

The task refreshes Packwiz, derives the Minecraft and pack versions from `pack.toml`, creates `dist/`, and writes:

```txt
dist/mc-fantasy-1.21.1-v1.0.0.mrpack
```

The generated `.mrpack` is ignored by Git because `dist/` and `*.mrpack` are runtime/release outputs.

## Client Defaults

`client/options.txt` is exported into the `.mrpack` as `client-overrides/options.txt`.

That file is intentionally partial: it keeps only keybind lines that differ from a reset/default launcher profile. Unchanged controls, graphics, audio, chat, and other personal settings stay out of the repo. Minecraft fills missing option lines with defaults when the imported instance first launches.

Current control defaults include the changed Vampirism action wheel keys, Iron's Spells spell controls, Dragon Mounts Remastered dragon command key, and the other keybind adjustments from the captured launcher profile.

`client/**` is listed in `.packwizignore`, so these client-only defaults do not enter the normal Packwiz index and are not synced into the server runtime.

## Release Checklist

Every time the pack changes and friends need a new client file:

```bash
task pack:export-client
```

Then upload the generated `.mrpack` to a GitHub Release or send it directly.

## Send To Friends

Send:

```txt
dist/mc-fantasy-1.21.1-v1.0.0.mrpack
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
- `config/`, `defaultconfigs/`, resource packs, shaders, or client options when they are intentionally tracked by Packwiz

The client export should not include:

- the generated server runtime
- `server/base/`
- server world saves
- logs, crash reports, libraries, installers, or NeoForge runtime files
- repo docs and Taskfile plumbing
- repo-managed server datapacks

`.packwizignore` keeps those repo/server-only files out of the Packwiz index and out of `.mrpack` exports.

The current export shape has been smoke-tested. The `.mrpack` contains:

- `modrinth.index.json` for downloadable mods
- `client-overrides/options.txt` for client keybind defaults
- `overrides/defaultconfigs/...`
- embedded jars for current non-Modrinth export cases:
  - `More Dragon Eggs`
  - `Configured`

It does not contain `server/`, `docs/`, `Taskfile.yml`, `README.md`, or repo-managed `datapacks/`.

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
