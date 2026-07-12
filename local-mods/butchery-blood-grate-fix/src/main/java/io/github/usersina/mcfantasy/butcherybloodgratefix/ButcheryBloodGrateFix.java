package io.github.usersina.mcfantasy.butcherybloodgratefix;

import net.mcreator.butchery.procedures.BloodgratechangeProcedure;
import net.mcreator.butchery.procedures.BloodgratewithdrawbloodProcedure;
import net.mcreator.butchery.procedures.SmallfillbloodgrateProcedure;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;

@Mod(ButcheryBloodGrateFix.MOD_ID)
public final class ButcheryBloodGrateFix {
    public static final String MOD_ID = "butchery_blood_grate_fix";

    public ButcheryBloodGrateFix(IEventBus modEventBus) {
        verifyMixinTarget(BloodgratechangeProcedure.class);
        verifyMixinTarget(BloodgratewithdrawbloodProcedure.class);
        verifyMixinTarget(SmallfillbloodgrateProcedure.class);
    }

    private static void verifyMixinTarget(Class<?> target) {
        target.getName();
    }
}
