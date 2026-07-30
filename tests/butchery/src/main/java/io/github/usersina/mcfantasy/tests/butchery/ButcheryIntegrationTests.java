package io.github.usersina.mcfantasy.tests.butchery;

import io.redspace.ironsspellbooks.block.alchemist_cauldron.AlchemistCauldronTile;
import net.grid.vampiresdelight.common.registry.VDDataComponents;
import net.mcreator.butchery.block.BloodgrateBlock;
import net.mcreator.butchery.block.entity.BloodgrateBlockEntity;
import net.mcreator.butchery.init.ButcheryModBlocks;
import net.mcreator.butchery.init.ButcheryModFluids;
import net.mcreator.butchery.init.ButcheryModItems;
import net.mcreator.butchery.procedures.BloodgratechangeProcedure;
import net.mcreator.butchery.procedures.BloodgratewithdrawbloodProcedure;
import net.mcreator.butchery.procedures.FillbloodgrateProcedure;
import net.mcreator.butchery.procedures.SmallfillbloodgrateProcedure;
import net.minecraft.core.BlockPos;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.tags.TagKey;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.food.FoodProperties;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.component.CustomData;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.Vec3;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.common.util.FakePlayer;
import net.neoforged.neoforge.common.util.FakePlayerFactory;
import net.neoforged.neoforge.event.entity.player.PlayerInteractEvent;
import net.neoforged.neoforge.event.server.ServerStartedEvent;
import net.neoforged.neoforge.fluids.FluidStack;
import net.neoforged.neoforge.fluids.capability.IFluidHandler;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Mod(ButcheryIntegrationTests.MOD_ID)
public final class ButcheryIntegrationTests {
    public static final String MOD_ID = "fantasy_pack_butchery_tests";
    private static final Path RESULT_PATH = Path.of("fantasy-pack-tests", "butchery.txt");
    private static final ResourceLocation VAMPIRISM_IMPURE_BLOOD = id("vampirism:impure_blood");
    private static final ResourceLocation VAMPIRISM_IMPURE_BLOOD_BUCKET = id("vampirism:impure_blood_bucket");
    private static final TagKey<Fluid> CLEAN_BLOOD = TagKey.create(Registries.FLUID, id("fantasy_pack:clean_blood"));
    private static final TagKey<Item> BUTCHERY_WEAPONS = TagKey.create(
            Registries.ITEM,
            id("butchery:enchantable/weapon")
    );

    private final List<String> results = new ArrayList<>();
    private int failures;

    public ButcheryIntegrationTests(IEventBus modEventBus) {
        NeoForge.EVENT_BUS.addListener(this::onServerStarted);
    }

    private void onServerStarted(ServerStartedEvent event) {
        MinecraftServer server = event.getServer();
        ServerLevel level = server.overworld();
        BlockPos origin = new BlockPos(0, 200, 0);

        runCase("recipes and registries", () -> testRecipesAndRegistries(server));
        runCase("Butchery weapon tag", this::testWeaponTag);
        runCase("blood-grate mode switching", () -> testModeSwitching(level, origin));
        runCase("filled grate blocks mode switching", () -> testFilledModeSwitch(level, origin));
        runCase("small carcass blood routing", () -> testSmallFillModes(level, origin));
        runCase("full carcass blood routing", () -> testFullFillModes(level, origin));
        runCase("Vampirism grate extraction", () -> testVampirismExtraction(level, origin));
        runCase("blood-grate persistence", () -> testPersistence(level, origin));
        runCase("wet sponge draining", () -> testSpongeDrain(level, origin));
        runCase("clean-blood cauldron merging", () -> testCleanBloodMerge(level, origin));
        runCase("Butchery vampire foods", this::testVampireFoods);

        writeResult();
        server.halt(false);
    }

