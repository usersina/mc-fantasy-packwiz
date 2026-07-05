# Vampire Player Bite Fix

Tiny pack-local compatibility mod for one rule:

- Vampirism vampire players cannot suck blood from other vampire players.

The patch is intentionally narrow. It does not change player feeding in general, Bloodlines blood extraction, mob blood values, cauldrons, or vampire bottles.

## Implementation

The mod injects at the return of Vampirism's `VampirePlayer.determineBiteType(...)`.

If Vampirism has already decided the bite would be `SUCK_BLOOD_PLAYER`, and the target player is in the vampire faction, the bite type is replaced with `NONE`.

This leaves addon checks such as Bloodlines' `canBeBitten(...)` changes intact for non-vampire player targets.
