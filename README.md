# MC Fantasy Packwiz

End-to-end Packwiz repo for the 1.21.1 Fantasy NeoForge server. The goal is that the repo owns the pack definition and the lightweight server bootstrap, while the actual Minecraft runtime stays outside Git.

## Quick Start

Run these from the repo root.

Prerequisites:

- Java 21 at `/usr/lib/jvm/java-21-openjdk/bin/java`
- `packwiz`
- `task` from Go Task
- `curl` and `rsync`

First, set up the generated server runtime:

```bash
task server:setup
```

Then keep Terminal 1 open to serve the pack:

```bash
task pack:serve
```

Then use Terminal 2 to sync server-side Packwiz files and start NeoForge:

```bash
task server:start
```

The real server runtime is generated here:

```txt
/data/games/servers/minecraft/fantasy-lan/
```

## What Gets Used

The base server template lives in `server/base/`. `task server:setup` runs `server/setup-fantasy-server.sh`, which copies these files into the runtime directory:

- `server/base/server.properties`
- `server/base/user_jvm_args.txt`
- `server/base/start-packwiz-server.sh`

By default, setup uses `rsync --ignore-existing`, so existing runtime config is preserved. It still updates `start-packwiz-server.sh` so launcher fixes are applied. To overwrite every runtime copy from the repo template, run:

```bash
FORCE=true ACCEPT_EULA=true ./server/setup-fantasy-server.sh
```

`server/base/server.properties` is intentionally tracked. The generated runtime `server.properties` at the repo root is ignored, but the template under `server/base/` is not.

## Useful Tasks

Task names use `domain:action`: `pack:*` for Packwiz work and `server:*` for runtime work.

Initialize the server runtime without starting it:

```bash
task server:setup
```

Refresh the Packwiz index after changing pack files:

```bash
task pack:refresh
```

Back up the current world and runtime config:

```bash
task server:backup
```

Rebuild the generated runtime from scratch:

```bash
rm -rf /data/games/servers/minecraft/fantasy-lan
task server:setup
```

Then run `task pack:serve` and `task server:start` again.

## Overrides

The default runtime path and Java path are in `Taskfile.yml`. For one-off direct script runs:

```bash
SERVER_DIR=/path/to/server JAVA21=/path/to/java ACCEPT_EULA=true ./server/setup-fantasy-server.sh
```

## Troubleshooting

If startup fails with `Unsupported class file major version 70`, the server launched with Java 26. Run setup again so the runtime gets the tracked launcher script, then start the server:

```bash
task server:setup
task server:start
```

The startup log should show Java 21. If it does not, update `JAVA21` in `Taskfile.yml` or run with `JAVA21=/path/to/java21`.

## Packwiz Reference

- Initial setup command

    ```bash
    packwiz init \
    --name "1.21.1 Fantasy" \
    --author "usersina" \
    --version "1.0.0" \
    --mc-version "1.21.1" \
    --modloader "neoforge" \
    --neoforge-version "21.1.233"
    ```

- Add mods to the pack using the following command:

    ```bash
    packwiz <loader> add <mod-identifier>

    # E.g.
    packwiz modrinth install jei
    packwiz curseforge install configured
    ```