    private void testRecipesAndRegistries(MinecraftServer server) {
        requireItem("butchery:butchers_papers");
        requireItem("butchery:sponge");
        requireItem("vampirism:impure_blood_bucket");
        requireFluid("butchery:blood");
        requireFluid("butchery:infected_blood");
        requireFluid("vampirism:blood");
        requireFluid("vampirism:impure_blood");
        requireBlock("butchery:blood_grate");
        requireBlock("irons_spellbooks:alchemist_cauldron");

        assertFalse(server.getRecipeManager().hadErrorsLoading(), "recipe manager reported parse errors");
        for (String recipe : List.of(
                "butchery_convenience:fill_alchemist_cauldron_from_blood_bottle",
                "butchery_convenience:fill_alchemist_cauldron_from_blood_bucket",
                "butchery_convenience:fill_alchemist_cauldron_from_infected_blood_bottle",
                "butchery_convenience:fill_alchemist_cauldron_from_infected_blood_bucket",
                "butchery_convenience:fill_blood_bottle_from_alchemist_cauldron",
                "butchery_convenience:fill_blood_bucket_from_alchemist_cauldron",
                "butchery_convenience:fill_infected_blood_bottle_from_alchemist_cauldron",
                "butchery_convenience:fill_infected_blood_bucket_from_alchemist_cauldron",
                "vampirism_convenience:blood_vial_from_butchery_heart",
                "vampirism_convenience:butchery_eye_from_human_eye",
                "vampirism_convenience:butchery_heart_from_human_heart",
                "vampirism_convenience:human_eye_from_butchery_eye",
                "vampirism_convenience:human_heart_from_butchery_heart",
                "vampirism_convenience:fill_alchemist_cauldron_from_vampirism_blood_bucket",
                "vampirism_convenience:fill_alchemist_cauldron_from_vampirism_impure_blood_bucket",
                "vampirism_convenience:fill_vampirism_blood_bucket_from_alchemist_cauldron",
                "vampirism_convenience:fill_vampirism_impure_blood_bucket_from_alchemist_cauldron",
                "irons_spellbooks:alchemist_cauldron/fill_blood_vial",
                "irons_spellbooks_convenience:hogskin_from_butchery_hoglin_skin"
        )) {
            assertTrue(server.getRecipeManager().byKey(id(recipe)).isPresent(), "missing recipe " + recipe);
        }
    }

    private void testWeaponTag() {
        assertTrue(new ItemStack(Items.IRON_SWORD).is(BUTCHERY_WEAPONS), "iron sword missing from tag");
        assertTrue(new ItemStack(Items.BOW).is(BUTCHERY_WEAPONS), "bow missing from tag");
        assertTrue(new ItemStack(Items.CROSSBOW).is(BUTCHERY_WEAPONS), "crossbow missing from tag");
    }

    private void testModeSwitching(ServerLevel level, BlockPos origin) {
        BloodgrateBlockEntity grate = placeGrate(level, origin, 0);
        FakePlayer player = preparePlayer(level, origin);
        player.setItemInHand(InteractionHand.MAIN_HAND, new ItemStack(ButcheryModItems.BUTCHERS_PAPERS.get()));

        BloodgratechangeProcedure.execute(level, origin.getX(), origin.getY(), origin.getZ(), level.getBlockState(origin), player);
        assertEquals(3, grateMode(level, origin), "grate did not switch to Vampirism mode");
        assertTrue(grate.getPersistentData().getBoolean("isVampirism"), "Vampirism mode flag missing");
        assertFalse(grate.getPersistentData().getBoolean("isButchery"), "Butchery mode flag remained set");

        BloodgratechangeProcedure.execute(level, origin.getX(), origin.getY(), origin.getZ(), level.getBlockState(origin), player);
        assertEquals(0, grateMode(level, origin), "grate did not switch back to Butchery mode");
        assertTrue(grate.getPersistentData().getBoolean("isButchery"), "Butchery mode flag missing");
        clearTestBlock(level, origin);
    }

    private void testFilledModeSwitch(ServerLevel level, BlockPos origin) {
        BloodgrateBlockEntity grate = placeGrate(level, origin, 0);
        grate.getFluidTank().fill(new FluidStack(ButcheryModFluids.BLOOD.get(), 100), IFluidHandler.FluidAction.EXECUTE);
        FakePlayer player = preparePlayer(level, origin);
        player.setItemInHand(InteractionHand.MAIN_HAND, new ItemStack(ButcheryModItems.BUTCHERS_PAPERS.get()));

        BloodgratechangeProcedure.execute(level, origin.getX(), origin.getY(), origin.getZ(), level.getBlockState(origin), player);
        assertEquals(0, grateMode(level, origin), "filled grate changed mode");
        assertEquals(100, grate.getFluidTank().getFluidAmount(), "filled grate lost blood");
        clearTestBlock(level, origin);
    }

