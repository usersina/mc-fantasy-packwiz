package io.github.usersina.mcfantasy.butcherybloodgratefix.mixin;

import net.mcreator.butchery.block.BloodgrateBlock;
import net.mcreator.butchery.block.entity.BloodgrateBlockEntity;
import net.mcreator.butchery.init.ButcheryModBlocks;
import net.mcreator.butchery.init.ButcheryModItems;
import net.mcreator.butchery.procedures.BloodgratechangeProcedure;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.neoforged.bus.api.Event;
import net.neoforged.neoforge.fluids.FluidStack;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(value = BloodgratechangeProcedure.class, remap = false)
public abstract class BloodGrateChangeMixin {
    @Inject(
            method = "execute(Lnet/neoforged/bus/api/Event;Lnet/minecraft/world/level/LevelAccessor;DDDLnet/minecraft/world/level/block/state/BlockState;Lnet/minecraft/world/entity/Entity;)V",
            at = @At("HEAD"),
            cancellable = true,
            remap = false
    )
    private static void fantasyPack$switchSupportedBloodMode(
            Event event,
            LevelAccessor world,
            double x,
            double y,
            double z,
            BlockState blockState,
            Entity entity,
            CallbackInfo ci
    ) {
        if (entity == null || entity.isShiftKeyDown()) {
            return;
        }

        if (!(entity instanceof LivingEntity living)
                || living.getMainHandItem().getItem() != ButcheryModItems.BUTCHERS_PAPERS.get()
                || blockState.getBlock() != ButcheryModBlocks.BLOOD_GRATE.get()) {
            return;
        }

        BlockPos pos = BlockPos.containing(x, y, z);
        BlockEntity blockEntity = world.getBlockEntity(pos);
        if (!(blockEntity instanceof BloodgrateBlockEntity grate)) {
            return;
        }

        if (blockEntity.getPersistentData().getBoolean("isInfectedBlood")) {
            return;
        }

        if (grate.getFluidTank().getFluidAmount() > 0) {
            ci.cancel();
            if (!world.isClientSide() && entity instanceof Player player) {
                player.displayClientMessage(
                        Component.literal("Empty the Blood Grate before changing modes."),
                        true
                );
            }
            return;
        }

        ci.cancel();
        if (world.isClientSide()) {
            return;
        }

        int currentMode = blockState.getValue(BloodgrateBlock.BLOCKSTATE);
        int nextMode = currentMode == 0 ? 3 : 0;

        grate.getFluidTank().setFluid(FluidStack.EMPTY);

        blockEntity.getPersistentData().putBoolean("isButchery", nextMode == 0);
        blockEntity.getPersistentData().putBoolean("isVampirism", nextMode == 3);
        blockEntity.getPersistentData().putBoolean("isBloodMagic", false);
        blockEntity.getPersistentData().putBoolean("isHexeri", false);

        BlockState nextState = blockState.setValue(BloodgrateBlock.BLOCKSTATE, nextMode);
        world.setBlock(pos, nextState, 3);
        grate.setChanged();

        if (world instanceof Level level) {
            level.sendBlockUpdated(pos, nextState, nextState, 3);
            level.playSound(null, pos, SoundEvents.ANVIL_LAND, SoundSource.NEUTRAL, 1.0F, 1.0F);
        }

        living.swing(InteractionHand.MAIN_HAND, true);
        if (entity instanceof Player player) {
            String modeName = nextMode == 3 ? "Vampirism" : "Butchery";
            player.displayClientMessage(Component.literal("Set to " + modeName), true);
        }
    }
}
