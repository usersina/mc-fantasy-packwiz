package io.github.usersina.mcfantasy.tests.umbrellainfuser;

import fuzs.enchantinginfuser.config.AllowedRepairItems;
import fuzs.enchantinginfuser.world.level.block.InfuserType;
import net.minecraft.core.Holder;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.enchantment.Enchantment;
import net.minecraft.world.item.enchantment.Enchantments;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.common.Tags;
import net.neoforged.neoforge.event.server.ServerStartedEvent;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

@Mod(UmbrellaInfuserIntegrationTests.MOD_ID)
public final class UmbrellaInfuserIntegrationTests {
    public static final String MOD_ID = "fantasy_pack_umbrella_infuser_tests";
    private static final Path RESULT_PATH = Path.of("fantasy-pack-tests", "umbrella-infuser.txt");

    private final List<String> results = new ArrayList<>();
    private int failures;

    public UmbrellaInfuserIntegrationTests(IEventBus modEventBus) {
        NeoForge.EVENT_BUS.addListener(this::onServerStarted);
    }

    private void onServerStarted(ServerStartedEvent event) {
        MinecraftServer server = event.getServer();

        runCase("normal Infuser enchantability", () -> testNormalEnchantability(server));
        runCase("Advanced Infuser repair", this::testAdvancedRepair);
        runCase("Normal Infuser repair remains disabled", this::testNormalRepairPolicy);

        writeResult();
        server.halt(false);
    }

    private void testNormalEnchantability(MinecraftServer server) {
        ItemStack umbrella = umbrella();
        Holder<Enchantment> unbreaking = server.registryAccess()
                .lookupOrThrow(Registries.ENCHANTMENT)
                .getOrThrow(Enchantments.UNBREAKING);
        Holder<Enchantment> mending = server.registryAccess()
                .lookupOrThrow(Registries.ENCHANTMENT)
                .getOrThrow(Enchantments.MENDING);

        assertTrue(umbrella.isPrimaryItemFor(unbreaking), "Normal Infuser cannot offer Unbreaking");
        assertTrue(unbreaking.is(InfuserType.NORMAL.getAvailableEnchantments()), "Unbreaking missing from Normal Infuser");
        assertTrue(umbrella.supportsEnchantment(mending), "umbrella no longer supports Mending books");
    }

    private void testAdvancedRepair() {
        ItemStack umbrella = damagedUmbrella();

        assertTrue(umbrella.is(Tags.Items.TOOLS), "umbrella missing from c:tools");
        assertTrue(
                AllowedRepairItems.TOOLS_AND_ARMOR.canRepair(umbrella),
                "Advanced Infuser rejected the damaged umbrella"
        );
    }

    private void testNormalRepairPolicy() {
        assertFalse(
                AllowedRepairItems.NOTHING.canRepair(damagedUmbrella()),
                "Normal Infuser unexpectedly gained general repair behavior"
        );
    }

    private static ItemStack umbrella() {
        Item item = BuiltInRegistries.ITEM.get(ResourceLocation.parse("vampiresneedumbrellas:red_iron_umbrella"));
        if (item == Items.AIR) {
            throw new AssertionError("red iron umbrella is missing");
        }
        return new ItemStack(item);
    }

    private static ItemStack damagedUmbrella() {
        ItemStack umbrella = umbrella();
        umbrella.setDamageValue(Math.max(1, umbrella.getMaxDamage() / 2));
        assertTrue(umbrella.isDamaged(), "umbrella could not be damaged for repair test");
        return umbrella;
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
            report.add(failures == 0 ? "PASS umbrella-infuser" : "FAIL umbrella-infuser (" + failures + ")");
            report.addAll(results);
            Files.write(RESULT_PATH, report, StandardCharsets.UTF_8);
        } catch (Exception error) {
            throw new RuntimeException("failed to write umbrella Infuser test result", error);
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

    @FunctionalInterface
    private interface ThrowingRunnable {
        void run() throws Exception;
    }
}
