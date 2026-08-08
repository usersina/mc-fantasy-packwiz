# Printing Press Compat

Tiny pack-local compatibility mod for Glowbrick's Printing Press 1.0.1:

- Allows explicitly tagged custom books to be captured by the Typesetter and
  reproduced by the Printing Press without losing their data components.
- Returns the press's internal ink as bottles when the block is destroyed.
- Gives the Printing Press and Typesetter normal workstation durability instead
  of the upstream instant-break hardness.

## Custom books

Supported custom books are controlled by the item tag:

```text
printing_press_compat:copyable_books
```

The pack initially includes only `vampirism:vampire_book`. The allowlist is
deliberately narrow so equipment such as Iron's spellbooks cannot be duplicated.

The Typesetter stores an exact one-item copy inside the resulting Type Block.
Printing consumes one vanilla Book and a full 1000-unit tank, equal to five Magic
Ink Bottles. The source book and Type Block are retained, matching the upstream
enchanted-book workflow.

Vanilla enchanted books retain the upstream 200-unit ink cost.

## Ink recovery

Printing Press ink is stored in 200-unit increments. Destroying a press returns
one matching Ink Bottle or Magic Ink Bottle per 200 units, then clears the
internal tank to prevent duplicate drops.

## Workstation durability

The Printing Press and Typesetter use hardness `2.5` and blast resistance `6`.
They do not require a particular tool, so breaking either block still returns it.
