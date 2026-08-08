package io.github.usersina.mcfantasy.tests.fishofthieves;

import com.stevekung.fishofthieves.entity.FishingHookBait;
import com.stevekung.fishofthieves.storage.BaitPreserveSavedData;
import com.stevekung.fishofthieves.storage.BaitStorageAccessor;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.projectile.FishingHook;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.phys.Vec3;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.common.util.FakePlayer;
import net.neoforged.neoforge.common.util.FakePlayerFactory;
import net.neoforged.neoforge.event.server.ServerStartedEvent;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

@Mod(FishOfThievesIntegrationTests.MOD_ID)
public final class FishOfThievesIntegrationTests {
    public static final String MOD_ID = "fantasy_pack_fish_of_thieves_tests";
    private static final Path RESULT_PATH = Path.of("fantasy-pack-tests", "fish-of-thieves.txt");

    private final List<String> results = new ArrayList<>();
    private int failures;

    public FishOfThievesIntegrationTests(IEventBus modEventBus) {
        NeoForge.EVENT_BUS.addListener(this::onServerStarted);
    }

    private void onServerStarted(ServerStartedEvent event) {
        MinecraftServer server = event.getServer();
        ServerLevel level = server.overworld();
        BaitPreserveSavedData data = ((BaitStorageAccessor) level).getBaitPreserve();

        runCase("unbaited hook save", () -> testUnbaitedHookSave(level, data));
        runCase("valid bait persistence", () -> testValidBaitPersistence(level, data));
        runCase("empty serializer defense", () -> testEmptySerializerDefense(level, data));
        runCase("malformed loaded-data defense", () -> testMalformedLoadedDataDefense(level));

        data.getBaitStorage().clear();
        data.setDirty();
        writeResult();
        server.halt(false);
    }

    private void testUnbaitedHookSave(ServerLevel level, BaitPreserveSavedData data) {
        data.getBaitStorage().clear();
        FishingHook hook = new FishingHook(testPlayer(level), level, 0, 0);

        hook.save(new CompoundTag());

        assertTrue(data.getBaitStorage().isEmpty(), "unbaited hook inserted ItemStack.EMPTY");
    }

    private void testValidBaitPersistence(ServerLevel level, BaitPreserveSavedData data) {
        data.getBaitStorage().clear();
        FishingHook hook = new FishingHook(testPlayer(level), level, 0, 0);
        ((FishingHookBait) hook).fishofthieves$setBaitStack(new ItemStack(Items.COD));

        hook.save(new CompoundTag());

        assertEquals(1, data.getBaitStorage().size(), "valid hook bait was not preserved");
        CompoundTag saved = data.save(new CompoundTag(), level.registryAccess());
        assertEquals(1, saved.getList("bait_preserves", CompoundTag.TAG_COMPOUND).size(), "valid bait was not serialized");
    }

    private void testEmptySerializerDefense(ServerLevel level, BaitPreserveSavedData data) {
        data.getBaitStorage().clear();
        ItemStack consumedBait = new ItemStack(Items.COD);
        data.getBaitStorage().put(new Vec3(10.0, 64.0, 10.0), consumedBait);
        consumedBait.shrink(1);
        assertEquals(1, data.getBaitStorage().size(), "test bait was not retained by reference");

        CompoundTag saved = data.save(new CompoundTag(), level.registryAccess());

        assertTrue(data.getBaitStorage().isEmpty(), "empty bait remained in runtime storage");
        assertTrue(!saved.contains("bait_preserves"), "empty bait was written to saved data");
    }

    private void testMalformedLoadedDataDefense(ServerLevel level) {
        CompoundTag malformedEntry = new CompoundTag();
        malformedEntry.putDouble("x", 20.0);
        malformedEntry.putDouble("y", 64.0);
        malformedEntry.putDouble("z", 20.0);
        malformedEntry.put("item", new CompoundTag());

        ListTag entries = new ListTag();
        entries.add(malformedEntry);
        CompoundTag root = new CompoundTag();
        root.put("bait_preserves", entries);

        BaitPreserveSavedData loaded = BaitPreserveSavedData.load(root, level.registryAccess());

        assertTrue(loaded.getBaitStorage().isEmpty(), "malformed loaded bait was retained");
    }

    private static FakePlayer testPlayer(ServerLevel level) {
        return FakePlayerFactory.getMinecraft(level);
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
            report.add(failures == 0 ? "PASS fish-of-thieves" : "FAIL fish-of-thieves (" + failures + ")");
            report.addAll(results);
            Files.write(RESULT_PATH, report, StandardCharsets.UTF_8);
        } catch (Exception error) {
            throw new RuntimeException("failed to write Fish of Thieves test result", error);
        }
    }

    private static void assertTrue(boolean value, String message) {
        if (!value) {
            throw new AssertionError(message);
        }
    }

    private static void assertEquals(int expected, int actual, String message) {
        if (expected != actual) {
            throw new AssertionError(message + " (expected " + expected + ", got " + actual + ")");
        }
    }

    @FunctionalInterface
    private interface ThrowingRunnable {
        void run() throws Exception;
    }
}
