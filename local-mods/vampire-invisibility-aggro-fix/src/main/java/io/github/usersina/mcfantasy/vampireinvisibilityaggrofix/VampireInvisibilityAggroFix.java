package io.github.usersina.mcfantasy.vampireinvisibilityaggrofix;

import de.teamlapen.vampirism.api.VampirismAttachments;
import de.teamlapen.vampirism.entity.player.vampire.actions.VampireActions;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.NeutralMob;
import net.minecraft.world.entity.ai.memory.MemoryModuleType;
import net.minecraft.world.entity.player.Player;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.attachment.IAttachmentHolder;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.entity.living.LivingChangeTargetEvent;
import net.neoforged.neoforge.event.entity.living.LivingEvent;
import net.neoforged.neoforge.event.tick.EntityTickEvent;

@Mod(VampireInvisibilityAggroFix.MOD_ID)
public final class VampireInvisibilityAggroFix {
    public static final String MOD_ID = "vampire_invisibility_aggro_fix";

    public VampireInvisibilityAggroFix(IEventBus modEventBus) {
        NeoForge.EVENT_BUS.register(this);
    }

    @SubscribeEvent
    public void onVisibility(LivingEvent.LivingVisibilityEvent event) {
        if (event.getLookingEntity() instanceof Mob && hasVampireInvisibilityAction(event.getEntity())) {
            event.modifyVisibility(0.01D);
        }
    }

    @SubscribeEvent
    public void onChangeTarget(LivingChangeTargetEvent event) {
        if (!(event.getEntity() instanceof Mob mob) || mob.level().isClientSide()) {
            return;
        }

        LivingEntity target = event.getNewAboutToBeSetTarget();
        if (hasVampireInvisibilityAction(target)) {
            event.setCanceled(true);
            event.setNewAboutToBeSetTarget(null);
            clearAggro(mob, target);
        }
    }

    @SubscribeEvent
    public void onMobTick(EntityTickEvent.Post event) {
        if (!(event.getEntity() instanceof Mob mob) || mob.level().isClientSide()) {
            return;
        }

        LivingEntity target = mob.getTarget();
        if (hasVampireInvisibilityAction(target)) {
            clearAggro(mob, target);
        }
    }

    private static boolean hasVampireInvisibilityAction(LivingEntity entity) {
        if (!(entity instanceof Player player) || !player.isInvisible()) {
            return false;
        }

        return ((IAttachmentHolder) player).getData(VampirismAttachments.VAMPIRE_PLAYER)
                .getActionHandler()
                .isActionActive(VampireActions.VAMPIRE_INVISIBILITY.get());
    }

    private static void clearAggro(Mob mob, LivingEntity target) {
        if (mob.getTarget() == target) {
            mob.setTarget(null);
        }

        mob.getNavigation().stop();
        mob.setAggressive(false);
        mob.setLastHurtByMob(null);
        mob.getBrain().eraseMemory(MemoryModuleType.ATTACK_TARGET);

        if (mob instanceof NeutralMob neutralMob) {
            neutralMob.stopBeingAngry();
        }
    }
}
