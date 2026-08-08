package io.github.usersina.mcfantasy.printingpresscompat.mixin;

import com.glowbrick.printingpress.block.entity.block.TypesetterBlockEntity;
import com.glowbrick.printingpress.item.ModItems;
import io.github.usersina.mcfantasy.printingpresscompat.PrintingPressBookData;
import net.minecraft.world.item.ItemStack;
import net.neoforged.neoforge.items.ItemStackHandler;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(value = TypesetterBlockEntity.class, remap = false)
public abstract class TypesetterBlockEntityMixin {
    private static final int SOURCE_SLOT = 0;
    private static final int MOVABLE_TYPE_SLOT = 1;
    private static final int OUTPUT_SLOT = 2;

    @Shadow
    @Final
    public ItemStackHandler itemHandler;

    @Inject(method = "hasRecipe()Z", at = @At("HEAD"), cancellable = true, remap = false)
    private void fantasyPack$recognizeTaggedBooks(CallbackInfoReturnable<Boolean> cir) {
        ItemStack source = itemHandler.getStackInSlot(SOURCE_SLOT);
        if (!PrintingPressBookData.isCopyable(source)) {
            return;
        }

        cir.setReturnValue(
                itemHandler.getStackInSlot(MOVABLE_TYPE_SLOT).is(ModItems.MOVABLE_TYPE.get())
                        && itemHandler.getStackInSlot(OUTPUT_SLOT).isEmpty()
        );
    }

    @Inject(method = "craftItem()V", at = @At("HEAD"), cancellable = true, remap = false)
    private void fantasyPack$captureTaggedBook(CallbackInfo ci) {
        ItemStack source = itemHandler.getStackInSlot(SOURCE_SLOT);
        if (!PrintingPressBookData.isCopyable(source)) {
            return;
        }

        TypesetterBlockEntity self = (TypesetterBlockEntity) (Object) this;
        if (self.getLevel() == null) {
            ci.cancel();
            return;
        }

        ItemStack typeBlock = new ItemStack(ModItems.TYPE_BLOCK.get());
        PrintingPressBookData.storeCopiedBook(typeBlock, source, self.getLevel().registryAccess());
        itemHandler.setStackInSlot(OUTPUT_SLOT, typeBlock);
        itemHandler.extractItem(MOVABLE_TYPE_SLOT, 1, false);
        ci.cancel();
    }
}
