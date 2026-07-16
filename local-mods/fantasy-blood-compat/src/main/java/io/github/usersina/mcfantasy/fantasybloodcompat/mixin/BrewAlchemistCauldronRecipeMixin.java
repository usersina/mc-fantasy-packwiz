package io.github.usersina.mcfantasy.fantasybloodcompat.mixin;

import io.redspace.ironsspellbooks.recipe_types.alchemist_cauldron.BrewAlchemistCauldronRecipe;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.tags.TagKey;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.material.Fluid;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(value = BrewAlchemistCauldronRecipe.class, remap = false)
public abstract class BrewAlchemistCauldronRecipeMixin {
    private static final TagKey<Fluid> CLEAN_BLOOD = TagKey.create(
            Registries.FLUID,
            ResourceLocation.fromNamespaceAndPath("fantasy_pack", "clean_blood")
    );

    @Inject(
            method = "matches(Lio/redspace/ironsspellbooks/recipe_types/alchemist_cauldron/BrewAlchemistCauldronRecipe$Input;Lnet/minecraft/world/level/Level;)Z",
            at = @At("HEAD"),
            cancellable = true,
            remap = false
    )
    private void fantasyPack$matchEquivalentCleanBlood(
            BrewAlchemistCauldronRecipe.Input input,
            Level level,
            CallbackInfoReturnable<Boolean> cir
    ) {
        BrewAlchemistCauldronRecipe recipe = (BrewAlchemistCauldronRecipe) (Object) this;
        if (recipe.fluidIn().is(CLEAN_BLOOD) && input.fluidIn().is(CLEAN_BLOOD)) {
            cir.setReturnValue(recipe.reagent().test(input.reagent()));
        }
    }
}
