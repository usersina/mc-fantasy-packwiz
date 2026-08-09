package io.github.usersina.mcfantasy.tests.printingpress;

import com.glowbrick.printingpress.block.ModBlocks;
import com.glowbrick.printingpress.block.entity.block.PrintingPressBlockEntity;
import com.glowbrick.printingpress.block.entity.block.TypesetterBlockEntity;
import com.glowbrick.printingpress.item.ModItems;
import de.teamlapen.vampirism.core.ModDataComponents;
import de.teamlapen.vampirism.items.component.VampireBookContents;
import io.github.usersina.mcfantasy.printingpresscompat.PrintingPressBookData;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.tags.BlockTags;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.item.ItemEntity;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.crafting.ShapelessRecipe;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.phys.AABB;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.server.ServerStartedEvent;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

@Mod(PrintingPressIntegrationTests.MOD_ID)
public final class PrintingPressIntegrationTests {
    public static final String MOD_ID = "fantasy_pack_printing_press_tests";
    private static final Path RESULT_PATH = Path.of("fantasy-pack-tests", "printing-press.txt");

    private final List<String> results = new ArrayList<>();
    private int failures;

    public PrintingPressIntegrationTests(IEventBus modEventBus) {
        NeoForge.EVENT_BUS.addListener(this::onServerStarted);
    }

    private void onServerStarted(ServerStartedEvent event) {
        MinecraftServer server = event.getServer();
        ServerLevel level = server.overworld();
        BlockPos origin = new BlockPos(4, 200, 4);

        runCase("copyable-book allowlist", this::testCopyableBookAllowlist);
        runCase("Magic Ink recipe", () -> testMagicInkRecipe(server));
        runCase("workstation durability", () -> testWorkstationDurability(level, origin));
        runCase("Vampire Book typesetting", () -> testVampireBookTypesetting(level, origin));
        runCase("Vampire Book full-tank printing", () -> testVampireBookPrinting(level, origin.offset(4, 0, 0)));
        runCase("Hunter Intel tier round-trip", () -> testHunterIntelRoundTrip(level, origin.offset(8, 0, 0)));
        runCase("vanilla enchanted-book regression", () -> testVanillaPrinting(level, origin.offset(0, 0, 4)));
        runCase("Magic Ink recovery", () -> testInkRecovery(level, origin.offset(4, 0, 4), true, 3));
        runCase("normal Ink recovery", () -> testInkRecovery(level, origin.offset(8, 0, 4), false, 2));

        writeResult();
        server.halt(false);
    }

    private void testCopyableBookAllowlist() {
        assertTrue(vampireBook().is(PrintingPressBookData.COPYABLE_BOOKS), "Vampire Book missing from allowlist");
        for (int tier = 0; tier <= 9; tier++) {
            assertTrue(
                    hunterIntel(tier).is(PrintingPressBookData.COPYABLE_BOOKS),
                    "Hunter Intel tier " + tier + " missing from allowlist"
            );
        }
        assertFalse(new ItemStack(Items.WRITTEN_BOOK).is(PrintingPressBookData.COPYABLE_BOOKS), "Written Book was broadly allowlisted");
        assertFalse(new ItemStack(requireItem("irons_spellbooks:iron_spell_book")).is(PrintingPressBookData.COPYABLE_BOOKS), "Iron spellbook was broadly allowlisted");
    }

    private void testMagicInkRecipe(MinecraftServer server) {
        var recipeHolder = server.getRecipeManager()
                .byKey(ResourceLocation.fromNamespaceAndPath("printingpress", "magic_ink_bottle"))
                .orElseThrow(() -> new AssertionError("Magic Ink Bottle recipe is missing"));
        assertTrue(recipeHolder.value() instanceof ShapelessRecipe, "Magic Ink Bottle recipe is not shapeless");

        ShapelessRecipe recipe = (ShapelessRecipe) recipeHolder.value();
        ItemStack commonInk = new ItemStack(requireItem("irons_spellbooks:common_ink"));
        ItemStack arcaneEssence = new ItemStack(requireItem("irons_spellbooks:arcane_essence"));
        ItemStack lapis = new ItemStack(Items.LAPIS_LAZULI);
        assertEquals(3, recipe.getIngredients().size(), "Magic Ink Bottle recipe ingredient count");
        assertEquals(1, countMatchingIngredients(recipe, commonInk), "Magic Ink Bottle Common Ink cost");
        assertEquals(1, countMatchingIngredients(recipe, arcaneEssence), "Magic Ink Bottle Arcane Essence cost");
        assertEquals(1, countMatchingIngredients(recipe, lapis), "Magic Ink Bottle lapis cost");
        assertTrue(
                recipe.getResultItem(server.registryAccess()).is(ModItems.MAGIC_INK_BOTTLE.get()),
                "Magic Ink Bottle recipe has the wrong output"
        );
        assertTrue(
                server.getRecipeManager()
                        .byKey(ResourceLocation.fromNamespaceAndPath("printingpress", "magic_ink_bottle_alt"))
                        .isEmpty(),
                "upstream enchanted-book Magic Ink shortcut is still enabled"
        );
    }

