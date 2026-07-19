package io.github.usersina.mcfantasy.carryonplayersyncfix.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.NbtOps;
import net.minecraft.nbt.Tag;
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
    private void fantasyPack$createDetachedSnapshot(CallbackInfoReturnable<CompoundTag> cir) {
        CompoundTag snapshot = nbt.copy();
        snapshot.putString("type", type.toString());
        snapshot.putBoolean("keyPressed", keyPressed);

        if (activeScript != null) {
            Tag encodedScript = CarryOnScript.CODEC
                    .encodeStart(NbtOps.INSTANCE, activeScript)
                    .getOrThrow(message -> new RuntimeException("Failed encoding Carry On script: " + message));
            snapshot.put("activeScript", encodedScript);
        } else {
            snapshot.remove("activeScript");
        }

        snapshot.putInt("selected", selectedSlot);
        cir.setReturnValue(snapshot);
    }

    private void fantasyPack$sanitizePlayerCarryData() {
        nbt = new CompoundTag();
        activeScript = null;
    }
}
