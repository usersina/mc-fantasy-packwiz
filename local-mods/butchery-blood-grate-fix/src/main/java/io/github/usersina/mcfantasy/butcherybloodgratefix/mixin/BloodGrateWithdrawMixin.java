package io.github.usersina.mcfantasy.butcherybloodgratefix.mixin;

import net.mcreator.butchery.block.BloodgrateBlock;
import net.mcreator.butchery.block.entity.BloodgrateBlockEntity;
import net.mcreator.butchery.init.ButcheryModBlocks;
import net.mcreator.butchery.procedures.BloodgratewithdrawbloodProcedure;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.material.Fluid;
import net.neoforged.bus.api.Event;
import net.neoforged.neoforge.fluids.FluidStack;
import net.neoforged.neoforge.fluids.capability.IFluidHandler;
import net.neoforged.neoforge.items.ItemHandlerHelper;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(value = BloodgratewithdrawbloodProcedure.class, remap = false)
public abstract class BloodGrateWithdrawMixin {
    private static final ResourceLocation VAMPIRISM_IMPURE_BLOOD =
            ResourceLocation.parse("vampirism:impure_blood");
    private static final ResourceLocation VAMPIRISM_IMPURE_BLOOD_BUCKET =
            ResourceLocation.parse("vampirism:impure_blood_bucket");

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
        if (!(entity instanceof Player player)
                || blockState.getBlock() != ButcheryModBlocks.BLOOD_GRATE.get()
                || blockState.getValue(BloodgrateBlock.BLOCKSTATE) != 3) {
            return;
        }

        ItemStack heldItem = player.getMainHandItem();
        if (heldItem.getItem() == Items.BUCKET) {
            fantasyPack$fillImpureBloodBucket(world, x, y, z, player, heldItem, ci);
            return;
        }

        if (heldItem.getItem() != Items.GLASS_BOTTLE) {
            return;
        }

        ci.cancel();
        if (!world.isClientSide()) {
            player.displayClientMessage(
                    Component.literal("Impure blood must be purified with a Blood Sieve before bottling."),
                    true
            );
        }
    }

    private static void fantasyPack$fillImpureBloodBucket(
            LevelAccessor world,
            double x,
            double y,
            double z,
            Player player,
            ItemStack heldItem,
            CallbackInfo ci
    ) {
        ci.cancel();
        if (world.isClientSide()) {
            return;
        }

        BlockPos pos = BlockPos.containing(x, y, z);
        if (!(world.getBlockEntity(pos) instanceof BloodgrateBlockEntity grate)) {
            return;
        }

        Fluid impureBlood = BuiltInRegistries.FLUID.get(VAMPIRISM_IMPURE_BLOOD);
        FluidStack requested = new FluidStack(impureBlood, 1000);
        FluidStack available = grate.getFluidTank().drain(
                requested,
                IFluidHandler.FluidAction.SIMULATE
        );
        if (available.getAmount() != 1000) {
            return;
        }

        Item bucketItem = BuiltInRegistries.ITEM.get(VAMPIRISM_IMPURE_BLOOD_BUCKET);
        if (bucketItem == Items.AIR) {
            return;
        }

        grate.getFluidTank().drain(requested, IFluidHandler.FluidAction.EXECUTE);
        grate.setChanged();

        if (!player.getAbilities().instabuild) {
            heldItem.shrink(1);
        }
        ItemHandlerHelper.giveItemToPlayer(player, new ItemStack(bucketItem));
        player.swing(InteractionHand.MAIN_HAND, true);

        if (world instanceof Level level) {
            BlockState state = level.getBlockState(pos);
            level.sendBlockUpdated(pos, state, state, 3);
            level.playSound(null, pos, SoundEvents.BUCKET_FILL, SoundSource.NEUTRAL, 1.0F, 1.0F);
        }
    }
}
