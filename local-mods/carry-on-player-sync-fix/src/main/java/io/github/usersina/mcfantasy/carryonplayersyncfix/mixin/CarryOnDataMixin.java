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
    private void fantasyPack$sanitizeBeforeEncoding(CallbackInfoReturnable<CompoundTag> cir) {
        if (type == CarryOnData.CarryType.PLAYER) {
            fantasyPack$sanitizePlayerCarryData();
            cir.setReturnValue(fantasyPack$metadataOnlyTag(CarryOnData.CarryType.PLAYER));
            return;
        }

        CompoundTag wireTag = fantasyPack$copySafely(nbt);
        if (wireTag == null) {
            nbt = new CompoundTag();
            activeScript = null;
            type = CarryOnData.CarryType.INVALID;
            cir.setReturnValue(fantasyPack$metadataOnlyTag(CarryOnData.CarryType.INVALID));
            return;
        }

        CarryOnData.CarryType wireType = type == null ? CarryOnData.CarryType.INVALID : type;
        fantasyPack$putMetadata(wireTag, wireType);
        fantasyPack$putActiveScript(wireTag);
        cir.setReturnValue(wireTag);
    }

    private void fantasyPack$sanitizePlayerCarryData() {
        nbt = new CompoundTag();
        activeScript = null;
    }

    private CompoundTag fantasyPack$metadataOnlyTag(CarryOnData.CarryType wireType) {
        CompoundTag tag = new CompoundTag();
        fantasyPack$putMetadata(tag, wireType);
        return tag;
    }

    private CompoundTag fantasyPack$copySafely(CompoundTag source) {
        if (source == null) {
            return new CompoundTag();
        }

        try {
            return source.copy();
        } catch (Throwable ignored) {
            return null;
        }
    }

    private void fantasyPack$putMetadata(CompoundTag tag, CarryOnData.CarryType wireType) {
        tag.putString("type", wireType.toString());
        tag.putBoolean("keyPressed", keyPressed);
        tag.putInt("selected", selectedSlot);

        Integer tick = fantasyPack$getIntSafely(nbt, "tick");
        if (tick != null) {
            tag.putInt("tick", tick);
        }
    }

    private Integer fantasyPack$getIntSafely(CompoundTag tag, String key) {
        if (tag == null) {
            return null;
        }

        try {
            return tag.contains(key) ? tag.getInt(key) : null;
        } catch (Throwable ignored) {
            return null;
        }
    }

    private void fantasyPack$putActiveScript(CompoundTag tag) {
        if (activeScript == null) {
            return;
        }

        try {
            Tag activeScriptTag = (Tag) CarryOnScript.CODEC
                    .encodeStart(NbtOps.INSTANCE, activeScript)
                    .getOrThrow(RuntimeException::new);
            tag.put("activeScript", activeScriptTag);
        } catch (Throwable ignored) {
            activeScript = null;
        }
    }
}
