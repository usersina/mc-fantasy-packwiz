package io.github.usersina.mcfantasy.butcherybloodgratefix.mixin;

import net.mcreator.butchery.block.BloodgrateBlock;
import net.mcreator.butchery.init.ButcheryModBlocks;
import net.mcreator.butchery.procedures.BloodgratewithdrawbloodProcedure;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.state.BlockState;
import net.neoforged.bus.api.Event;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(value = BloodgratewithdrawbloodProcedure.class, remap = false)
public abstract class BloodGrateWithdrawMixin {
    @Inject(
            method = "execute(Lnet/neoforged/bus/api/Event;Lnet/minecraft/world/level/LevelAccessor;DDDLnet/minecraft/world/level/block/state/BlockState;Lnet/minecraft/world/entity/Entity;)V",
            at = @At("HEAD"),
            cancellable = true,
            remap = false
    )
    private static void fantasyPack$requireVampirismPurification(
            Event event,
            LevelAccessor world,
            double x,
            double y,
            double z,
            BlockState blockState,
            Entity entity,
            CallbackInfo ci
    ) {
        if (!(entity instanceof LivingEntity living)
                || living.getMainHandItem().getItem() != Items.GLASS_BOTTLE
                || blockState.getBlock() != ButcheryModBlocks.BLOOD_GRATE.get()
                || blockState.getValue(BloodgrateBlock.BLOCKSTATE) != 3) {
            return;
        }

        ci.cancel();
        if (!world.isClientSide() && entity instanceof Player player) {
            player.displayClientMessage(
                    Component.literal("Impure blood must be purified with a Blood Sieve before bottling."),
                    true
            );
        }
    }
}
