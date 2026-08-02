package io.github.usersina.mcfantasy.fantasybloodcompat.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.Constant;
import org.spongepowered.asm.mixin.injection.ModifyConstant;

@Mixin(
        targets = {
                "net.mcreator.butchery.procedures.PlayercutupProcedure",
                "net.mcreator.butchery.procedures.HangingplayercutupProcedure"
        },
        remap = false
)
public abstract class PlayerOrgansLootMixin {
    @ModifyConstant(
            method = "execute(Lnet/neoforged/bus/api/Event;Lnet/minecraft/world/level/LevelAccessor;DDDLnet/minecraft/world/entity/Entity;)V",
            constant = @Constant(stringValue = "butchery:blocks/player_heart_drop"),
            require = 4,
            remap = false
    )
    private static String fantasyPack$useHumanPlayerOrgans(String original) {
        return "fantasy_blood_compat:blocks/player_human_organs";
    }
}
