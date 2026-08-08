package io.github.usersina.mcfantasy.printingpresscompat;

import net.minecraft.core.HolderLookup;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.Tag;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.tags.TagKey;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.component.CustomData;

public final class PrintingPressBookData {
    public static final TagKey<Item> COPYABLE_BOOKS = TagKey.create(
            Registries.ITEM,
            ResourceLocation.fromNamespaceAndPath(PrintingPressCompat.MOD_ID, "copyable_books")
    );

    private static final String COPIED_BOOK_KEY = "printing_press_compat.copied_book";

    private PrintingPressBookData() {
    }

    public static boolean isCopyable(ItemStack stack) {
        return !stack.isEmpty() && stack.is(COPYABLE_BOOKS);
    }

    public static boolean hasCopiedBook(ItemStack typeBlock) {
        CustomData data = typeBlock.get(DataComponents.CUSTOM_DATA);
        return data != null && data.copyTag().contains(COPIED_BOOK_KEY, Tag.TAG_COMPOUND);
    }

    public static void storeCopiedBook(
            ItemStack typeBlock,
            ItemStack source,
            HolderLookup.Provider registries
    ) {
        ItemStack template = source.copyWithCount(1);
        CustomData.update(DataComponents.CUSTOM_DATA, typeBlock, tag ->
                tag.put(COPIED_BOOK_KEY, template.save(registries))
        );
        typeBlock.set(
                DataComponents.CUSTOM_NAME,
                Component.translatable("item.printing_press_compat.type_block_for", template.getHoverName())
        );
    }

    public static ItemStack readCopiedBook(
            ItemStack typeBlock,
            HolderLookup.Provider registries
    ) {
        CustomData data = typeBlock.get(DataComponents.CUSTOM_DATA);
        if (data == null) {
            return ItemStack.EMPTY;
        }

        CompoundTag tag = data.copyTag();
        if (!tag.contains(COPIED_BOOK_KEY, Tag.TAG_COMPOUND)) {
            return ItemStack.EMPTY;
        }

        return ItemStack.parse(registries, tag.get(COPIED_BOOK_KEY))
                .map(stack -> stack.copyWithCount(1))
                .orElse(ItemStack.EMPTY);
    }
}
