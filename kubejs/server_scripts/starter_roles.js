const STARTER_LOBBY_DIMENSION = 'fantasy_pack:starter_lobby'
const STARTER_OVERWORLD_DIMENSION = 'minecraft:overworld'
const STARTER_ROLE_KEY = 'fantasy_start_role'
const STARTER_LOBBY_SPAWN = { x: 0.5, y: 62, z: 0.5 }
const STARTER_PAD_HOLD_TICKS = 40

const StarterLobbyBlockPos = Java.loadClass('net.minecraft.core.BlockPos')
const StarterLobbyResourceLocation = Java.loadClass(
  'net.minecraft.resources.ResourceLocation'
)
const StarterLobbyBuiltInRegistries = Java.loadClass(
  'net.minecraft.core.registries.BuiltInRegistries'
)

let starterLobbyBuilt = false
let starterLobbyMissingLevelLogged = false
const starterPadHolds = {}
const starterLobbyModePlayers = {}
const starterRoleChoicesInProgress = {}

const STARTER_ROLES = {
  mage: {
    name: 'Mage Apprentice',
    label: ['Mage', 'Apprentice'],
    color: '#55FFFF',
    block: 'irons_spellbooks:arcane_anvil',
    display: { x: -10, z: -11 },
    pad: {
      x1: -10,
      x2: -10,
      z1: -10,
      z2: -10,
      floor: 'minecraft:light_blue_concrete',
      carpet: 'minecraft:light_blue_carpet',
    },
    grant(player, server) {
      equipArmor(server, player, {
        head: 'irons_spellbooks:wizard_helmet',
        chest: 'irons_spellbooks:wizard_chestplate',
        legs: 'irons_spellbooks:wizard_leggings',
        feet: 'irons_spellbooks:wizard_boots',
      })
      giveAll(player, [
        ['minecraft:bread', 16],
        ['minecraft:torch', 32],
        ['irons_spellbooks:arcane_essence', 16],
        ['irons_spellbooks:common_ink', 4],
      ])
      equipSpellbook(server, player, 'irons_spellbooks:gold_spell_book', 3, [
        ['irons_spellbooks:magic_missile', 1],
        ['irons_spellbooks:heal', 1],
        ['irons_spellbooks:shield', 1],
      ])
    },
  },
  vampire: {
    name: 'Vampire Fledgling',
    label: ['Vampire', 'Fledgling'],
    color: '#FF5555',
    block: 'vampirism:blood_pedestal',
    display: { x: -5, z: -11 },
    pad: {
      x1: -5,
      x2: -5,
      z1: -10,
      z2: -10,
      floor: 'minecraft:red_concrete',
      carpet: 'minecraft:red_carpet',
    },
    grant(player, server) {
      runForPlayer(server, player, 'vampirism level vampirism:vampire 4')
      runForPlayer(server, player, 'vampirism bloodBar fill')
      equipArmor(server, player, {
        head: 'vampirism:vampire_clothing_hat',
        chest: 'vampirism:vampire_cloak_black_red',
        legs: 'vampirism:vampire_clothing_legs',
        feet: 'vampirism:vampire_clothing_boots',
      })
      equipOffhand(server, player, 'vampiresneedumbrellas:red_iron_umbrella')
      giveAll(player, [
        ['vampirism:coffin_black', 1],
        ['vampirism:heart_seeker_normal', 1],
      ])
      giveItem(
        server,
        player,
        'vampirism:blood_bottle[vampirism:bottle_blood={blood:9}]',
        8
      )
      equipSpellbook(
        server,
        player,
        'irons_spellbooks:cursed_doll_spell_book',
        3,
        [
          ['irons_spellbooks:blood_step', 1],
          ['irons_spellbooks:ray_of_siphoning', 1],
          ['irons_spellbooks:devour', 1],
        ]
      )
    },
  },
  hunter: {
    name: 'Hunter Initiate',
    label: ['Hunter', 'Initiate'],
    color: '#FFAA00',
    block: 'vampirism:hunter_table',
    display: { x: 0, z: -11 },
    pad: {
      x1: 0,
      x2: 0,
      z1: -10,
      z2: -10,
      floor: 'minecraft:orange_concrete',
      carpet: 'minecraft:orange_carpet',
    },
    grant(player, server) {
      runForPlayer(server, player, 'vampirism level vampirism:hunter 4')
      equipArmor(server, player, {
        head: 'vampirism:hunter_coat_head_normal',
        chest: 'vampirism:hunter_coat_chest_normal',
        legs: 'vampirism:hunter_coat_legs_normal',
        feet: 'vampirism:hunter_coat_feet_normal',
      })
      giveAll(player, [
        ['vampirism:basic_crossbow', 1],
        ['vampirism:crossbow_arrow_normal', 48],
        ['vampirism:crossbow_arrow_vampire_killer', 8],
        ['vampirism:stake', 1],
        ['vampirism:hunter_axe_normal', 1],
        ['vampirism:hunter_intel_0', 1],
        ['minecraft:bread', 16],
        ['minecraft:torch', 32],
      ])
    },
  },
  werewolf: {
    name: 'Werewolf Initiate',
    label: ['Werewolf', 'Initiate'],
    color: '#AA5500',
    block: 'werewolves:stone_altar',
    display: { x: 5, z: -11 },
    pad: {
      x1: 5,
      x2: 5,
      z1: -10,
      z2: -10,
      floor: 'minecraft:brown_concrete',
      carpet: 'minecraft:brown_carpet',
    },
    grant(player, server) {
      runForPlayer(server, player, 'vampirism level werewolves:werewolf 4')
      equipArmor(server, player, {
        head: 'werewolves:pelt_helmet',
        chest: 'werewolves:pelt_chestplate',
        legs: 'werewolves:pelt_leggings',
        feet: 'werewolves:pelt_boots',
      })
      giveAll(player, [
        ['minecraft:iron_sword', 1],
        ['minecraft:iron_pickaxe', 1],
        ['minecraft:shield', 1],
        ['werewolves:bone_necklace', 1],
        ['werewolves:dream_catcher', 1],
        ['werewolves:wolf_berries', 24],
        ['werewolves:liver', 8],
        ['werewolves:werewolf_tooth', 2],
        ['minecraft:cooked_beef', 24],
        ['minecraft:torch', 32],
      ])
    },
  },
  explorer: {
    name: 'Explorer Pilot',
    label: ['Explorer', 'Pilot'],
    color: '#FFFF55',
    block: 'minecraft:cartography_table',
    display: { x: 10, z: -11 },
    pad: {
      x1: 10,
      x2: 10,
      z1: -10,
      z2: -10,
      floor: 'minecraft:yellow_concrete',
      carpet: 'minecraft:yellow_carpet',
    },
    grant(player, server) {
      equipArmor(server, player, {
        head: 'minecraft:leather_helmet',
        chest: 'minecraft:leather_chestplate',
        legs: 'minecraft:leather_leggings',
        feet: 'minecraft:leather_boots',
      })
      equipHotbar(server, player, [
        'minecraft:iron_sword',
        'minecraft:iron_pickaxe',
        'minecraft:iron_axe',
        'minecraft:iron_shovel',
      ])
      giveAll(player, [
        ['immersive_aircraft:airship', 1],
        ['minecraft:coal', 32],
        ['minecraft:compass', 1],
        ['minecraft:clock', 1],
        ['minecraft:map', 2],
        ['minecraft:spyglass', 1],
        ['minecraft:bread', 20],
        ['minecraft:torch', 48],
      ])
    },
  },
  vanilla: {
    name: 'Vanilla Start',
    label: ['Vanilla', 'Start'],
    color: '#55FF55',
    block: 'minecraft:grass_block',
    display: { x: 0, z: 11 },
    pad: {
      x1: 0,
      x2: 0,
      z1: 10,
      z2: 10,
      floor: 'minecraft:lime_concrete',
      carpet: 'minecraft:lime_carpet',
    },
    grant(player, server) {},
  },
}

