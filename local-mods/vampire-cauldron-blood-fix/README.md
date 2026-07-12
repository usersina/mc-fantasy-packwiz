# Vampire Cauldron Blood Fix

Tiny NeoForge compatibility mod for this pack.

## Why

Iron's Spells fills `irons_spellbooks:blood_cauldron` when a living entity takes its cauldron damage. Vampires and other undead creatures should not produce usable blood.

## Behavior

When an undead living entity would take Iron's Spells cauldron damage, this patch cancels that specific damage event. It checks Minecraft's native inverted-healing predicate and the pack-owned `fantasy_pack:cauldron_undead` entity-type tag. Vampirism players are checked separately because every player shares the same `minecraft:player` entity type.

That means:

- vampire players and tagged undead mobs do not bleed into Iron's Spells blood cauldrons
- protected undead do not take that specific cauldron damage
- living non-vampire players and non-undead mobs still behave normally
- other Iron's Spells damage types are unchanged

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
mods/vampire-cauldron-blood-fix-1.0.0+mc1.21.1-neoforge.jar
```