    private void testSmallFillModes(ServerLevel level, BlockPos origin) {
        BloodgrateBlockEntity grate = placeGrate(level, origin, 0);
        SmallfillbloodgrateProcedure.execute(level, origin.getX(), origin.getY() + 1, origin.getZ());
        assertFluid(grate.getFluidTank().getFluid(), "butchery:blood", 50);

        clearTestBlock(level, origin);
        grate = placeGrate(level, origin, 3);
        SmallfillbloodgrateProcedure.execute(level, origin.getX(), origin.getY() + 1, origin.getZ());
        assertFluid(grate.getFluidTank().getFluid(), "vampirism:impure_blood", 50);
        clearTestBlock(level, origin);
    }

    private void testFullFillModes(ServerLevel level, BlockPos origin) {
        BloodgrateBlockEntity grate = placeGrate(level, origin, 0);
        FillbloodgrateProcedure.execute(level, origin.getX(), origin.getY() + 1, origin.getZ());
        assertFluid(grate.getFluidTank().getFluid(), "butchery:blood", 50);

        clearTestBlock(level, origin);
        grate = placeGrate(level, origin, 3);
        FillbloodgrateProcedure.execute(level, origin.getX(), origin.getY() + 1, origin.getZ());
        assertFluid(grate.getFluidTank().getFluid(), "vampirism:impure_blood", 50);
        clearTestBlock(level, origin);
    }

    private void testVampirismExtraction(ServerLevel level, BlockPos origin) {
        BloodgrateBlockEntity grate = placeGrate(level, origin, 3);
        Fluid impureBlood = requireFluid(VAMPIRISM_IMPURE_BLOOD.toString());
        grate.getFluidTank().setFluid(new FluidStack(impureBlood, 1000));
        FakePlayer player = preparePlayer(level, origin);
        player.setItemInHand(InteractionHand.MAIN_HAND, new ItemStack(Items.BUCKET));

        BloodgratewithdrawbloodProcedure.execute(
                level,
                origin.getX(),
                origin.getY(),
                origin.getZ(),
                level.getBlockState(origin),
                player
        );
        assertEquals(0, grate.getFluidTank().getFluidAmount(), "bucket extraction did not drain 1000 mB");
        assertTrue(
                player.getInventory().contains(new ItemStack(requireItem(VAMPIRISM_IMPURE_BLOOD_BUCKET.toString()))),
                "impure blood bucket was not returned"
        );

        player.getInventory().clearContent();
        player.setItemInHand(InteractionHand.MAIN_HAND, new ItemStack(Items.GLASS_BOTTLE));
        grate.getFluidTank().setFluid(new FluidStack(impureBlood, 333));
        BloodgratewithdrawbloodProcedure.execute(
                level,
                origin.getX(),
                origin.getY(),
                origin.getZ(),
                level.getBlockState(origin),
                player
        );
        assertEquals(333, grate.getFluidTank().getFluidAmount(), "glass bottle bypassed purification");
        assertTrue(player.getMainHandItem().is(Items.GLASS_BOTTLE), "glass bottle was replaced");
        clearTestBlock(level, origin);
    }

    private void testPersistence(ServerLevel level, BlockPos origin) {
        BloodgrateBlockEntity grate = placeGrate(level, origin, 3);
        grate.getFluidTank().setFluid(new FluidStack(requireFluid("vampirism:impure_blood"), 321));
        grate.getPersistentData().putBoolean("isVampirism", true);
        grate.getPersistentData().putBoolean("isButchery", false);

        CompoundTag saved = grate.saveWithFullMetadata(level.registryAccess());
        BlockEntity loaded = BlockEntity.loadStatic(origin, level.getBlockState(origin), saved, level.registryAccess());
        assertTrue(loaded instanceof BloodgrateBlockEntity, "serialized block entity did not reload as a Blood Grate");
        BloodgrateBlockEntity loadedGrate = (BloodgrateBlockEntity) loaded;
        assertFluid(loadedGrate.getFluidTank().getFluid(), "vampirism:impure_blood", 321);
        assertTrue(loadedGrate.getPersistentData().getBoolean("isVampirism"), "Vampirism flag did not persist");
        clearTestBlock(level, origin);
    }

