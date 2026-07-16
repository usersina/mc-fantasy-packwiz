package io.github.usersina.mcfantasy.fantasybloodcompat.mixin;

import io.redspace.ironsspellbooks.block.alchemist_cauldron.AlchemistCauldronTile;
import net.minecraft.core.HolderLookup;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.tags.TagKey;
import net.minecraft.world.level.material.Fluid;
import net.neoforged.neoforge.fluids.FluidStack;
import net.neoforged.neoforge.fluids.IFluidTank;
import net.neoforged.neoforge.fluids.capability.IFluidHandler;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(value = AlchemistCauldronTile.AlchemistCauldronFluidHandler.class, remap = false)
public abstract class AlchemistCauldronFluidHandlerMixin {
    private static final TagKey<Fluid> CLEAN_BLOOD = TagKey.create(
            Registries.FLUID,
            ResourceLocation.fromNamespaceAndPath("fantasy_pack", "clean_blood")
    );

    @Shadow
    IFluidTank[] tanks;

    @Shadow
    public abstract int fluidAmount();

    @Inject(
            method = "fill(Lnet/neoforged/neoforge/fluids/FluidStack;Lnet/neoforged/neoforge/fluids/capability/IFluidHandler$FluidAction;)I",
            at = @At("HEAD"),
            cancellable = true,
            remap = false
    )
    private void fantasyPack$mergeCleanBlood(
            FluidStack resource,
            IFluidHandler.FluidAction action,
            CallbackInfoReturnable<Integer> cir
    ) {
        if (resource.isEmpty() || !resource.is(CLEAN_BLOOD)) {
            return;
        }

        IFluidTank cleanTank = null;
        for (IFluidTank tank : tanks) {
            if (!tank.getFluid().isEmpty() && tank.getFluid().is(CLEAN_BLOOD)) {
                cleanTank = tank;
                break;
            }
        }

        if (cleanTank == null
                || FluidStack.isSameFluidSameComponents(cleanTank.getFluid(), resource)) {
            return;
        }

        int accepted = Math.min(resource.getAmount(), 1000 - fluidAmount());
        if (accepted <= 0) {
            cir.setReturnValue(0);
            return;
        }

        cir.setReturnValue(cleanTank.fill(cleanTank.getFluid().copyWithAmount(accepted), action));
    }

    @Inject(
            method = "load",
            at = @At("TAIL"),
            remap = false
    )
    private void fantasyPack$consolidateSavedCleanBlood(
            String key,
            CompoundTag tag,
            HolderLookup.Provider provider,
            CallbackInfo ci
    ) {
        IFluidTank first = null;
        FluidStack canonical = FluidStack.EMPTY;
        int total = 0;
        int count = 0;

        for (IFluidTank tank : tanks) {
            FluidStack stored = tank.getFluid();
            if (stored.isEmpty() || !stored.is(CLEAN_BLOOD)) {
                continue;
            }
            if (first == null) {
                first = tank;
                canonical = stored.copy();
            }
            total += stored.getAmount();
            count++;
        }

        if (first == null || count < 2) {
            return;
        }

        for (IFluidTank tank : tanks) {
            if (tank.getFluid().is(CLEAN_BLOOD)) {
                tank.drain(tank.getCapacity(), IFluidHandler.FluidAction.EXECUTE);
            }
        }
        first.fill(canonical.copyWithAmount(total), IFluidHandler.FluidAction.EXECUTE);
    }
}
