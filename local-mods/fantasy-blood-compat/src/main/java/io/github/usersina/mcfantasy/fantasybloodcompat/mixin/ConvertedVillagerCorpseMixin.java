package io.github.usersina.mcfantasy.fantasybloodcompat.mixin;

import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.tags.TagKey;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.level.LevelAccessor;
import net.neoforged.bus.api.Event;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(targets = "net.mcreator.butchery.procedures.VillagercorpsedropProcedure", remap = false)
public abstract class ConvertedVillagerCorpseMixin {
    private static final TagKey<EntityType<?>> ZOMBIE_VILLAGERS = TagKey.create(
            Registries.ENTITY_TYPE,
            ResourceLocation.fromNamespaceAndPath("c", "zombie_villager")
    );

    @Inject(
            method = "execute(Lnet/neoforged/bus/api/Event;Lnet/minecraft/world/level/LevelAccessor;DDDLnet/minecraft/world/entity/Entity;Lnet/minecraft/world/entity/Entity;)V",
            at = @At("HEAD"),
            cancellable = true,
            remap = false
    )
    private static void fantasyPack$skipZombieVillagers(
            Event event,
            LevelAccessor level,
            double x,
            double y,
            double z,
            Entity victim,
            Entity attacker,
            CallbackInfo ci
    ) {
        if (victim != null && victim.getType().is(ZOMBIE_VILLAGERS)) {
            ci.cancel();
        }
    }
}