    private void testWorkstationDurability(ServerLevel level, BlockPos pos) {
        assertTrue(
                ModBlocks.PRINTINGPRESS.get().defaultBlockState().is(BlockTags.MINEABLE_WITH_AXE),
                "Printing Press is not axe-mineable"
        );
        assertTrue(
                ModBlocks.TYPESETTER.get().defaultBlockState().is(BlockTags.MINEABLE_WITH_AXE),
                "Typesetter is not axe-mineable"
        );
        assertFloatEquals(
                2.5F,
                ModBlocks.PRINTINGPRESS.get().defaultBlockState().getDestroySpeed(level, pos),
                "Printing Press hardness"
        );
        assertFloatEquals(
                2.5F,
                ModBlocks.TYPESETTER.get().defaultBlockState().getDestroySpeed(level, pos),
                "Typesetter hardness"
        );
        assertFloatEquals(6.0F, ModBlocks.PRINTINGPRESS.get().getExplosionResistance(), "Printing Press resistance");
        assertFloatEquals(6.0F, ModBlocks.TYPESETTER.get().getExplosionResistance(), "Typesetter resistance");
    }

    private void testVampireBookTypesetting(ServerLevel level, BlockPos pos) {
        TypesetterBlockEntity typesetter = placeTypesetter(level, pos);
        ItemStack source = vampireBook();

        assertTrue(typesetter.itemHandler.isItemValid(0, source), "Typesetter rejected tagged Vampire Book");
        typesetter.itemHandler.setStackInSlot(0, source.copy());
        typesetter.itemHandler.setStackInSlot(1, new ItemStack(ModItems.MOVABLE_TYPE.get()));
        tickTypesetter(level, pos, typesetter, 72);

        ItemStack typeBlock = typesetter.itemHandler.getStackInSlot(2);
        assertTrue(typeBlock.is(ModItems.TYPE_BLOCK.get()), "Typesetter did not create a Type Block");
        assertTrue(PrintingPressBookData.hasCopiedBook(typeBlock), "Type Block has no copied-book data");
        assertTrue(typesetter.itemHandler.getStackInSlot(1).isEmpty(), "Movable Type was not consumed");
        assertTrue(ItemStack.isSameItemSameComponents(source, typesetter.itemHandler.getStackInSlot(0)), "Source Vampire Book changed");

        ItemStack stored = PrintingPressBookData.readCopiedBook(typeBlock, level.registryAccess());
        assertTrue(ItemStack.isSameItemSameComponents(source, stored), "Type Block did not preserve Vampire Book components");
        clearTestBlock(level, pos);
    }

    private void testVampireBookPrinting(ServerLevel level, BlockPos pos) {
        ItemStack source = vampireBook();
        ItemStack typeBlock = new ItemStack(ModItems.TYPE_BLOCK.get());
        PrintingPressBookData.storeCopiedBook(typeBlock, source, level.registryAccess());
        PrintingPressBlockEntity press = placePress(level, pos);

        press.itemHandler.setStackInSlot(2, new ItemStack(ModItems.MAGIC_INK_BOTTLE.get(), 4));
        tickPress(level, pos, press, 4);
        press.itemHandler.setStackInSlot(0, new ItemStack(Items.BOOK));
        press.itemHandler.setStackInSlot(1, typeBlock.copy());
        tickPress(level, pos, press, 220);
        assertTrue(press.itemHandler.getStackInSlot(3).isEmpty(), "Vampire Book printed with less than a full tank");

        press.itemHandler.setStackInSlot(2, new ItemStack(ModItems.MAGIC_INK_BOTTLE.get()));
        tickPress(level, pos, press, 200);

        ItemStack output = press.itemHandler.getStackInSlot(3);
        assertTrue(ItemStack.isSameItemSameComponents(source, output), "Printed Vampire Book was not an exact copy");
        assertTrue(press.itemHandler.getStackInSlot(0).isEmpty(), "Blank Book was not consumed");
        assertTrue(PrintingPressBookData.hasCopiedBook(press.itemHandler.getStackInSlot(1)), "Type Block was consumed or changed");
        clearTestBlock(level, pos);
        clearNearbyItems(level, pos);
    }

