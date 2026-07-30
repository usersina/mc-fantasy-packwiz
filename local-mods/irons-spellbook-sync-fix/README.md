# Iron's Spellbook Sync Fix

Tiny client-only compatibility patch for Iron's Spells 'n Spellbooks 3.16.2.

## Why

Corpse Curios Compatibility restores Curios slots directly and asynchronously.
Iron's Spells can rebuild its client spell-selection cache before the restored
slot reaches the client. The equipped spellbook is then visible but unusable
until it is manually removed and equipped again, and the spell bar can remain
after removal.

## Behavior

- Refreshes Iron's client spell-selection cache once when a client world becomes active.
- Watches Iron's actual equipped spellbook stack and refreshes only when its item or
  components change.
- Clears its observation state when the client disconnects so old worlds are not
  retained in memory.
- Does not change spell cooldowns, spell data, Curios contents, corpse restoration,
  or server behavior.

The tracked `config/immediatelyfast.json` separately disables ImmediatelyFast HUD
batching so Iron's cooldown overlay remains visible outside the spell wheel.

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
mods/irons-spellbook-sync-fix-1.0.0+mc1.21.1-neoforge.jar
```
