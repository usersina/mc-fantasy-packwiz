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
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.item.ItemEntity;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
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
        BlockPos origin = new BlockPos(0, 200, 0);

        runCase("copyable-book allowlist", this::testCopyableBookAllowlist);
        runCase("workstation durability", () -> testWorkstationDurability(level, origin.offset(-10, 0, 0)));
        runCase("Vampire Book typesetting", () -> testVampireBookTypesetting(level, origin));
        runCase("Vampire Book full-tank printing", () -> testVampireBookPrinting(level, origin.offset(10, 0, 0)));
        runCase("vanilla enchanted-book regression", () -> testVanillaPrinting(level, origin.offset(20, 0, 0)));
        runCase("Magic Ink recovery", () -> testInkRecovery(level, origin.offset(30, 0, 0), true, 3));
        runCase("normal Ink recovery", () -> testInkRecovery(level, origin.offset(40, 0, 0), false, 2));

        writeResult();
        server.halt(false);
    }

    private void testCopyableBookAllowlist() {
        assertTrue(vampireBook().is(PrintingPressBookData.COPYABLE_BOOKS), "Vampire Book missing from allowlist");
        assertFalse(new ItemStack(Items.WRITTEN_BOOK).is(PrintingPressBookData.COPYABLE_BOOKS), "Written Book was broadly allowlisted");
        assertFalse(new ItemStack(requireItem("irons_spellbooks:iron_spell_book")).is(PrintingPressBookData.COPYABLE_BOOKS), "Iron spellbook was broadly allowlisted");
    }

    private void testWorkstationDurability(ServerLevel level, BlockPos pos) {
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

        clearNearbyItems(level, pos);
        press.drops();
        assertEquals(bottles, countNearbyItem(level, pos, ink), "press returned the wrong amount of stored ink");

        clearNearbyItems(level, pos);
        press.drops();
        assertEquals(0, countNearbyItem(level, pos, ink), "stored ink was dropped more than once");
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

    private static int countNearbyItem(ServerLevel level, BlockPos pos, Item item) {
        return level.getEntitiesOfClass(ItemEntity.class, new AABB(pos).inflate(2.0)).stream()
                .filter(entity -> entity.getItem().is(item))
                .mapToInt(entity -> entity.getItem().getCount())
                .sum();
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
