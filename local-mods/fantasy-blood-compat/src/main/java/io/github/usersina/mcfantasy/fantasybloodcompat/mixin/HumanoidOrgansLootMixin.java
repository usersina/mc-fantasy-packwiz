package io.github.usersina.mcfantasy.fantasybloodcompat.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.Constant;
import org.spongepowered.asm.mixin.injection.ModifyConstant;

@Mixin(
        targets = {
                "net.mcreator.butchery.procedures.VillagercutupProcedure",
                "net.mcreator.butchery.procedures.HangingvillagercutupProcedure",
                "net.mcreator.butchery.procedures.PillagercorpsecutupProcedure",
                "net.mcreator.butchery.procedures.HangingPillagercorpsecutupProcedure",
                "net.mcreator.butchery.procedures.VindicatorcorpsecutupProcedure",
                "net.mcreator.butchery.procedures.HangingvindicatorcorpsecutupProcedure",
                "net.mcreator.butchery.procedures.EvokercutupProcedure",
                "net.mcreator.butchery.procedures.HangingevokercutupProcedure",
                "net.mcreator.butchery.procedures.WitchCutUpProcedure",
                "net.mcreator.butchery.procedures.HangingwitchcutupProcedure"
        },
        remap = false
)
public abstract class HumanoidOrgansLootMixin {
    @ModifyConstant(
            method = "execute(Lnet/neoforged/bus/api/Event;Lnet/minecraft/world/level/LevelAccessor;DDDLnet/minecraft/world/entity/Entity;)V",
            constant = @Constant(stringValue = "butchery:blocks/organs_drop_1"),
            require = 4,
            remap = false
    )
    private static String fantasyPack$useHumanoidOrgans(String original) {
        return "fantasy_blood_compat:blocks/humanoid_organs_drop_1";
    }
}
