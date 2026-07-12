package io.github.usersina.mcfantasy.butcherybloodgratefix.mixin;

import net.mcreator.butchery.block.BloodgrateBlock;
import net.mcreator.butchery.init.ButcheryModBlocks;
import net.mcreator.butchery.init.ButcheryModFluids;
import net.mcreator.butchery.procedures.SmallfillbloodgrateProcedure;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.material.Fluid;
import net.neoforged.neoforge.capabilities.Capabilities;
import net.neoforged.neoforge.common.extensions.ILevelExtension;
import net.neoforged.neoforge.fluids.FluidStack;
import net.neoforged.neoforge.fluids.capability.IFluidHandler;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(value = SmallfillbloodgrateProcedure.class, remap = false)
public abstract class SmallFillBloodGrateMixin {
    private static final ResourceLocation VAMPIRISM_BLOOD = ResourceLocation.parse("vampirism:impure_blood");

    @Inject(method = "execute", at = @At("HEAD"), cancellable = true, remap = false)
    private static void fantasyPack$fillSelectedBloodMode(
            LevelAccessor world,
            double x,
            double y,
            double z,
            CallbackInfo ci
    ) {
        ci.cancel();

        for (int offset = 1; offset <= 5; offset++) {
            BlockPos pos = BlockPos.containing(x, y - offset, z);
            BlockState state = world.getBlockState(pos);
            if (state.getBlock() != ButcheryModBlocks.BLOOD_GRATE.get()) {
                continue;
            }

            int mode = state.getValue(BloodgrateBlock.BLOCKSTATE);
            Fluid fluid;
            if (mode == 0) {
                fluid = ButcheryModFluids.BLOOD.get();
            } else if (mode == 3) {
                fluid = BuiltInRegistries.FLUID.get(VAMPIRISM_BLOOD);
            } else {
                return;
            }

            if (world instanceof ILevelExtension extension) {
                IFluidHandler handler = extension.getCapability(Capabilities.FluidHandler.BLOCK, pos, null);
                if (handler != null) {
                    handler.fill(new FluidStack(fluid, 50), IFluidHandler.FluidAction.EXECUTE);
                }
            }
            return;
        }
    }
}