const STARTER_ROLE_IDS = [
  'mage',
  'vampire',
  'hunter',
  'werewolf',
  'explorer',
  'vanilla',
]

function playerTarget(player) {
  return String(player.username)
}

function runForPlayer(server, player, commandPrefix) {
  runStarterCommand(
    server,
    `${commandPrefix} ${playerTarget(player)}`,
    commandPrefix
  )
}

function tellraw(player, message) {
  runStarterCommand(
    player.server,
    `tellraw ${playerTarget(player)} ${JSON.stringify(message)}`,
    'tellraw'
  )
}

function starterPrefix() {
  return [
    { text: '[', color: 'dark_gray' },
    { text: 'Fantasy Pack', color: '#C77DFF', bold: true },
    { text: '] ', color: 'dark_gray' },
  ]
}

function roleNameComponent(role) {
  return { text: role.name, color: role.color, bold: true }
}

function starterLine(extra) {
  const message = starterPrefix()
  for (const part of extra) {
    message.push(part)
  }
  return message
}

function giveAll(player, entries) {
  for (const entry of entries) {
    if (
      !validateStarterItem(
        entry[0],
        `give starter item to ${playerTarget(player)}`
      )
    ) {
      continue
    }

    try {
      player.give(Item.of(entry[0], entry[1]))
    } catch (error) {
      console.error(
        `[Fantasy Pack] Failed to give starter item ${entry[0]} x${entry[1]} to ${playerTarget(player)}.`
      )
      console.error(error)
    }
  }
}

