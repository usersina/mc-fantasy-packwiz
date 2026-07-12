# Butchery Blood Grate Fix

Tiny pack-local compatibility mod for two Butchery 5.1 Blood Grate bugs on NeoForge 1.21.1:

- Butcher's Papers writes the obsolete `fluidTank.FluidName` NBT field, so changing modes does not convert the live tank and later fills are rejected.
- Small carcasses only fill a Blood Grate in Butchery mode; the other generated mode branches are empty.

## Implementation

The patch is intentionally narrow:

- Butcher's Papers toggles between the two fluids available in this pack: Butchery Blood and Vampirism Impure Blood.
- Existing tank contents are converted in place while preserving their amount.
- Small carcasses add their normal 50 mB pulses to either supported mode.
- Glass bottles cannot extract impure blood directly. It must pass through a Vampirism Blood Sieve first so the mod's 75% conversion rate remains meaningful.

Companion Paxi recipes let an Iron's Spells Alchemist Cauldron accept one Butchery Blood Bucket as 1000 mB and fill one Bottle of Blood from each 333 mB. This yields three bottles and leaves the expected 1 mB rounding remainder without requiring a custom crafting hook.

The mod does not change carcass yields, bleeding duration, Blood Grate capacity, normal Butchery fluid extraction, or large-carcass behavior.
