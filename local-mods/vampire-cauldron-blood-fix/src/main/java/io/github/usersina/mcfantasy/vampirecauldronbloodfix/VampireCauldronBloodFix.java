package io.github.usersina.mcfantasy.vampirecauldronbloodfix;

import de.teamlapen.vampirism.entity.player.vampire.VampirePlayer;
import io.redspace.ironsspellbooks.damage.ISSDamageTypes;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.tags.TagKey;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.entity.living.LivingIncomingDamageEvent;

@Mod(VampireCauldronBloodFix.MOD_ID)
public final class VampireCauldronBloodFix {
    public static final String MOD_ID = "vampire_cauldron_blood_fix";
    private static final TagKey<EntityType<?>> CAULDRON_UNDEAD = TagKey.create(
            Registries.ENTITY_TYPE,
            ResourceLocation.fromNamespaceAndPath("fantasy_pack", "cauldron_undead")
    );

    public VampireCauldronBloodFix(IEventBus modEventBus) {
        NeoForge.EVENT_BUS.register(this);
    }

    @SubscribeEvent
    public void onIncomingDamage(LivingIncomingDamageEvent event) {
        LivingEntity entity = event.getEntity();
        if (entity.level().isClientSide()) {
            return;
        }

        if (!event.getSource().is(ISSDamageTypes.CAULDRON)) {
            return;
        }

        boolean vampirePlayer = entity instanceof Player player && VampirePlayer.get(player).getLevel() > 0;
        boolean undead = entity.isInvertedHealAndHarm() || entity.getType().is(CAULDRON_UNDEAD);
        if (!vampirePlayer && !undead) {
            return;
        }

        event.setCanceled(true);
    }
}
