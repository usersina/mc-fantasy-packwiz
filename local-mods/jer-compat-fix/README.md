# JER Compatibility Fix

Tiny client-only compatibility mod for Just Enough Resources 1.6.0.17.

It fixes two upstream assumptions that break JER in this pack:

- JER builds a vanilla-only biome lookup, which fails when installed mods contribute biomes.
- JER treats some non-living entity types as mobs when their category is not `MISC`.

## Implementation

The patch is intentionally generic:

- Biome lookups use the active client level's registry access.
- Mob-table entries are accepted only when the entity type's base class extends `LivingEntity`.

It does not alter JER categories, loot data, world-generation data, or any Cataclysm Spellbooks entity. Remove this mod when upstream JER fixes both behaviors for Minecraft 1.21.1.
