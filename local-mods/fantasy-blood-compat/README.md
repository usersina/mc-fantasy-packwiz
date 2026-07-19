# Fantasy Blood Compatibility

Tiny pack-local compatibility mod for clean blood stored in Iron's Spells' Alchemist Cauldron.

## Behavior

- Fluids in `fantasy_pack:clean_blood` merge at a one-to-one ratio inside the Alchemist Cauldron.
- The first clean fluid determines the stored identity and therefore the matching output container.
- Iron's blood-based brewing recipes accept any clean blood.
- Existing cauldrons with several clean blood tanks are consolidated without changing the total amount.
- A wet Butchery Sponge drains and discards up to `1000 mB` per use from a Blood Grate, Alchemist Cauldron, or Vampirism Blood Container.
- Butchery humanoid flesh, hearts, eyes, and blood sausages restore balanced amounts of blood when eaten by vampire players.
- A Butchery Heart restores `5` blood and yields `50 mB` in the Blood Grinder; four hearts therefore equal one Vampirism Human Heart.
- The same items retain their original hunger values for non-vampires.
- Impure blood, fill/empty recipes, potions, inks, and unrelated fluids are unchanged.

Sponge cleanup never converts fluids. It drains the live stored stack, so the first-fluid identity rule remains intact.

Vampirism Blood Bottles are filled and emptied through Vampirism's Blood Container, not the Alchemist Cauldron. The fluid tags and Blood Sieve conversion rates are supplied by the pack's Paxi datapack. This mod does not add fluids, items, recipes, or a new conversion machine.

Butchery blood bottles are intentionally not vampire foods. Vampire's Delight bypasses an item's original finish-use callback when consuming component-based vampire food, which would lose Butchery's empty-bottle and infected-blood behavior. Use the pack's fluid conversion and purification workflows for those bottles.
