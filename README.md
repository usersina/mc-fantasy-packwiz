# MC Fantasty Packwiz

This is a modpack for Minecraft, created using [Packwiz](https://packwiz.org/). It includes a variety of mods that enhance the gameplay experience, adding new features, mechanics, and content to the game.

## Getting Started

## Reference

0. Initial setup command

    ```bash
    packwiz init \
    --name "1.21.1 Fantasy" \
    --author "usersina" \
    --version "1.0.0" \
    --mc-version "1.21.1" \
    --modloader "neoforge" \
    --neoforge-version "21.1.233"
    ```

1. Add mods to the pack using the following command:

    ```bash
    packwiz <loader> add <mod-identifier>

    # E.g.
    packwiz modrinth install jei
    packwiz curseforge install configured
    ```
