package io.github.usersina.mcfantasy.printingpresscompat.mixin;

import io.github.usersina.mcfantasy.printingpresscompat.PrintingPressBookData;
import net.minecraft.world.item.ItemStack;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(targets = "com.glowbrick.printingpress.block.entity.block.TypesetterBlockEntity$1", remap = false)
public abstract class TypesetterItemHandlerMixin {
    @Inject(
            method = "isItemValid(ILnet/minecraft/world/item/ItemStack;)Z",
            at = @At("HEAD"),
            cancellable = true,
            remap = false
    )
    private void fantasyPack$allowTaggedBooks(
            int slot,
            ItemStack stack,
            CallbackInfoReturnable<Boolean> cir
    ) {
        if (slot == 0 && PrintingPressBookData.isCopyable(stack)) {
            cir.setReturnValue(true);
        }
    }
}
