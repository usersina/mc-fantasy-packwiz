# Fantasy Pack Client Setup

Use this guide if you are joining the Fantasy Minecraft server with Prism Launcher or Freesm Launcher.

## Recommended: Updater Instance

Ask for the updater instance zip that matches your keyboard layout:

- QWERTY
- AZERTY

This is the best option because it updates itself every time you launch. New mods, config changes, and datapacks are downloaded before Minecraft starts.

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

## Controls And Keyboard Layout

There are separate QWERTY and AZERTY starter profiles.

If movement, drop, bite, suck, spell casting, or wheel keys feel wrong, ask for the other keyboard layout instance.

Your personal settings can still change after import. The updater does not overwrite your normal local `options.txt` on every launch.

## Manual Fallback: `.mrpack`

If the updater instance zip does not work, ask for the `.mrpack` file matching your keyboard layout:

```txt
mc-fantasy-1.21.1-v1.0.0-qwerty.mrpack
mc-fantasy-1.21.1-v1.0.0-azerty.mrpack
```

Import it with:

```txt
Add Instance
Import
Select the .mrpack file
```

This fallback does not auto-update. If the server pack changes later, you may need a newer file.

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
