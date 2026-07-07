const REPRESENTATIVE_TAG = 'fantasy_pack_representative'
const REPRESENTATIVE_RADIUS = 12
const TOTEM_BASE = 'vampirism:totem_base'
const MISSING_TOP_MESSAGE =
  'Place a crafted Vampirism Village Totem Top directly above the base first.'
const CLICK_BASE_MESSAGE = 'Sneak-right-click the totem base, not the top.'

const RITUAL_TOPS = [
  'vampirism:totem_top_crafted',
  'vampirism:totem_top_vampirism_vampire_crafted',
  'vampirism:totem_top_vampirism_hunter_crafted',
]

const HORIZONTAL_OFFSETS = {
  north: { x: 0, z: -1 },
  south: { x: 0, z: 1 },
  west: { x: -1, z: 0 },
  east: { x: 1, z: 0 },
}

const REPRESENTATIVES = {
  vampire: {
    entity: 'vampirism:task_master_vampire',
    name: 'Vampire Representative',
    success: 'A vampire representative answers the totem.',
    duplicate: 'A vampire representative is already near this totem.',
  },
  hunter: {
    entity: 'vampirism:task_master_hunter',
    name: 'Hunter Representative',
    success: 'A hunter representative answers the totem.',
    duplicate: 'A hunter representative is already near this totem.',
  },
}

function representativeForOffering(itemId) {
  if (itemId == 'vampirism:vampire_blood_bottle') {
    return REPRESENTATIVES.vampire
  }

  if (/^vampirism:hunter_intel_[0-9]$/.test(itemId)) {
    return REPRESENTATIVES.hunter
  }

  return null
}

function hasNearbyRepresentative(event, representative, x, y, z) {
  const nearbyEntities = event.block.level.entities.filterDistance(
    x,
    y,
    z,
    REPRESENTATIVE_RADIUS
  )

  for (const entity of nearbyEntities) {
    if (
      String(entity.type) == representative.entity &&
      entity.tags.contains(REPRESENTATIVE_TAG)
    ) {
      return true
    }
  }

  return false
}

function hasCraftedTotemTop(event) {
  return RITUAL_TOPS.includes(String(event.block.up.id))
}

function isRitualTop(blockId) {
  return RITUAL_TOPS.includes(blockId)
}

function isRitualBlock(blockId) {
  return blockId == TOTEM_BASE || isRitualTop(blockId)
}

function spawnOffsetFor(event) {
  const facing = String(event.facing || '').toLowerCase()
  if (HORIZONTAL_OFFSETS[facing] != null) {
    return HORIZONTAL_OFFSETS[facing]
  }

  const dxToPlayer = event.player.getX() - (event.block.x + 0.5)
  const dzToPlayer = event.player.getZ() - (event.block.z + 0.5)

  if (Math.abs(dxToPlayer) >= Math.abs(dzToPlayer)) {
    return dxToPlayer >= 0 ? HORIZONTAL_OFFSETS.east : HORIZONTAL_OFFSETS.west
  }

  return dzToPlayer >= 0 ? HORIZONTAL_OFFSETS.south : HORIZONTAL_OFFSETS.north
}

function summonRepresentative(event, representative) {
  if (!hasCraftedTotemTop(event)) {
    event.player.tell(MISSING_TOP_MESSAGE)
    event.cancel()
    return
  }

  const offset = spawnOffsetFor(event)
  const x = event.block.x + 0.5 + offset.x
  const y = event.block.y
  const z = event.block.z + 0.5 + offset.z

  if (hasNearbyRepresentative(event, representative, x, y, z)) {
    event.player.tell(representative.duplicate)
    event.cancel()
    return
  }

  event.item.count--
  event.server.runCommandSilent(
    `execute in ${event.block.dimension} positioned ${x} ${y} ${z} run summon ${representative.entity} ~ ~ ~ {PersistenceRequired:1b,Invulnerable:1b,NoAI:1b,Tags:["${REPRESENTATIVE_TAG}"],CustomName:'{"text":"${representative.name}"}'}`
  )
  event.player.tell(representative.success)
  event.cancel()
}

BlockEvents.rightClicked((event) => {
  if (String(event.hand) != 'MAIN_HAND') return
  if (!event.player.isShiftKeyDown()) return

  const representative = representativeForOffering(String(event.item.id))
  if (representative == null) return

  const blockId = String(event.block.id)
  if (blockId != TOTEM_BASE) {
    if (isRitualTop(blockId)) {
      event.player.tell(CLICK_BASE_MESSAGE)
      event.cancel()
    }
    return
  }

  summonRepresentative(event, representative)
})

ItemEvents.rightClicked((event) => {
  if (String(event.hand) != 'MAIN_HAND') return
  if (!event.player.isShiftKeyDown()) return

  const representative = representativeForOffering(String(event.item.id))
  if (representative == null) return

  const target = event.target
  if (target == null || target.block == null) return
  if (!isRitualBlock(String(target.block.id))) return

  event.cancel()
})
