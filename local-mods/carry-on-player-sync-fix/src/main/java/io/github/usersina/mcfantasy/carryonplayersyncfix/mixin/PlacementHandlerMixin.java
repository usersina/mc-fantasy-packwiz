package io.github.usersina.mcfantasy.carryonplayersyncfix.mixin;

import java.util.function.BiFunction;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.phys.Vec3;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
import tschipp.carryon.common.carry.CarryOnData;
import tschipp.carryon.common.carry.CarryOnDataManager;
import tschipp.carryon.common.carry.PlacementHandler;

@Mixin(value = PlacementHandler.class, remap = false)
public abstract class PlacementHandlerMixin {
    @Inject(method = "tryPlaceEntity", at = @At("HEAD"), cancellable = true, remap = false)
    private static void fantasyPack$clearStalePlayerCarryWithoutPassenger(
            ServerPlayer player,
            BlockPos pos,
            Direction facing,
            BiFunction<Vec3, Entity, Boolean> placementCallback,
            CallbackInfoReturnable<Boolean> cir
    ) {
        CarryOnData carry = CarryOnDataManager.getCarryData(player);
        if (!carry.isCarrying(CarryOnData.CarryType.PLAYER)) {
            return;
        }

        if (player.getFirstPassenger() != null) {
            return;
        }

        carry.clear();
        CarryOnDataManager.setCarryData(player, carry);
        cir.setReturnValue(false);
    }
}