    private void testHunterIntelRoundTrip(ServerLevel level, BlockPos pos) {
        for (int tier = 0; tier <= 9; tier++) {
            ItemStack source = hunterIntel(tier);
            TypesetterBlockEntity typesetter = placeTypesetter(level, pos);

            assertTrue(typesetter.itemHandler.isItemValid(0, source), "Typesetter rejected Hunter Intel tier " + tier);
            typesetter.itemHandler.setStackInSlot(0, source.copy());
            typesetter.itemHandler.setStackInSlot(1, new ItemStack(ModItems.MOVABLE_TYPE.get()));
            tickTypesetter(level, pos, typesetter, 72);

            ItemStack typeBlock = typesetter.itemHandler.getStackInSlot(2).copy();
            assertTrue(PrintingPressBookData.hasCopiedBook(typeBlock), "Hunter Intel tier " + tier + " was not captured");
            assertTrue(
                    ItemStack.isSameItemSameComponents(
                            source,
                            PrintingPressBookData.readCopiedBook(typeBlock, level.registryAccess())
                    ),
                    "Type Block changed Hunter Intel tier " + tier
            );
            clearTestBlock(level, pos);

            PrintingPressBlockEntity press = placePress(level, pos);
            press.itemHandler.setStackInSlot(2, new ItemStack(ModItems.MAGIC_INK_BOTTLE.get(), 5));
            tickPress(level, pos, press, 5);
            press.itemHandler.setStackInSlot(0, new ItemStack(Items.BOOK));
            press.itemHandler.setStackInSlot(1, typeBlock);
            tickPress(level, pos, press, 220);

            assertTrue(
                    ItemStack.isSameItemSameComponents(source, press.itemHandler.getStackInSlot(3)),
                    "Printing changed Hunter Intel tier " + tier
            );
            clearTestBlock(level, pos);
            clearNearbyItems(level, pos);
        }
    }

    private void testVanillaPrinting(ServerLevel level, BlockPos pos) {
        TypesetterBlockEntity typesetter = placeTypesetter(level, pos);
        typesetter.itemHandler.setStackInSlot(0, new ItemStack(Items.ENCHANTED_BOOK));
        typesetter.itemHandler.setStackInSlot(1, new ItemStack(ModItems.MOVABLE_TYPE.get()));
        tickTypesetter(level, pos, typesetter, 72);
        ItemStack typeBlock = typesetter.itemHandler.getStackInSlot(2).copy();
        assertTrue(typeBlock.is(ModItems.TYPE_BLOCK.get()), "upstream enchanted-book Typesetter path failed");
        assertFalse(PrintingPressBookData.hasCopiedBook(typeBlock), "vanilla Type Block received custom-book marker");
        clearTestBlock(level, pos);

        PrintingPressBlockEntity press = placePress(level, pos);
        press.itemHandler.setStackInSlot(2, new ItemStack(ModItems.MAGIC_INK_BOTTLE.get()));
        tickPress(level, pos, press, 1);
        press.itemHandler.setStackInSlot(0, new ItemStack(Items.BOOK));
        press.itemHandler.setStackInSlot(1, typeBlock);
        tickPress(level, pos, press, 200);
        assertTrue(press.itemHandler.getStackInSlot(3).is(Items.ENCHANTED_BOOK), "upstream enchanted-book print path failed");
        clearTestBlock(level, pos);
        clearNearbyItems(level, pos);
    }

    private void testInkRecovery(ServerLevel level, BlockPos pos, boolean magic, int bottles) {
        PrintingPressBlockEntity press = placePress(level, pos);
        Item ink = magic ? ModItems.MAGIC_INK_BOTTLE.get() : ModItems.INK_BOTTLE.get();
        press.itemHandler.setStackInSlot(2, new ItemStack(ink, bottles));
        tickPress(level, pos, press, bottles);
        assertTrue(press.itemHandler.getStackInSlot(2).isEmpty(), "press did not absorb ink bottles");
        CompoundTag stored = press.saveWithoutMetadata(level.registryAccess());
        assertEquals(bottles * 200, stored.getInt("printing_press.ink_level"), "press stored the wrong ink amount");
        assertEquals(magic ? 2 : 1, stored.getInt("printing_press.current_ink_mode"), "press stored the wrong ink type");

        press.drops();
        CompoundTag drained = press.saveWithoutMetadata(level.registryAccess());
        assertEquals(0, drained.getInt("printing_press.ink_level"), "press did not drain recovered ink");
        assertEquals(0, drained.getInt("printing_press.current_ink_mode"), "press did not clear its recovered ink type");

        press.drops();
        CompoundTag drainedAgain = press.saveWithoutMetadata(level.registryAccess());
        assertEquals(0, drainedAgain.getInt("printing_press.ink_level"), "press recovered stored ink more than once");
        clearTestBlock(level, pos);
        clearNearbyItems(level, pos);
    }