function giveItem(server, player, itemSpec, count) {
  if (
    !validateStarterItem(
      itemSpec,
      `give ${itemSpec} to ${playerTarget(player)}`
    )
  ) {
    return
  }

  runStarterCommand(
    server,
    `give ${playerTarget(player)} ${itemSpec} ${count}`,
    `give ${itemSpec}`
  )
}

function equipArmor(server, player, armor) {
  const target = playerTarget(player)
  for (const slot in armor) {
    if (
      !validateStarterItem(armor[slot], `equip armor.${slot} for ${target}`)
    ) {
      continue
    }

    runStarterCommand(
      server,
      `item replace entity ${target} armor.${slot} with ${armor[slot]}`,
      `equip armor.${slot}`
    )
  }
}

function equipOffhand(server, player, itemId) {
  if (
    !validateStarterItem(itemId, `equip offhand for ${playerTarget(player)}`)
  ) {
    return
  }

  runStarterCommand(
    server,
    `item replace entity ${playerTarget(player)} weapon.offhand with ${itemId}`,
    'equip offhand'
  )
}

function equipHotbar(server, player, itemIds) {
  const target = playerTarget(player)
  for (let i = 0; i < itemIds.length; i++) {
    if (!validateStarterItem(itemIds[i], `equip hotbar.${i} for ${target}`)) {
      continue
    }

    runStarterCommand(
      server,
      `item replace entity ${target} hotbar.${i} with ${itemIds[i]}`,
      `equip hotbar.${i}`
    )
  }
}

function spellbookComponent(maxSpells, spells) {
  const data = []
  for (let i = 0; i < spells.length; i++) {
    data.push(
      `{id:"${spells[i][0]}",index:${i},level:${spells[i][1]},locked:false}`
    )
  }

  return `{maxSpells:${maxSpells},spellWheel:true,mustEquip:true,improved:false,data:[${data.join(',')}]}`
}

function equipSpellbook(server, player, itemId, maxSpells, spells) {
  if (
    !validateStarterItem(itemId, `equip spellbook for ${playerTarget(player)}`)
  ) {
    return
  }

  runStarterCommand(
    server,
    `curios replace spellbook 0 ${playerTarget(player)} with ${itemId}[irons_spellbooks:spell_container=${spellbookComponent(maxSpells, spells)}] 1`,
    `equip spellbook ${itemId}`
  )
}

function itemIdFromSpec(itemSpec) {
  return String(itemSpec).split('[')[0]
}

function validateStarterItem(itemSpec, context) {
  const itemId = itemIdFromSpec(itemSpec)
  const id = StarterLobbyResourceLocation.parse(itemId)

  if (StarterLobbyBuiltInRegistries.ITEM.containsKey(id)) {
    return true
  }

  console.error(
    `[Fantasy Pack] Missing starter item ${itemId}; skipped ${context}.`
  )
  return false
}

