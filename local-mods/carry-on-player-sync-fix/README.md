# Carry On Sync Fix

Tiny pack-local compatibility mod for Carry On multiplayer synchronization bugs:

- `carryon:sync_carry_data` can disconnect every recipient when several Netty threads encode the same mutable carry NBT.
- Player pickup can retain stale block/entity NBT in carry data.
- Releasing a carried player can hit `otherPlayer is null` when Carry On still thinks the carrier is carrying a player but no passenger is attached.

## Implementation

The patch is intentionally limited to synchronization and stale player state:

- Carry data serialization returns a detached tag instead of mutating and returning Carry On's live internal tag.
- Every sync packet freezes its own detached carry-data snapshot before asynchronous network encoding begins.
- Starting a player carry strips stale block/entity NBT and active scripts.
- When Carry On tries to place a carried player but `getFirstPassenger()` is already null, the stale carry state is cleared and the placement action is canceled.

It does not change Carry On pickup eligibility, placement rules, stacking, or CarryOnExtend throwing.
