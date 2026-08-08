package io.github.usersina.mcfantasy.printingpresscompat;

import com.glowbrick.printingpress.block.entity.block.PrintingPressBlockEntity;
import com.glowbrick.printingpress.block.entity.block.TypesetterBlockEntity;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;

@Mod(PrintingPressCompat.MOD_ID)
public final class PrintingPressCompat {
    public static final String MOD_ID = "printing_press_compat";

    public PrintingPressCompat(IEventBus modEventBus) {
        verifyMixinTarget(PrintingPressBlockEntity.class);
        verifyMixinTarget(TypesetterBlockEntity.class);
    }

    private static void verifyMixinTarget(Class<?> target) {
        target.getName();
    }
}