function hasChosenStarterRole(player) {
  return player.persistentData.contains(STARTER_ROLE_KEY)
}

function setChosenStarterRole(player, roleId) {
  player.persistentData.putString(STARTER_ROLE_KEY, roleId)
}

function clearStarterPadHold(player) {
  delete starterPadHolds[playerTarget(player)]
}

function clearStarterObject(object) {
  for (const key in object) {
    delete object[key]
  }
}

function resetStarterLobbyState() {
  starterLobbyBuilt = false
  starterLobbyMissingLevelLogged = false
  clearStarterObject(starterPadHolds)
  clearStarterObject(starterLobbyModePlayers)
  clearStarterObject(starterRoleChoicesInProgress)
}

function runStarterCommand(server, command, description) {
  try {
    return server.runCommandSilent(command)
  } catch (error) {
    console.error(
      `[Fantasy Pack] Starter command failed (${description}): ${command}`
    )
    console.error(error)
    return 0
  }
}

function runInStarterLobby(server, command) {
  server.runCommandSilent(
    `execute in ${STARTER_LOBBY_DIMENSION} run ${command}`
  )
}

function runStarterLobbyCommand(server, command) {
  try {
    runInStarterLobby(server, command)
  } catch (error) {
    console.warn(`[Fantasy Pack] Failed starter lobby command: ${command}`)
    console.warn(error)
  }
}

function signMessage(text, color, bold) {
  return JSON.stringify({ text: text, color: color, bold: bold })
}

function signTextNbt(role) {
  const label = role.label || [role.name, '']
  return `{front_text:{has_glowing_text:1b,messages:['${signMessage(label[0], role.color, true)}','${signMessage(label[1], role.color, true)}','${signMessage('Stand on', 'gray', false)}','${signMessage('the pad', 'gray', false)}']}}`
}

function starterLobbyLevel(server) {
  return server.getLevel(
    StarterLobbyResourceLocation.parse(STARTER_LOBBY_DIMENSION)
  )
}

function blockState(blockId) {
  const id = StarterLobbyResourceLocation.parse(blockId)
  if (!StarterLobbyBuiltInRegistries.BLOCK.containsKey(id)) {
    throw new Error(
      `[Fantasy Pack] Missing starter lobby block in registry: ${blockId}`
    )
  }

  return StarterLobbyBuiltInRegistries.BLOCK.get(id).defaultBlockState()
}

function setStarterBlock(level, x, y, z, blockId) {
  level.setBlock(new StarterLobbyBlockPos(x, y, z), blockState(blockId), 3)
}

function fillStarterRegion(level, x1, y1, z1, x2, y2, z2, blockId) {
  const state = blockState(blockId)
  const minX = Math.min(x1, x2)
  const maxX = Math.max(x1, x2)
  const minY = Math.min(y1, y2)
  const maxY = Math.max(y1, y2)
  const minZ = Math.min(z1, z2)
  const maxZ = Math.max(z1, z2)

  for (let x = minX; x <= maxX; x++) {
    for (let y = minY; y <= maxY; y++) {
      for (let z = minZ; z <= maxZ; z++) {
        level.setBlock(new StarterLobbyBlockPos(x, y, z), state, 3)
      }
    }
  }
}

function hasStarterBlock(level, x, y, z, blockId) {
  const actual = level
    .getBlockState(new StarterLobbyBlockPos(x, y, z))
    .getBlock()
  return String(StarterLobbyBuiltInRegistries.BLOCK.getKey(actual)) == blockId
}

function setStarterLobbySigns(server) {
  for (
    var signRoleIndex = 0;
    signRoleIndex < STARTER_ROLE_IDS.length;
    signRoleIndex++
  ) {
    var signRoleId = STARTER_ROLE_IDS[signRoleIndex]
    var signRole = STARTER_ROLES[signRoleId]
    var signZ = signRole.display.z
    var signFacing = signRole.display.z < 0 ? 'south' : 'north'

    runStarterLobbyCommand(
      server,
      `setblock ${signRole.display.x} 63 ${signZ} minecraft:oak_wall_sign[facing=${signFacing}]`
    )
    runStarterLobbyCommand(
      server,
      `data merge block ${signRole.display.x} 63 ${signZ} ${signTextNbt(signRole)}`
    )
  }
}

