# Vampirism Convenience Recipes

Minecraft 1.21.1 datapack.

This combines the old `blood_vials_to_blood_bottles` datapack with extra Vampirism convenience recipes.

## Recipes

### Pure Blood 4

Crafting table:

```txt
. G .
V H V
. N .
```

- `G` = Glowstone Dust
- `V` = Iron's Spellbooks Blood Vial
- `H` = Vampirism Human Heart
- `N` = Nether Wart

Output:

```txt
1x vampirism:pure_blood_4
```

### Blood Bottle to Blood Vials

Stonecutter:

Input:

```txt
1x vampirism:blood_bottle (with blood = 9)
```

Output:

```txt
3x irons_spellbooks:blood_vial
```

Note: uses a NeoForge component ingredient that matches blood bottles containing exactly 9 blood. The `strict: false` flag means other mods' blood bottles with a `vampirism:bottle_blood` component may also match.

### Blood Vials to Blood Bottles

Shapeless:

```txt
1x irons_spellbooks:blood_vial + 1x minecraft:glass_bottle
```

Output:

```txt
1x vampirism:blood_bottle with blood = 3
```

```txt
2x irons_spellbooks:blood_vial + 1x minecraft:glass_bottle
```

Output:

```txt
1x vampirism:blood_bottle with blood = 6
```

```txt
3x irons_spellbooks:blood_vial + 1x minecraft:glass_bottle
```

Output:

```txt
1x vampirism:blood_bottle with blood = 9
```