    private void testSpongeDrain(ServerLevel level, BlockPos origin) {
        BloodgrateBlockEntity grate = placeGrate(level, origin, 0);
        grate.getFluidTank().setFluid(new FluidStack(ButcheryModFluids.BLOOD.get(), 750));
        FakePlayer player = preparePlayer(level, origin);
        ItemStack sponge = new ItemStack(requireItem("butchery:sponge"));
        CustomData.update(DataComponents.CUSTOM_DATA, sponge, tag -> tag.putDouble("spongeWetness", 1));
        player.setItemInHand(InteractionHand.MAIN_HAND, sponge);

        BlockHitResult hit = new BlockHitResult(Vec3.atCenterOf(origin), net.minecraft.core.Direction.UP, origin, false);
        PlayerInteractEvent.RightClickBlock click = new PlayerInteractEvent.RightClickBlock(
                player,
                InteractionHand.MAIN_HAND,
                origin,
                hit
        );
        NeoForge.EVENT_BUS.post(click);

        assertTrue(click.isCanceled(), "sponge interaction was not handled");
        assertEquals(0, grate.getFluidTank().getFluidAmount(), "sponge did not drain stored blood");
        double wetness = sponge.getOrDefault(DataComponents.CUSTOM_DATA, CustomData.EMPTY)
                .copyTag()
                .getDouble("spongeWetness");
        assertEquals(0.0, wetness, "sponge wetness was not consumed");
        clearTestBlock(level, origin);
    }

    private void testCleanBloodMerge(ServerLevel level, BlockPos origin) {
        Block cauldronBlock = requireBlock("irons_spellbooks:alchemist_cauldron");
        level.setBlock(origin, cauldronBlock.defaultBlockState(), 3);
        assertTrue(level.getBlockEntity(origin) instanceof AlchemistCauldronTile, "Alchemist Cauldron tile missing");
        AlchemistCauldronTile cauldron = (AlchemistCauldronTile) level.getBlockEntity(origin);
        cauldron.fluidInventory.clear();

        Fluid butcheryBlood = requireFluid("butchery:blood");
        Fluid vampirismBlood = requireFluid("vampirism:blood");
        assertTrue(new FluidStack(butcheryBlood, 1).is(CLEAN_BLOOD), "Butchery blood missing from clean tag");
        assertTrue(new FluidStack(vampirismBlood, 1).is(CLEAN_BLOOD), "Vampirism blood missing from clean tag");

        assertEquals(
                400,
                cauldron.fluidInventory.fill(new FluidStack(butcheryBlood, 400), IFluidHandler.FluidAction.EXECUTE),
                "cauldron rejected initial Butchery blood"
        );
        assertEquals(
                350,
                cauldron.fluidInventory.fill(new FluidStack(vampirismBlood, 350), IFluidHandler.FluidAction.EXECUTE),
                "cauldron rejected equivalent Vampirism blood"
        );
        assertEquals(750, cauldron.fluidInventory.fluidAmount(), "clean blood did not merge to 750 mB");
        assertFluid(cauldron.fluidInventory.getFluidInTank(0), "butchery:blood", 750);
        clearTestBlock(level, origin);
    }

    private void testVampireFoods() {
        Map<String, Integer> expected = new LinkedHashMap<>();
        expected.put("heart", 5);
        expected.put("eye", 2);
        expected.put("intestines", 4);
        expected.put("kidney", 3);
        expected.put("liver", 4);
        expected.put("lungs", 4);
        expected.put("stomach", 4);
        expected.put("flesh", 5);
        expected.put("rawhumanmeat", 4);
        expected.put("raw_villager_steak", 4);
        expected.put("raw_evoker_meat", 3);
        expected.put("raw_pillager_meat", 3);
        expected.put("raw_vindicator_meat", 3);
        expected.put("raw_witch_meat", 5);
        expected.put("raw_blood_sausage", 4);
        expected.put("cooked_blood_sausage", 4);

        expected.forEach((path, blood) -> {
            ItemStack stack = new ItemStack(requireItem("butchery:" + path));
            FoodProperties food = stack.get(VDDataComponents.VAMPIRE_FOOD.value());
            assertTrue(food != null, "missing vampire food component on butchery:" + path);
            assertEquals(blood.intValue(), food.nutrition(), "wrong vampire blood value on butchery:" + path);
        });
    }

