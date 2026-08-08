package io.github.usersina.mcfantasy.fishofthievesbaitfix;

import com.stevekung.fishofthieves.storage.BaitPreserveSavedData;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;

@Mod(FishOfThievesBaitFix.MOD_ID)
public final class FishOfThievesBaitFix {
    public static final String MOD_ID = "fish_of_thieves_bait_fix";

    public FishOfThievesBaitFix(IEventBus modEventBus) {
        BaitPreserveSavedData.class.getName();
    }
}
