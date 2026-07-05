package io.github.usersina.mcfantasy.vampirecauldronbloodfix;

import de.teamlapen.vampirism.entity.player.vampire.VampirePlayer;
import io.redspace.ironsspellbooks.damage.ISSDamageTypes;
import net.minecraft.world.entity.player.Player;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.entity.living.LivingIncomingDamageEvent;

@Mod(VampireCauldronBloodFix.MOD_ID)
public final class VampireCauldronBloodFix {
    public static final String MOD_ID = "vampire_cauldron_blood_fix";

    public VampireCauldronBloodFix(IEventBus modEventBus) {
        NeoForge.EVENT_BUS.register(this);
    }

    @SubscribeEvent
    public void onIncomingDamage(LivingIncomingDamageEvent event) {
        if (!(event.getEntity() instanceof Player player) || player.level().isClientSide()) {
            return;
        }

        if (!event.getSource().is(ISSDamageTypes.CAULDRON)) {
            return;
        }

        if (VampirePlayer.get(player).getLevel() <= 0) {
            return;
        }

        event.setCanceled(true);
    }
}
