const REPRESENTATIVE_RITUAL_BASE = 'vampirism:totem_base'
const REPRESENTATIVE_RITUAL_TOPS = [
  'vampirism:totem_top_crafted',
  'vampirism:totem_top_vampirism_vampire_crafted',
  'vampirism:totem_top_vampirism_hunter_crafted'
]

function isRepresentativeOffering(itemId) {
  return itemId == 'vampirism:vampire_blood_bottle' || itemId == 'vampirism:hunter_intel' || /^vampirism:hunter_intel_[0-9]$/.test(itemId)
}

function isRepresentativeRitualGesture(event) {
  return String(event.hand) == 'MAIN_HAND' && event.player.isShiftKeyDown() && isRepresentativeOffering(String(event.item.id))
}

function isRepresentativeRitualBlock(blockId) {
  return blockId == REPRESENTATIVE_RITUAL_BASE || REPRESENTATIVE_RITUAL_TOPS.includes(blockId)
}

BlockEvents.rightClicked(event => {
  if (!isRepresentativeRitualGesture(event)) return
  if (!isRepresentativeRitualBlock(String(event.block.id))) return

  event.cancel()
})

ItemEvents.rightClicked(event => {
  if (!isRepresentativeRitualGesture(event)) return

  const target = event.target
  if (target == null || target.block == null) return
  if (!isRepresentativeRitualBlock(String(target.block.id))) return

  event.cancel()
})
