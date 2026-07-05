# Vampire Cauldron Blood Fix

Tiny NeoForge compatibility mod for this pack.

## Why

Iron's Spells fills `irons_spellbooks:blood_cauldron` when a living entity takes its cauldron damage. Vampirism vampire players should not be able to farm their own blood into that normal Iron's Spells blood cauldron.

## Behavior

When a Vampirism vampire player would take Iron's Spells cauldron damage, this patch cancels that specific damage event.

That means:

- vampire players do not bleed into Iron's Spells blood cauldrons
- vampire players do not take that specific cauldron damage
- non-vampire players still behave normally
- mobs still behave normally
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
