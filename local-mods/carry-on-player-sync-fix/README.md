# Carry On Player Sync Fix

Tiny pack-local compatibility mod for two Carry On multiplayer player-pickup bugs:

- `carryon:sync_carry_data` can disconnect players while encoding stale player-carry NBT.
- Releasing a carried player can hit `otherPlayer is null` when Carry On still thinks the carrier is carrying a player but no passenger is attached.

## Implementation

The patch is intentionally narrow:

- When Carry On serializes carry data with type `PLAYER`, stale block/entity NBT and active scripts are stripped before the packet is encoded.
- When Carry On tries to place a carried player but `getFirstPassenger()` is already null, the stale carry state is cleared and the placement action is canceled.

It does not change Carry On block pickup, normal mob pickup, entity placement, stacking, or CarryOnExtend throwing.
