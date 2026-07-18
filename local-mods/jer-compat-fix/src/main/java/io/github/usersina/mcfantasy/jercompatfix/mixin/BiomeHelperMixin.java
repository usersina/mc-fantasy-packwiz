package io.github.usersina.mcfantasy.jercompatfix.mixin;

import jeresources.compatibility.CompatBase;
import net.minecraft.core.HolderLookup;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

@Mixin(targets = "jeresources.api.util.BiomeHelper", remap = false)
public abstract class BiomeHelperMixin {
    @Redirect(
            method = {"getAllBiomes", "getBiome", "getBiomes"},
            at = @At(
                    value = "INVOKE",
                    target = "Lnet/minecraft/data/registries/VanillaRegistries;createLookup()Lnet/minecraft/core/HolderLookup$Provider;"
            ),
            remap = false
    )
    private static HolderLookup.Provider fantasyPack$useActiveBiomeRegistry() {
        return CompatBase.getLevel().registryAccess();
    }
}