function verifyStarterLobby(level) {
  let ok = true

  for (let i = 0; i < STARTER_ROLE_IDS.length; i++) {
    var verifyRoleId = STARTER_ROLE_IDS[i]
    var verifyRole = STARTER_ROLES[verifyRoleId]
    var carpetOk = hasStarterBlock(
      level,
      verifyRole.pad.x1,
      62,
      verifyRole.pad.z1,
      verifyRole.pad.carpet
    )
    var displayOk = hasStarterBlock(
      level,
      verifyRole.display.x,
      62,
      verifyRole.display.z,
      verifyRole.block
    )

    console.info(
      `[Fantasy Pack] Starter lobby ${verifyRoleId}: carpet=${carpetOk}, display=${displayOk}`
    )
    ok = ok && carpetOk && displayOk
  }

  return ok
}

function buildStarterLobby(server) {
  if (starterLobbyBuilt) return

  const level = starterLobbyLevel(server)
  if (level == null) {
    if (!starterLobbyMissingLevelLogged) {
      console.warn(
        '[Fantasy Pack] Starter lobby level is not loaded yet; delaying room build.'
      )
      starterLobbyMissingLevelLogged = true
    }
    return
  }
  starterLobbyMissingLevelLogged = false

  try {
    console.info('[Fantasy Pack] Building starter lobby.')

    for (let cx = -1; cx <= 0; cx++) {
      for (let cz = -1; cz <= 0; cz++) {
        level.setChunkForced(cx, cz, true)
      }
    }

    fillStarterRegion(level, -15, 59, -15, 15, 69, 15, 'minecraft:bedrock')
    fillStarterRegion(
      level,
      -14,
      60,
      -14,
      14,
      68,
      14,
      'minecraft:deepslate_bricks'
    )
    fillStarterRegion(level, -12, 62, -12, 12, 67, 12, 'minecraft:air')
    fillStarterRegion(
      level,
      -12,
      61,
      -12,
      12,
      61,
      12,
      'minecraft:polished_deepslate'
    )
    fillStarterRegion(
      level,
      -11,
      61,
      -11,
      11,
      61,
      11,
      'minecraft:deepslate_tiles'
    )
    fillStarterRegion(
      level,
      -12,
      68,
      -12,
      12,
      68,
      12,
      'minecraft:deepslate_tiles'
    )
    fillStarterRegion(
      level,
      -12,
      61,
      -10,
      12,
      61,
      -10,
      'minecraft:polished_blackstone'
    )
    fillStarterRegion(
      level,
      -2,
      61,
      10,
      2,
      61,
      10,
      'minecraft:polished_blackstone'
    )
    fillStarterRegion(level, -12, 62, -10, 12, 62, -9, 'minecraft:air')
    fillStarterRegion(level, -2, 62, 9, 2, 62, 10, 'minecraft:air')

    setStarterBlock(level, 0, 67, 0, 'minecraft:sea_lantern')
    setStarterBlock(level, -10, 67, -10, 'minecraft:sea_lantern')
    setStarterBlock(level, -5, 67, -10, 'minecraft:sea_lantern')
    setStarterBlock(level, 0, 67, -10, 'minecraft:sea_lantern')
    setStarterBlock(level, 5, 67, -10, 'minecraft:sea_lantern')
    setStarterBlock(level, 10, 67, -10, 'minecraft:sea_lantern')
    setStarterBlock(level, 0, 67, 10, 'minecraft:sea_lantern')
    setStarterBlock(level, -12, 63, 0, 'minecraft:amethyst_block')
    setStarterBlock(level, 12, 63, 0, 'minecraft:amethyst_block')

    for (let i = 0; i < STARTER_ROLE_IDS.length; i++) {
      var buildRoleId = STARTER_ROLE_IDS[i]
      var buildRole = STARTER_ROLES[buildRoleId]
      var backdropZ =
        buildRole.display.z < 0
          ? buildRole.display.z - 1
          : buildRole.display.z + 1

      fillStarterRegion(
        level,
        buildRole.pad.x1,
        61,
        buildRole.pad.z1,
        buildRole.pad.x2,
        61,
        buildRole.pad.z2,
        buildRole.pad.floor
      )
      fillStarterRegion(
        level,
        buildRole.pad.x1,
        62,
        buildRole.pad.z1,
        buildRole.pad.x2,
        62,
        buildRole.pad.z2,
        buildRole.pad.carpet
      )
      setStarterBlock(
        level,
        buildRole.display.x,
        62,
        backdropZ,
        'minecraft:polished_blackstone_bricks'
      )
      setStarterBlock(
        level,
        buildRole.display.x,
        63,
        backdropZ,
        'minecraft:chiseled_deepslate'
      )
      setStarterBlock(
        level,
        buildRole.display.x,
        61,
        buildRole.display.z,
        'minecraft:chiseled_deepslate'
      )
      setStarterBlock(
        level,
        buildRole.display.x,
        62,
        buildRole.display.z,
        buildRole.block
      )
    }

    setStarterLobbySigns(server)

    starterLobbyBuilt = verifyStarterLobby(level)
    if (starterLobbyBuilt) {
      console.info('[Fantasy Pack] Starter lobby build verified.')
    } else {
      console.warn(
        '[Fantasy Pack] Starter lobby build verification failed; will retry.'
      )
    }
  } catch (error) {
    console.error('[Fantasy Pack] Starter lobby build failed.')
    console.error(error)
  }
}

