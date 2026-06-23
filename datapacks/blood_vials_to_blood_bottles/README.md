# Blood Vials to Blood Bottles

A tiny Minecraft datapack that bridges Iron's Spells 'n Spellbooks Blood Vials with Vampirism Blood Bottles.

## Recipes

### Weak Blood Bottle

- 1 Blood Vial
- 1 Glass Bottle

Result:

- 1 Vampirism Blood Bottle with `blood:3`

### Medium Blood Bottle

- 2 Blood Vials
- 1 Glass Bottle

Result:

- 1 Vampirism Blood Bottle with `blood:6`

### Full Blood Bottle

- 3 Blood Vials
- 1 Glass Bottle

Result:

- 1 Vampirism Blood Bottle with `blood:9`

## Requirements

- Minecraft 1.21.1
- Iron's Spells 'n Spellbooks
- Vampirism

## Installation

In this repo, leave this datapack unpacked under `datapacks/blood_vials_to_blood_bottles/`. `task server:start` and `task server:sync` copy it into the server runtime and mirror it into the configured world before NeoForge starts.

For standalone use outside this repo, put a zipped copy in your world's `datapacks` folder, then run:

```mcfunction
/reload
/datapack list
```

## Notes

This datapack does not include reverse conversion from Vampirism Blood Bottles to Iron's Spells Blood Vials. Vanilla datapack crafting does not handle that case cleanly because Vampirism Blood Bottles have container/remainder behavior.
