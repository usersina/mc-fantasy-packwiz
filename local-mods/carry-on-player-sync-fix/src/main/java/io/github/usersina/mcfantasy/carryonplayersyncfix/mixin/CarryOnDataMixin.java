package io.github.usersina.mcfantasy.carryonplayersyncfix.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import net.minecraft.nbt.CompoundTag;
import tschipp.carryon.common.carry.CarryOnData;
import tschipp.carryon.common.scripting.CarryOnScript;

@Mixin(value = CarryOnData.class, remap = false)
public abstract class CarryOnDataMixin {
    @Shadow
    private CarryOnData.CarryType type;

    @Shadow
    private CompoundTag nbt;

    @Shadow
    private boolean keyPressed;

    @Shadow
    private CarryOnScript activeScript;

    @Shadow
    private int selectedSlot;

    @Inject(method = "setCarryingPlayer", at = @At("HEAD"), remap = false)
    private void fantasyPack$clearStaleNbtBeforePlayerCarry(CallbackInfo ci) {
        fantasyPack$sanitizePlayerCarryData();
    }

    @Inject(method = "getNbt", at = @At("HEAD"), cancellable = true, remap = false)
    private void fantasyPack$sanitizeBeforeEncoding(CallbackInfoReturnable<CompoundTag> cir) {
        if (type != CarryOnData.CarryType.PLAYER) {
            return;
        }

        fantasyPack$sanitizePlayerCarryData();
        cir.setReturnValue(fantasyPack$metadataOnlyTag());
    }

    private void fantasyPack$sanitizePlayerCarryData() {
        nbt = new CompoundTag();
        activeScript = null;
    }

    private CompoundTag fantasyPack$metadataOnlyTag() {
        CompoundTag tag = new CompoundTag();
        tag.putString("type", CarryOnData.CarryType.PLAYER.toString());
        tag.putBoolean("keyPressed", keyPressed);
        tag.putInt("selected", selectedSlot);
        return tag;
    }
}
