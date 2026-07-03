# Vampire Invisibility Aggro Fix

Tiny NeoForge compatibility mod for this pack.

## Why

Vampirism's vampire invisibility action calls `Player.setInvisible(true)`, but it does not apply the vanilla `minecraft:invisibility` effect and does not clear mob aggro. That means mods which fix vanilla invisibility, such as Invisibility Aggro Fix, do not help this specific action.

This patch treats the active `vampirism:vampire_invisibility` action as stealth for mob targeting.

## Behavior

While a player has the Vampirism vampire invisibility action active:

- mobs are prevented from selecting that player as a new target
- mobs that already target that player drop the target
- mob navigation/aggressive state/brain attack target are cleared
- visibility checks from mobs are reduced

It does not change ordinary invisibility potions, Iron's Spells true invisibility, or non-vampire invisible players.

## Build

First materialize a server runtime so the compile classpath exists:

```bash
go-task pack:inspect INSPECT=server-generated
```

Then build:

```bash
go-task local-mods:build
```

The jar is written to:

```text
mods/vampire-invisibility-aggro-fix-1.0.0+mc1.21.1-neoforge.jar
```
