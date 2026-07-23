package io.github.usersina.mcfantasy.fantasybloodcompat;

import de.teamlapen.vampirism.blockentity.BloodContainerBlockEntity;
import io.redspace.ironsspellbooks.block.alchemist_cauldron.AlchemistCauldronTile;
import io.redspace.ironsspellbooks.recipe_types.alchemist_cauldron.BrewAlchemistCauldronRecipe;
import net.grid.vampiresdelight.common.registry.VDDataComponents;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.food.FoodProperties;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.component.CustomData;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.mcreator.butchery.block.entity.BloodgrateBlockEntity;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.ModifyDefaultComponentsEvent;
import net.neoforged.neoforge.event.entity.player.PlayerInteractEvent;
import net.neoforged.neoforge.fluids.FluidStack;
import net.neoforged.neoforge.fluids.capability.IFluidHandler;

@Mod(FantasyBloodCompat.MOD_ID)
public final class FantasyBloodCompat {
    public static final String MOD_ID = "fantasy_blood_compat";
    private static final ResourceLocation BUTCHERY_SPONGE = ResourceLocation.fromNamespaceAndPath("butchery", "sponge");
    private static final String SPONGE_WETNESS = "spongeWetness";
    private static final int SPONGE_DRAIN_AMOUNT = 1000;

    public FantasyBloodCompat(IEventBus modEventBus) {
        verifyMixinTarget(AlchemistCauldronTile.class);
        verifyMixinTarget(AlchemistCauldronTile.AlchemistCauldronFluidHandler.class);
        verifyMixinTarget(BrewAlchemistCauldronRecipe.class);
        verifyMixinTarget(BloodgrateBlockEntity.class);
        verifyMixinTarget(BloodContainerBlockEntity.class);
        modEventBus.addListener(this::onModifyDefaultComponents);
        NeoForge.EVENT_BUS.register(this);
    }

    private void onModifyDefaultComponents(ModifyDefaultComponentsEvent event) {
        addVampireFood(event, "heart", 5);
        addVampireFood(event, "eye", 2);
        addVampireFood(event, "intestines", 4);
        addVampireFood(event, "kidney", 3);
        addVampireFood(event, "liver", 4);
        addVampireFood(event, "lungs", 4);
        addVampireFood(event, "stomach", 4);
        addVampireFood(event, "flesh", 5);
        addVampireFood(event, "rawhumanmeat", 4);
        addVampireFood(event, "raw_villager_steak", 4);
        addVampireFood(event, "raw_evoker_meat", 3);
        addVampireFood(event, "raw_pillager_meat", 3);
        addVampireFood(event, "raw_vindicator_meat", 3);
        addVampireFood(event, "raw_witch_meat", 5);
        addVampireFood(event, "raw_blood_sausage", 4);
        addVampireFood(event, "cooked_blood_sausage", 4);
    }

    private static void addVampireFood(ModifyDefaultComponentsEvent event, String path, int blood) {
        ResourceLocation id = ResourceLocation.fromNamespaceAndPath("butchery", path);
        Item item = BuiltInRegistries.ITEM.getOptional(id)
                .orElseThrow(() -> new IllegalStateException("Missing required Butchery item: " + id));
        FoodProperties properties = new FoodProperties.Builder()
                .nutrition(blood)
                .saturationModifier(0.1F)
                .build();
        event.modify(item, components -> components.set(VDDataComponents.VAMPIRE_FOOD.value(), properties));
    }

    @SubscribeEvent
    public void onRightClickBlock(PlayerInteractEvent.RightClickBlock event) {
        ItemStack sponge = event.getItemStack();
        if (!BuiltInRegistries.ITEM.getKey(sponge.getItem()).equals(BUTCHERY_SPONGE)) {
            return;
        }

        Level level = event.getLevel();
        BlockEntity blockEntity = level.getBlockEntity(event.getPos());
        IFluidHandler handler = fluidHandler(blockEntity);
        if (handler == null) {
            return;
        }

        event.setCancellationResult(InteractionResult.sidedSuccess(level.isClientSide()));
        event.setCanceled(true);
        if (level.isClientSide()) {
            return;
        }

        double wetness = sponge.getOrDefault(DataComponents.CUSTOM_DATA, CustomData.EMPTY)
                .copyTag()
                .getDouble(SPONGE_WETNESS);
        if (wetness < 1) {
            event.getEntity().displayClientMessage(Component.literal("The sponge needs to be wet."), true);
            return;
        }

        int drained = drainStoredFluids(handler, SPONGE_DRAIN_AMOUNT);
        if (drained == 0) {
            event.getEntity().displayClientMessage(Component.literal("The container is empty."), true);
            return;
        }

        CustomData.update(DataComponents.CUSTOM_DATA, sponge,
                tag -> tag.putDouble(SPONGE_WETNESS, Math.max(0, wetness - 1)));
        blockEntity.setChanged();
        level.sendBlockUpdated(event.getPos(), blockEntity.getBlockState(), blockEntity.getBlockState(), 3);
        level.playSound(null, event.getPos(), SoundEvents.BUCKET_EMPTY, SoundSource.BLOCKS, 0.6F, 1.0F);
        event.getEntity().displayClientMessage(
                Component.literal("Absorbed " + drained + " mB of fluid."),
                true
        );
    }

    private static IFluidHandler fluidHandler(BlockEntity blockEntity) {
        if (blockEntity instanceof BloodgrateBlockEntity bloodGrate) {
            return bloodGrate.getFluidTank();
        }
        if (blockEntity instanceof AlchemistCauldronTile cauldron) {
            return cauldron.fluidInventory;
        }
        if (blockEntity instanceof BloodContainerBlockEntity bloodContainer) {
            return bloodContainer.getTank();
        }
        return null;
    }

    private static int drainStoredFluids(IFluidHandler handler, int maximum) {
        int drained = 0;
        for (int tank = 0; tank < handler.getTanks() && drained < maximum; tank++) {
            FluidStack stored = handler.getFluidInTank(tank);
            if (stored.isEmpty()) {
                continue;
            }

            int amount = Math.min(maximum - drained, stored.getAmount());
            FluidStack result = handler.drain(
                    stored.copyWithAmount(amount),
                    IFluidHandler.FluidAction.EXECUTE
            );
            drained += result.getAmount();
        }
        return drained;
    }

    private static void verifyMixinTarget(Class<?> target) {
        target.getName();
    }
}
