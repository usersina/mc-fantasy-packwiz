package io.github.usersina.mcfantasy.vampireplayerbitefix.mixin;

import de.teamlapen.vampirism.api.entity.player.vampire.IVampirePlayer;
import de.teamlapen.vampirism.entity.player.vampire.VampirePlayer;
import de.teamlapen.vampirism.util.Helper;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(value = VampirePlayer.class, remap = false)
public abstract class VampirePlayerMixin {
    @Inject(method = "determineBiteType", at = @At("RETURN"), cancellable = true, remap = false)
    private void fantasyPack$blockVampirePlayerBloodFeeding(
            LivingEntity target,
            CallbackInfoReturnable<IVampirePlayer.BITE_TYPE> cir
    ) {
        if (cir.getReturnValue() != IVampirePlayer.BITE_TYPE.SUCK_BLOOD_PLAYER) {
            return;
        }

        if (target instanceof Player targetPlayer && Helper.isVampire(targetPlayer)) {
            cir.setReturnValue(IVampirePlayer.BITE_TYPE.NONE);
        }
    }
}