function sendStarterInstructions(player) {
  tellraw(
    player,
    starterLine([
      { text: 'Choose your origin', color: 'white', bold: true },
      {
        text: ' - stand on the colored pad in front of a display block.',
        color: 'gray',
      },
    ])
  )
}

function setStarterLobbyGameMode(player, server) {
  const target = playerTarget(player)
  if (starterLobbyModePlayers[target]) return

  starterLobbyModePlayers[target] = true
  runStarterCommand(
    server,
    `execute as ${target} unless entity @s[gamemode=creative] unless entity @s[gamemode=spectator] run gamemode adventure @s`,
    'set starter lobby adventure mode'
  )
}

function restoreOverworldGameMode(player, server) {
  const target = playerTarget(player)
  delete starterLobbyModePlayers[target]
  runStarterCommand(
    server,
    `execute as ${target} if entity @s[gamemode=adventure] run gamemode survival @s`,
    'restore survival mode'
  )
}

function sendToStarterLobby(player, server) {
  player.teleportTo(
    STARTER_LOBBY_DIMENSION,
    STARTER_LOBBY_SPAWN.x,
    STARTER_LOBBY_SPAWN.y,
    STARTER_LOBBY_SPAWN.z,
    180,
    0
  )
  buildStarterLobby(server)
  setStarterLobbyGameMode(player, server)
  sendStarterInstructions(player)
}

function overworldSpawn(server) {
  const overworld = server.getLevel(STARTER_OVERWORLD_DIMENSION)
  if (overworld == null) {
    return { x: 0.5, y: 96, z: 0.5 }
  }

  const spawn = overworld.getSharedSpawnPos()
  return { x: spawn.getX() + 0.5, y: spawn.getY() + 1, z: spawn.getZ() + 0.5 }
}

function sendToOverworldSpawn(player, server) {
  const spawn = overworldSpawn(server)
  restoreOverworldGameMode(player, server)
  player.teleportTo(
    STARTER_OVERWORLD_DIMENSION,
    spawn.x,
    spawn.y,
    spawn.z,
    0,
    0
  )
}

function isInStarterLobby(player) {
  return String(player.level.dimension) == STARTER_LOBBY_DIMENSION
}

function routeStarterPlayer(player, server) {
  if (hasChosenStarterRole(player)) {
    if (isInStarterLobby(player)) {
      clearStarterPadHold(player)
      sendToOverworldSpawn(player, server)
    }
    return
  }

  sendToStarterLobby(player, server)
}

