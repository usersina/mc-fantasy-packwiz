package io.github.usersina.mcfantasy.fishofthievesbaitfix.mixin;

import com.stevekung.fishofthieves.storage.BaitPreserveSavedData;
import io.github.usersina.mcfantasy.fishofthievesbaitfix.EmptySafeBaitStorage;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.world.level.Level;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.Vec3;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Mutable;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import java.util.Map;

@Mixin(value = BaitPreserveSavedData.class, remap = false)
public abstract class BaitPreserveSavedDataMixin {
    @Shadow
    @Final
    @Mutable
    private Map<Vec3, ItemStack> baitStorage;

    @Inject(method = "<init>(Ljava/util/Map;)V", at = @At("RETURN"), remap = false)
    private void fantasyPack$rejectEmptyBaitAtStorageBoundary(
            Map<Vec3, ItemStack> initialStorage,
            CallbackInfo ci
    ) {
        baitStorage = new EmptySafeBaitStorage(initialStorage);
    }

    @Inject(method = "load", at = @At("RETURN"), remap = false)
    private static void fantasyPack$discardEmptyLoadedBait(
            CompoundTag tag,
            HolderLookup.Provider registries,
            CallbackInfoReturnable<BaitPreserveSavedData> cir
    ) {
        sanitize(cir.getReturnValue());
    }

    @Inject(method = "spawnBaitOnLoad", at = @At("HEAD"), remap = false)
    private void fantasyPack$discardEmptyBaitBeforeSpawning(Level level, CallbackInfo ci) {
        sanitize((BaitPreserveSavedData) (Object) this);
    }

    @Inject(method = "save", at = @At("HEAD"), remap = false)
    private void fantasyPack$discardEmptyBaitBeforeSaving(
            CompoundTag tag,
            HolderLookup.Provider registries,
            CallbackInfoReturnable<CompoundTag> cir
    ) {
        sanitize((BaitPreserveSavedData) (Object) this);
    }

    private static void sanitize(BaitPreserveSavedData data) {
        if (data == null) {
            return;
        }

        boolean removed = data.getBaitStorage().entrySet().removeIf(entry ->
                entry.getValue() == null || entry.getValue().isEmpty()
        );
        if (removed) {
            data.setDirty();
        }
    }
}
