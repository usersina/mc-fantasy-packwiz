package io.github.usersina.mcfantasy.printingpresscompat.mixin;

import com.glowbrick.printingpress.block.ModBlocks;
import net.minecraft.world.level.block.state.BlockBehaviour;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

@Mixin(value = ModBlocks.class, remap = false)
public abstract class ModBlocksMixin {
    private static final float WORKSTATION_HARDNESS = 2.5F;
    private static final float WORKSTATION_RESISTANCE = 6.0F;

    @Redirect(
            method = {"lambda$static$0", "lambda$static$1"},
            at = @At(
                    value = "INVOKE",
                    target = "Lnet/minecraft/world/level/block/state/BlockBehaviour$Properties;of()Lnet/minecraft/world/level/block/state/BlockBehaviour$Properties;"
            ),
            remap = false
    )
    private static BlockBehaviour.Properties fantasyPack$durableWorkstationProperties() {
        return BlockBehaviour.Properties.of().strength(WORKSTATION_HARDNESS, WORKSTATION_RESISTANCE);
    }
}
