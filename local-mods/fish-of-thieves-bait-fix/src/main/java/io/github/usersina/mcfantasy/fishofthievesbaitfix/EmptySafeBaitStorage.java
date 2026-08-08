package io.github.usersina.mcfantasy.fishofthievesbaitfix;

import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.Vec3;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public final class EmptySafeBaitStorage extends ConcurrentHashMap<Vec3, ItemStack> {
    public EmptySafeBaitStorage(Map<Vec3, ItemStack> source) {
        putAll(source);
    }

    @Override
    public ItemStack put(Vec3 position, ItemStack bait) {
        if (isEmptyBait(bait)) {
            return get(position);
        }
        return super.put(position, bait);
    }

    @Override
    public ItemStack putIfAbsent(Vec3 position, ItemStack bait) {
        if (isEmptyBait(bait)) {
            return get(position);
        }
        return super.putIfAbsent(position, bait);
    }

    @Override
    public void putAll(Map<? extends Vec3, ? extends ItemStack> entries) {
        entries.forEach(this::put);
    }

    private static boolean isEmptyBait(ItemStack bait) {
        return bait == null || bait.isEmpty();
    }
}
