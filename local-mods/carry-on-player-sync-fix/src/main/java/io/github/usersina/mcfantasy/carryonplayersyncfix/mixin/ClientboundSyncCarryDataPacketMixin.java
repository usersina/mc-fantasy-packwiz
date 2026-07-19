package io.github.usersina.mcfantasy.carryonplayersyncfix.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyVariable;

import tschipp.carryon.common.carry.CarryOnData;
import tschipp.carryon.networking.clientbound.ClientboundSyncCarryDataPacket;

@Mixin(value = ClientboundSyncCarryDataPacket.class, remap = false)
public abstract class ClientboundSyncCarryDataPacketMixin {
    @ModifyVariable(method = "<init>", at = @At("HEAD"), argsOnly = true, index = 2, remap = false)
    private static CarryOnData fantasyPack$freezeCarryData(CarryOnData data) {
        return new CarryOnData(data.getNbt());
    }
}
