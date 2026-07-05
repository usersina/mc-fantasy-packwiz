const REPRESENTATIVE_TAG = 'fantasy_pack_representative'
const REPRESENTATIVE_RADIUS = 12

const RITUAL_BLOCKS = [
  'vampirism:totem_top_crafted',
  'vampirism:totem_top_vampirism_vampire_crafted',
  'vampirism:totem_top_vampirism_hunter_crafted'
]

const REPRESENTATIVES = {
  vampire: {
    entity: 'vampirism:task_master_vampire',
    name: 'Vampire Representative',
    success: 'A vampire representative answers the totem.',
    duplicate: 'A vampire representative is already near this totem.'
  },
  hunter: {
    entity: 'vampirism:task_master_hunter',
    name: 'Hunter Representative',
    success: 'A hunter representative answers the totem.',
    duplicate: 'A hunter representative is already near this totem.'
  }
}

function representativeForOffering(itemId) {
  if (itemId == 'vampirism:vampire_blood_bottle') {
    return REPRESENTATIVES.vampire
  }

  if (itemId == 'vampirism:hunter_intel' || /^vampirism:hunter_intel_[0-9]$/.test(itemId)) {
    return REPRESENTATIVES.hunter
  }

  return null
}

function hasNearbyRepresentative(event, representative, x, y, z) {
  const nearbyEntities = event.block.level.entities.filterDistance(x, y, z, REPRESENTATIVE_RADIUS)

  for (const entity of nearbyEntities) {
    if (String(entity.type) == representative.entity && entity.tags.contains(REPRESENTATIVE_TAG)) {
      return true
    }
  }

  return false
}

function summonRepresentative(event, representative) {
  const x = event.block.x + 0.5
  const y = event.block.y + 1
  const z = event.block.z + 0.5

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

BlockEvents.rightClicked(event => {
  if (String(event.hand) != 'MAIN_HAND') return
  if (!event.player.isShiftKeyDown()) return
  if (!RITUAL_BLOCKS.includes(String(event.block.id))) return

  const representative = representativeForOffering(String(event.item.id))
  if (representative == null) return

  summonRepresentative(event, representative)
})
