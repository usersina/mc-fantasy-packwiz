package io.github.usersina.mcfantasy.betterenginesneoforgefix;

import net.neoforged.bus.api.IEventBus;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.furnace.FurnaceFuelBurnTimeEvent;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;
import net.minecraft.world.item.Item;

@Mod(BetterEnginesNeoForgeFix.MOD_ID)
public final class BetterEnginesNeoForgeFix {
    public static final String MOD_ID = "better_engines_neoforge_fix";
    private static final DeferredRegister.Items ITEMS = DeferredRegister.createItems("more_engines");
    private static final DeferredItem<Item> COMPRESSED_FUEL = ITEMS.registerSimpleItem("compressed_fuel");
    private static final DeferredItem<Item> DENSE_FUEL = ITEMS.registerSimpleItem("dense_fuel");

    public BetterEnginesNeoForgeFix(IEventBus modEventBus) {
        ITEMS.register(modEventBus);
        NeoForge.EVENT_BUS.register(this);
    }

    @SubscribeEvent
    public void onFurnaceFuelBurnTime(FurnaceFuelBurnTimeEvent event) {
        Item fuel = event.getItemStack().getItem();
        if (fuel == COMPRESSED_FUEL.get()) {
            event.setBurnTime(170000);
        } else if (fuel == DENSE_FUEL.get()) {
            event.setBurnTime(1530000);
        }
    }
}
