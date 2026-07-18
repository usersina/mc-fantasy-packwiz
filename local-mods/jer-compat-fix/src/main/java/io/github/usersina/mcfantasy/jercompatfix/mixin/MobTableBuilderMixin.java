package io.github.usersina.mcfantasy.jercompatfix.mixin;

import net.minecraft.resources.ResourceKey;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.storage.loot.LootTable;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(targets = "jeresources.util.MobTableBuilder", remap = false)
public abstract class MobTableBuilderMixin {
    @Inject(method = "add", at = @At("HEAD"), cancellable = true, remap = false)
    private void fantasyPack$skipNonLivingEntityTypes(
            ResourceKey<LootTable> lootTable,
            EntityType<?> entityType,
            CallbackInfo ci
    ) {
        if (!LivingEntity.class.isAssignableFrom(entityType.getBaseClass())) {
            ci.cancel();
        }
    }
}
