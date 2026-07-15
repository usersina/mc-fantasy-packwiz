# Butchery Blood Grate Fix

Tiny pack-local compatibility mod for Butchery 5.1 Blood Grate behavior on NeoForge 1.21.1:

- Butcher's Papers writes the obsolete `fluidTank.FluidName` NBT field, so changing modes does not convert the live tank and later fills are rejected.
- Small carcasses only fill a Blood Grate in Butchery mode; the other generated mode branches are empty.
- Butchery's Vampirism bucket branch randomly returns finished blood 10% of the time, bypassing purification.

## Implementation

The patch is intentionally narrow:

- Butcher's Papers toggles between the two fluids available in this pack: Butchery Blood and Vampirism Impure Blood.
- Existing tank contents are converted in place while preserving their amount.
- Small carcasses add their normal 50 mB pulses to either supported mode.
- Glass bottles cannot extract impure blood directly. It must pass through a Vampirism Blood Sieve first so the mod's 75% conversion rate remains meaningful.
- Empty buckets always extract Vampirism Impure Blood from Vampirism mode; there is no finished-blood lottery.

Companion Paxi data integrates Butchery fluids with the rest of the pack:

- one Blood Bucket is 1000 mB and can be emptied into or filled from the cauldron
- one Bottle of Blood is Butchery's native 333 mB and can be emptied into or filled from the cauldron
- infected blood buckets and bottles can also be emptied into or filled from the cauldron
- Butchery infected blood is accepted by the Vampirism Blood Sieve at a 50% conversion rate
- one Butchery Bottle of Blood converts to a Vampirism Blood Bottle containing three blood units; the remaining 33 mB is the conversion loss

A bucket therefore fills three Butchery bottles and leaves 1 mB in the cauldron. A bucket of infected blood filtered through a Blood Sieve yields 500 mB of finished Vampirism blood.

The mod does not change carcass yields, bleeding duration, Blood Grate capacity, normal Butchery fluid extraction, or large-carcass behavior.
