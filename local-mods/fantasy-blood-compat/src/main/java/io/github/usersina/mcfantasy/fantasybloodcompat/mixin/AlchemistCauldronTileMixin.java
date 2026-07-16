package io.github.usersina.mcfantasy.fantasybloodcompat.mixin;

import io.redspace.ironsspellbooks.block.alchemist_cauldron.AlchemistCauldronTile;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.tags.TagKey;
import net.minecraft.world.level.material.Fluid;
import net.neoforged.neoforge.fluids.FluidStack;
import net.neoforged.neoforge.fluids.capability.IFluidHandler;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

import java.util.ArrayList;

@Mixin(value = AlchemistCauldronTile.class, remap = false)
public abstract class AlchemistCauldronTileMixin {
    private static final TagKey<Fluid> CLEAN_BLOOD = TagKey.create(
            Registries.FLUID,
            ResourceLocation.fromNamespaceAndPath("fantasy_pack", "clean_blood")
    );

    @Redirect(
            method = "tryMeltInput",
            at = @At(
                    value = "INVOKE",
                    target = "Lio/redspace/ironsspellbooks/block/alchemist_cauldron/AlchemistCauldronTile$AlchemistCauldronFluidHandler;contains(Lnet/neoforged/neoforge/fluids/FluidStack;I)Z",
                    ordinal = 0,
                    remap = false
            ),
            remap = false
    )
    private boolean fantasyPack$containsEquivalentCleanBlood(
            AlchemistCauldronTile.AlchemistCauldronFluidHandler handler,
            FluidStack requested,
            int amount
    ) {
        if (!requested.is(CLEAN_BLOOD)) {
            return handler.contains(requested, amount);
        }

        int available = handler.fluids().stream()
                .filter(stack -> stack.is(CLEAN_BLOOD))
                .mapToInt(FluidStack::getAmount)
                .sum();
        return available >= amount;
    }

    @Redirect(
            method = "tryMeltInput",
            at = @At(
                    value = "INVOKE",
                    target = "Lio/redspace/ironsspellbooks/block/alchemist_cauldron/AlchemistCauldronTile$AlchemistCauldronFluidHandler;drain(Lnet/neoforged/neoforge/fluids/FluidStack;Lnet/neoforged/neoforge/fluids/capability/IFluidHandler$FluidAction;)Lnet/neoforged/neoforge/fluids/FluidStack;",
                    ordinal = 1,
                    remap = false
            ),
            remap = false
    )
    private FluidStack fantasyPack$drainEquivalentCleanBlood(
            AlchemistCauldronTile.AlchemistCauldronFluidHandler handler,
            FluidStack requested,
            IFluidHandler.FluidAction action
    ) {
        if (!requested.is(CLEAN_BLOOD)) {
            return handler.drain(requested, action);
        }

        int remaining = requested.getAmount();
        int drained = 0;
        for (FluidStack stored : new ArrayList<>(handler.fluids())) {
            if (!stored.is(CLEAN_BLOOD) || remaining == 0) {
                continue;
            }
            int portion = Math.min(remaining, stored.getAmount());
            FluidStack result = handler.drain(stored.copyWithAmount(portion), action);
            drained += result.getAmount();
            remaining -= result.getAmount();
        }

        return drained == 0 ? FluidStack.EMPTY : requested.copyWithAmount(drained);
    }
}