    private BloodgrateBlockEntity placeGrate(ServerLevel level, BlockPos pos, int mode) {
        clearTestBlock(level, pos);
        level.getChunkAt(pos);
        BlockState state = ButcheryModBlocks.BLOOD_GRATE.get()
                .defaultBlockState()
                .setValue(BloodgrateBlock.BLOCKSTATE, mode);
        assertTrue(level.setBlock(pos, state, 3), "could not place Blood Grate");
        assertTrue(level.getBlockEntity(pos) instanceof BloodgrateBlockEntity, "Blood Grate tile missing");
        BloodgrateBlockEntity grate = (BloodgrateBlockEntity) level.getBlockEntity(pos);
        grate.getPersistentData().putBoolean("isButchery", mode == 0);
        grate.getPersistentData().putBoolean("isVampirism", mode == 3);
        grate.getPersistentData().putBoolean("isBloodMagic", false);
        grate.getPersistentData().putBoolean("isHexeri", false);
        return grate;
    }

    private FakePlayer preparePlayer(ServerLevel level, BlockPos pos) {
        FakePlayer player = FakePlayerFactory.getMinecraft(level);
        player.getInventory().clearContent();
        player.setShiftKeyDown(false);
        player.setPos(pos.getX() + 0.5, pos.getY() + 1, pos.getZ() + 0.5);
        return player;
    }

    private static void clearTestBlock(ServerLevel level, BlockPos pos) {
        level.setBlock(pos, Blocks.AIR.defaultBlockState(), 3);
    }

    private static int grateMode(ServerLevel level, BlockPos pos) {
        return level.getBlockState(pos).getValue(BloodgrateBlock.BLOCKSTATE);
    }

    private void runCase(String name, ThrowingRunnable test) {
        try {
            test.run();
            results.add("PASS " + name);
            System.out.println("[Fantasy Pack Test] PASS " + name);
        } catch (Throwable throwable) {
            failures++;
            StringWriter stack = new StringWriter();
            throwable.printStackTrace(new PrintWriter(stack));
            results.add("FAIL " + name + "\n" + stack);
            System.err.println("[Fantasy Pack Test] FAIL " + name + ": " + throwable);
        }
    }

    private void writeResult() {
        try {
            Files.createDirectories(RESULT_PATH.getParent());
            List<String> report = new ArrayList<>();
            report.add(failures == 0 ? "PASS butchery" : "FAIL butchery (" + failures + " failed)");
            report.addAll(results);
            Files.writeString(RESULT_PATH, String.join("\n", report) + "\n", StandardCharsets.UTF_8);
        } catch (Exception exception) {
            exception.printStackTrace();
        }
    }

    private static Item requireItem(String value) {
        ResourceLocation itemId = id(value);
        Item item = BuiltInRegistries.ITEM.get(itemId);
        assertTrue(item != Items.AIR, "missing item " + itemId);
        return item;
    }

    private static Fluid requireFluid(String value) {
        ResourceLocation fluidId = id(value);
        Fluid fluid = BuiltInRegistries.FLUID.get(fluidId);
        assertTrue(!BuiltInRegistries.FLUID.getKey(fluid).equals(id("minecraft:empty")), "missing fluid " + fluidId);
        return fluid;
    }

    private static Block requireBlock(String value) {
        ResourceLocation blockId = id(value);
        Block block = BuiltInRegistries.BLOCK.get(blockId);
        assertTrue(block != Blocks.AIR, "missing block " + blockId);
        return block;
    }

    private static void assertFluid(FluidStack stack, String expectedId, int expectedAmount) {
        assertFalse(stack.isEmpty(), "expected " + expectedId + " but fluid stack was empty");
        assertEquals(id(expectedId), BuiltInRegistries.FLUID.getKey(stack.getFluid()), "wrong fluid");
        assertEquals(expectedAmount, stack.getAmount(), "wrong fluid amount");
    }

    private static ResourceLocation id(String value) {
        return ResourceLocation.parse(value);
    }

    private static void assertTrue(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    private static void assertFalse(boolean condition, String message) {
        assertTrue(!condition, message);
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (!expected.equals(actual)) {
            throw new AssertionError(message + ": expected " + expected + ", got " + actual);
        }
    }

    private static void assertEquals(double expected, double actual, String message) {
        if (Double.compare(expected, actual) != 0) {
            throw new AssertionError(message + ": expected " + expected + ", got " + actual);
        }
    }

    @FunctionalInterface
    private interface ThrowingRunnable {
        void run() throws Exception;
    }
}
