# Better Engines NeoForge Fix

Tiny NeoForge compatibility patch for Immersive Aircraft: Better Engines 3.0.2.

## Why

Better Engines ships recipes for `more_engines:compressed_fuel` and
`more_engines:dense_fuel`, but its `EngineMod.init()` registers those two items only
when Architectury reports Fabric. NeoForge therefore rejects both recipes because
their result items do not exist.

## Behavior

The patch registers only the two missing items under Better Engines' namespace and
assigns them the burn times used by its Fabric branch: 170,000 ticks for Compressed
Fuel and 1,530,000 ticks for Dense Fuel. Better Engines does not refer to either of
its unbound static fields outside that branch, so the mod's own recipes and assets
work normally once the item IDs exist.

## Build

First materialize a server runtime so the compile classpath exists:

```bash
go-task pack:inspect INSPECT=server-generated
```

Then build all local compatibility jars:

```bash
go-task local-mods:build
```

The jar is written to:

```text
mods/better-engines-neoforge-fix-1.0.0+mc1.21.1-neoforge.jar
```
