# Fish of Thieves Bait Save Fix

This local NeoForge compatibility mod prevents Fish of Thieves `21.1.2.1`
from crashing a server save with:

```text
java.lang.IllegalStateException: Cannot encode empty ItemStack
```

Fish of Thieves preserves attached fishing-hook bait in world saved data. Its
1.21.1 implementation can add `ItemStack.EMPTY` when an unbaited hook is saved,
then passes that empty stack to `ItemStack.save` during the next autosave.

The patch:

- rejects empty bait before Fish of Thieves inserts it into preserved storage
- removes malformed empty entries after loading old data
- sanitizes preserved storage before bait restoration and every saved-data write
- leaves valid attached bait and the rest of Fish of Thieves unchanged

The dependency range intentionally targets only Fish of Thieves `21.1.2.1`.
Review or remove this patch before updating that mod.

Build it after materializing the server runtime:

```bash
go-task pack:inspect INSPECT=server-generated
go-task local-mods:build
```

Run its focused regression suite with:

```bash
go-task pack:test TEST=fish-of-thieves
```
