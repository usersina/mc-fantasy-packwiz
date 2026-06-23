# Craftable Arcane Essence

A tiny Minecraft datapack that adds a simple convenience recipe for Iron's Spells 'n Spellbooks.

## Recipe

- 1 Kelp
- 1 Lapis Lazuli
- 1 Phantom Membrane

Result:

- 4 Arcane Essence

## Requirements

- Minecraft 1.21.1
- Iron's Spells 'n Spellbooks

## Installation

In this repo, leave this datapack unpacked under `datapacks/craftable_arcane_essence/`. `task server:start` and `task server:sync` copy it into the server runtime and mirror it into the configured world before NeoForge starts.

For standalone use outside this repo, put a zipped copy in your world's `datapacks` folder, then run:

```mcfunction
/reload
/datapack list
```

## Notes

This datapack is intentionally small and vanilla-friendly. It does not add new items, blocks, loot tables, or progression systems.