function roleForPad(player) {
  const x = Math.floor(player.getX())
  const z = Math.floor(player.getZ())

  for (
    var padRoleIndex = 0;
    padRoleIndex < STARTER_ROLE_IDS.length;
    padRoleIndex++
  ) {
    var padRoleId = STARTER_ROLE_IDS[padRoleIndex]
    var padRole = STARTER_ROLES[padRoleId]
    if (
      x >= padRole.pad.x1 &&
      x <= padRole.pad.x2 &&
      z >= padRole.pad.z1 &&
      z <= padRole.pad.z2
    ) {
      return { id: padRoleId, data: padRole }
    }
  }

  return null
}

function chooseStarterRole(player, server, role) {
  const key = playerTarget(player)
  if (starterRoleChoicesInProgress[key]) return

  starterRoleChoicesInProgress[key] = true
  clearStarterPadHold(player)
  try {
    role.data.grant(player, server)
  } catch (error) {
    console.error(
      `[Fantasy Pack] Starter role grant failed for ${key}: ${role.id}`
    )
    console.error(error)
    tellraw(
      player,
      starterLine([
        {
          text: 'Some starter gear failed to apply; check the log.',
          color: 'red',
        },
      ])
    )
  }

  setChosenStarterRole(player, role.id)
  try {
    tellraw(
      player,
      starterLine([
        { text: 'Path chosen: ', color: 'gray' },
        roleNameComponent(role.data),
        { text: '. Good luck.', color: 'gray' },
      ])
    )
    sendToOverworldSpawn(player, server)
  } finally {
    delete starterRoleChoicesInProgress[key]
  }
}

function handleStarterPadTick(player, server) {
  const role = roleForPad(player)
  const key = playerTarget(player)

  if (role == null) {
    clearStarterPadHold(player)
    return
  }

  const hold = starterPadHolds[key]
  if (hold == null || hold.roleId != role.id) {
    starterPadHolds[key] = { roleId: role.id, ticks: 1 }
    tellraw(
      player,
      starterLine([
        { text: 'Hold still to choose ', color: 'gray' },
        roleNameComponent(role.data),
        { text: '.', color: 'gray' },
      ])
    )
    return
  }

  hold.ticks += 1
  if (hold.ticks >= STARTER_PAD_HOLD_TICKS) {
    chooseStarterRole(player, server, role)
  }
}

function isStarterLobbyBlock(block) {
  return String(block.dimension) == STARTER_LOBBY_DIMENSION
}

PlayerEvents.loggedIn((event) => {
  routeStarterPlayer(event.player, event.server)
})

ServerEvents.loaded((event) => {
  resetStarterLobbyState()
})

ServerEvents.unloaded((event) => {
  resetStarterLobbyState()
})

PlayerEvents.respawned((event) => {
  routeStarterPlayer(event.player, event.server)
})

PlayerEvents.tick((event) => {
  const player = event.player
  const server = event.server || player.server

  if (!isInStarterLobby(player)) {
    clearStarterPadHold(player)
    if (starterLobbyModePlayers[playerTarget(player)]) {
      restoreOverworldGameMode(player, server)
    }
    return
  }

  buildStarterLobby(server)

  if (hasChosenStarterRole(player)) {
    clearStarterPadHold(player)
    sendToOverworldSpawn(player, server)
    return
  }

  setStarterLobbyGameMode(player, server)
  handleStarterPadTick(player, server)
})

BlockEvents.rightClicked((event) => {
  if (String(event.block.dimension) != STARTER_LOBBY_DIMENSION) return

  event.cancel()
  tellraw(
    event.player,
    starterLine([
      { text: 'Use the colored pads to choose a start.', color: 'gray' },
    ])
  )
})

BlockEvents.leftClicked((event) => {
  if (isStarterLobbyBlock(event.block)) {
    event.cancel()
  }
})

BlockEvents.broken((event) => {
  if (isStarterLobbyBlock(event.block)) {
    event.cancel()
  }
})

BlockEvents.placed((event) => {
  if (isStarterLobbyBlock(event.block)) {
    event.cancel()
  }
})
