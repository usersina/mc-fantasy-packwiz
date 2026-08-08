package io.github.usersina.mcfantasy.printingpresscompat.mixin;

import com.glowbrick.printingpress.block.entity.block.PrintingPressBlockEntity;
import com.glowbrick.printingpress.item.ModItems;
import io.github.usersina.mcfantasy.printingpresscompat.PrintingPressBookData;
import net.minecraft.world.Containers;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.Level;
import net.neoforged.neoforge.items.ItemStackHandler;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(value = PrintingPressBlockEntity.class, remap = false)
public abstract class PrintingPressBlockEntityMixin {
    private static final int BLANK_BOOK_SLOT = 0;
    private static final int TYPE_BLOCK_SLOT = 1;
    private static final int OUTPUT_SLOT = 3;
    private static final int INK_PER_BOTTLE = 200;
    private static final int CUSTOM_BOOK_INK_COST = 1000;
    private static final int NORMAL_INK_MODE = 1;
    private static final int CUSTOM_MAGIC_INK_MODE = 2;

    @Shadow
    @Final
    public ItemStackHandler itemHandler;

    @Shadow
    private int inkLevel;

    @Shadow
    private int currentInkMode;

    @Inject(method = "hasRecipe()Z", at = @At("HEAD"), cancellable = true, remap = false)
    private void fantasyPack$recognizeCopiedBook(CallbackInfoReturnable<Boolean> cir) {
        PrintingPressBlockEntity self = (PrintingPressBlockEntity) (Object) this;
        ItemStack typeBlock = itemHandler.getStackInSlot(TYPE_BLOCK_SLOT);
        if (!PrintingPressBookData.hasCopiedBook(typeBlock)) {
            return;
        }

        if (self.getLevel() == null) {
            cir.setReturnValue(false);
            return;
        }

        ItemStack output = PrintingPressBookData.readCopiedBook(
                typeBlock,
                self.getLevel().registryAccess()
        );
        ItemStack existing = itemHandler.getStackInSlot(OUTPUT_SLOT);
        boolean outputAcceptsCopy = existing.isEmpty()
                || ItemStack.isSameItemSameComponents(existing, output)
                && existing.getCount() < existing.getMaxStackSize();

        cir.setReturnValue(
                !output.isEmpty()
                        && currentInkMode == CUSTOM_MAGIC_INK_MODE
                        && inkLevel >= CUSTOM_BOOK_INK_COST
                        && itemHandler.getStackInSlot(BLANK_BOOK_SLOT).is(Items.BOOK)
                        && outputAcceptsCopy
        );
    }

    @Inject(method = "craftItem()V", at = @At("HEAD"), cancellable = true, remap = false)
    private void fantasyPack$printCopiedBook(CallbackInfo ci) {
        PrintingPressBlockEntity self = (PrintingPressBlockEntity) (Object) this;
        ItemStack typeBlock = itemHandler.getStackInSlot(TYPE_BLOCK_SLOT);
        if (!PrintingPressBookData.hasCopiedBook(typeBlock) || self.getLevel() == null) {
            return;
        }

        ItemStack output = PrintingPressBookData.readCopiedBook(
                typeBlock,
                self.getLevel().registryAccess()
        );
        if (output.isEmpty()) {
            ci.cancel();
            return;
        }

        ItemStack existing = itemHandler.getStackInSlot(OUTPUT_SLOT);
        if (existing.isEmpty()) {
            itemHandler.setStackInSlot(OUTPUT_SLOT, output);
        } else {
            existing.grow(1);
            itemHandler.setStackInSlot(OUTPUT_SLOT, existing);
        }

        inkLevel -= CUSTOM_BOOK_INK_COST;
        itemHandler.extractItem(BLANK_BOOK_SLOT, 1, false);
        ci.cancel();
    }

    @Inject(method = "drops()V", at = @At("TAIL"), remap = false)
    private void fantasyPack$dropStoredInk(CallbackInfo ci) {
        PrintingPressBlockEntity self = (PrintingPressBlockEntity) (Object) this;
        Level level = self.getLevel();
        if (level == null || level.isClientSide() || inkLevel < INK_PER_BOTTLE) {
            return;
        }

        int bottles = inkLevel / INK_PER_BOTTLE;
        ItemStack drop;
        if (currentInkMode == CUSTOM_MAGIC_INK_MODE) {
            drop = new ItemStack(ModItems.MAGIC_INK_BOTTLE.get(), bottles);
        } else if (currentInkMode == NORMAL_INK_MODE) {
            drop = new ItemStack(ModItems.INK_BOTTLE.get(), bottles);
        } else {
            return;
        }

        Containers.dropItemStack(
                level,
                self.getBlockPos().getX() + 0.5,
                self.getBlockPos().getY() + 0.5,
                self.getBlockPos().getZ() + 0.5,
                drop
        );
        inkLevel = 0;
        currentInkMode = 0;
        self.setChanged();
    }
}