    private static ItemStack vampireBook() {
        ItemStack stack = new ItemStack(requireItem("vampirism:vampire_book"));
        stack.set(
                ModDataComponents.VAMPIRE_BOOK.get(),
                new VampireBookContents("fantasy_pack_test", "Fantasy Pack", "A Test of Blood")
        );
        return stack;
    }

    private static ItemStack hunterIntel(int tier) {
        return new ItemStack(requireItem("vampirism:hunter_intel_" + tier));
    }

    private static int countMatchingIngredients(ShapelessRecipe recipe, ItemStack stack) {
        return (int) recipe.getIngredients().stream().filter(ingredient -> ingredient.test(stack)).count();
    }

    private static TypesetterBlockEntity placeTypesetter(ServerLevel level, BlockPos pos) {
        level.setBlock(pos, ModBlocks.TYPESETTER.get().defaultBlockState(), 3);
        BlockEntity blockEntity = level.getBlockEntity(pos);
        if (!(blockEntity instanceof TypesetterBlockEntity typesetter)) {
            throw new AssertionError("Typesetter block entity was not created");
        }
        return typesetter;
    }

    private static PrintingPressBlockEntity placePress(ServerLevel level, BlockPos pos) {
        level.setBlock(pos, ModBlocks.PRINTINGPRESS.get().defaultBlockState(), 3);
        BlockEntity blockEntity = level.getBlockEntity(pos);
        if (!(blockEntity instanceof PrintingPressBlockEntity press)) {
            throw new AssertionError("Printing Press block entity was not created");
        }
        return press;
    }

    private static void tickTypesetter(ServerLevel level, BlockPos pos, TypesetterBlockEntity typesetter, int count) {
        for (int i = 0; i < count; i++) {
            typesetter.tick(level, pos, level.getBlockState(pos));
        }
    }

    private static void tickPress(ServerLevel level, BlockPos pos, PrintingPressBlockEntity press, int count) {
        for (int i = 0; i < count; i++) {
            press.tick(level, pos, level.getBlockState(pos));
        }
    }

    private static void clearNearbyItems(ServerLevel level, BlockPos pos) {
        level.getEntitiesOfClass(ItemEntity.class, new AABB(pos).inflate(2.0)).forEach(ItemEntity::discard);
    }

    private static void clearTestBlock(ServerLevel level, BlockPos pos) {
        level.setBlock(pos, Blocks.AIR.defaultBlockState(), 3);
    }

    private static Item requireItem(String id) {
        Item item = BuiltInRegistries.ITEM.get(ResourceLocation.parse(id));
        if (item == Items.AIR) {
            throw new AssertionError("missing item " + id);
        }
        return item;
    }

    private void runCase(String name, ThrowingRunnable test) {
        try {
            test.run();
            results.add("PASS " + name);
        } catch (Throwable error) {
            failures++;
            results.add("FAIL " + name + ": " + error.getMessage());
            StringWriter trace = new StringWriter();
            error.printStackTrace(new PrintWriter(trace));
            results.add(trace.toString());
        }
    }

    private void writeResult() {
        try {
            Files.createDirectories(RESULT_PATH.getParent());
            List<String> report = new ArrayList<>();
            report.add(failures == 0 ? "PASS printing-press" : "FAIL printing-press (" + failures + ")");
            report.addAll(results);
            Files.write(RESULT_PATH, report, StandardCharsets.UTF_8);
        } catch (Exception error) {
            throw new RuntimeException("failed to write printing press test result", error);
        }
    }

    private static void assertTrue(boolean value, String message) {
        if (!value) {
            throw new AssertionError(message);
        }
    }

    private static void assertFalse(boolean value, String message) {
        assertTrue(!value, message);
    }

    private static void assertEquals(int expected, int actual, String message) {
        if (expected != actual) {
            throw new AssertionError(message + " (expected " + expected + ", got " + actual + ")");
        }
    }

    private static void assertFloatEquals(float expected, float actual, String message) {
        if (Float.compare(expected, actual) != 0) {
            throw new AssertionError(message + " (expected " + expected + ", got " + actual + ")");
        }
    }

    @FunctionalInterface
    private interface ThrowingRunnable {
        void run() throws Exception;
    }
}
