package io.github.usersina.mcfantasy.ironsspellbooksyncfix;

import io.redspace.ironsspellbooks.api.util.Utils;
import io.redspace.ironsspellbooks.player.ClientMagicData;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.client.event.ClientPlayerNetworkEvent;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.PlayerTickEvent;

@Mod(value = IronsSpellbookSyncFix.MOD_ID, dist = Dist.CLIENT)
public final class IronsSpellbookSyncFix {
    public static final String MOD_ID = "irons_spellbook_sync_fix";

    private Player observedPlayer;
    private ItemStack observedSpellbook = ItemStack.EMPTY;

    public IronsSpellbookSyncFix(IEventBus modEventBus) {
        NeoForge.EVENT_BUS.register(this);
    }

    @SubscribeEvent
    public void onPlayerTick(PlayerTickEvent.Post event) {
        Player player = event.getEntity();
        if (!player.isLocalPlayer()) {
            return;
        }

        ItemStack equippedSpellbook = Utils.getPlayerSpellbookStack(player);
        ItemStack currentSpellbook = equippedSpellbook == null ? ItemStack.EMPTY : equippedSpellbook;
        if (player == observedPlayer && ItemStack.matches(observedSpellbook, currentSpellbook)) {
            return;
        }

        observedPlayer = player;
        observedSpellbook = currentSpellbook.copy();
        ClientMagicData.updateSpellSelectionManager();
    }

    @SubscribeEvent
    public void onPlayerLogout(ClientPlayerNetworkEvent.LoggingOut event) {
        observedPlayer = null;
        observedSpellbook = ItemStack.EMPTY;
    }
}
