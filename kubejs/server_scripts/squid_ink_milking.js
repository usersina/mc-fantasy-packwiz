const SquidMilkingSoundEvents = Java.loadClass('net.minecraft.sounds.SoundEvents')

const SQUID_MILKING_COOLDOWN_TICKS = 5 * 60 * 20
const SQUID_MILKING_READY_TICK = 'fantasy_pack_squid_milking_ready_tick'

const SQUID_MILKING_REWARDS = {
  'minecraft:squid': {
    item: 'minecraft:ink_sac',
    count: 4,
    sound: SquidMilkingSoundEvents.SQUID_SQUIRT,
    name: 'squid',
  },
  'minecraft:glow_squid': {
    item: 'minecraft:glow_ink_sac',
    count: 2,
    sound: SquidMilkingSoundEvents.GLOW_SQUID_SQUIRT,
    name: 'glow squid',
  },
}

function squidMilkingCooldownMessage(remainingTicks) {
  const seconds = Math.ceil(remainingTicks / 20)
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = seconds % 60

  if (minutes <= 0) {
    return `This squid needs ${remainingSeconds} more seconds to replenish its ink.`
  }

  if (remainingSeconds == 0) {
    return `This squid needs ${minutes} more minute${minutes == 1 ? '' : 's'} to replenish its ink.`
  }

  return `This squid needs ${minutes}m ${remainingSeconds}s to replenish its ink.`
}

ItemEvents.entityInteracted((event) => {
  if (String(event.hand) != 'MAIN_HAND') return
  if (String(event.item.id) != 'minecraft:bucket') return

  const target = event.target
  if (target == null) return

  const reward = SQUID_MILKING_REWARDS[String(target.type)]
  if (reward == null) return

  const now = Number(target.level.getGameTime())
  const readyAt = Number(target.persistentData.getLong(SQUID_MILKING_READY_TICK))
  if (readyAt > now) {
    event.player.tell(squidMilkingCooldownMessage(readyAt - now))
    event.cancel()
    return
  }

  target.persistentData.putLong(
    SQUID_MILKING_READY_TICK,
    now + SQUID_MILKING_COOLDOWN_TICKS
  )
  event.player.give(Item.of(reward.item, reward.count))
  target.playSound(reward.sound, 1.0, 1.0)
  event.player.tell(
    `Collected ${reward.count} ${reward.count == 1 ? 'ink sac' : 'ink sacs'} from the ${reward.name}.`
  )
  event.cancel()
})
