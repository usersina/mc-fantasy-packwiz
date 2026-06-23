#!/usr/bin/env bash
set -u

FAILED=()

install_modrinth() {
  local id="$1"
  local name="$2"

  echo
  echo "==> Modrinth: $name [$id]"
  if ! packwiz -y modrinth install "$id"; then
    echo "FAILED: $name"
    FAILED+=("Modrinth: $name [$id]")
  fi
}

install_curseforge() {
  local project_id="$1"
  local name="$2"

  echo
  echo "==> CurseForge: $name [$project_id]"
  if ! packwiz -y curseforge add --addon-id "$project_id"; then
    echo "FAILED: $name"
    FAILED+=("CurseForge: $name [$project_id]")
  fi
}

MODRINTH_PROJECTS=(
  "7Jy4rK9m|Ace's Spell Utils"
  "fM515JnW|AmbientSounds"
  "EsAfCjCV|AppleSkin"
  "Vl1uNAuy|Aquaculture 2"
  "Pkj2hNRk|ArcaneEssenceBlock"
  "lhGA9TYQ|Architectury"
  "7zlUOZvb|AzureLib"
  "OfKzpbRU|BaguetteLib"
  "MBAkmtvl|Balm"
  "uChGyl9A|Basic Login"
  "vNNL5mc7|Bedspreads"
  "zCh7omyG|Better Archeology"
  "ZucWZEBV|Better Climbing"
  "bZDWL6yP|Blazing Bamboo Continued"
  "BdKIyOLe|Boat Item View"
  "uy4Cnpcm|Bookshelf"
  "40FYwb4z|Caelus API"
  "joEfVgkn|Carry On"
  "JbqjOoQj|CarryOnExtend"
  "3FEg0A8D|Cataclysm: Spellbooks"
  "b5GyyYkp|Charm of Undying"
  "pvcsfne4|Chefs Delight"
  "9s6osm5g|Cloth Config v15 API"
  "Wnxd13zP|Clumps"
  "MtxycBD6|Compressed Fuel"
  "xv94TkTM|Controlling"
  "WrpuIfhw|Corpse"
  "pJGcKPh1|Corpse Curios Compatibility"
  "OsZiaDHq|CreativeCore"
  "cl223EMc|Cristel Lib"
  "vvuO3ImH|Curios API"
  "YSQOjXtW|DMR: Craftable Eggs"
  "jZ1O2L1W|DMR:Phantom Dragon"
  "DUx05jFK|Dragon Mounts Remastered"
  "tpehi7ww|Dungeons and Taverns"
  "OZBR5JT5|Easy Anvils"
  "mSQF1NpT|Elytra Slot"
  "ePv85y52|Enchanting Infuser"
  "UVtY3ZAC|EnchantmentDescriptions"
  "2uEhdGKt|Ender's Delight"
  "NNAgCjsB|EntityCulling"
  "R2OftAxM|Farmer's Delight"
  "AioQLjKj|Farmer's Respite"
  "uXXizFIs|Ferrite Core"
  "njBFO9fI|Fireproof Boats"
  "Aqlf1Shp|Forgified Fabric API"
  "1vkzEZjE|Forgiving Void"
  "8BmcQJ2H|GeckoLib 4"
  "WC4UgDcZ|Grind Enchantments"
  "w5L2PHJU|Guide-API-VP"
  "5faXoLqX|Iceberg"
  "x3HZvrj6|Immersive Aircraft"
  "kNsl999k|Immersive Aircraft: Better Engines"
  "9nfaJPtX|Iron's Lib"
  "s4OWxYQQ|Iron's Spells 'n Spellbooks"
  "cdEXZLO4|Iron's Spells 'n Spellbooks Dynamic Skill Tree"
  "nvQzSEkH|Jade"
  "9Pk89J3g|Just Enough Breeding"
  "EO27GKs1|Just Enough Effects Descriptions"
  "u6dRKJwZ|Just Enough Items"
  "1vrSzlao|KotlinLangForge"
  "a48R8AGk|L_Ender's Delight"
  "46KJle7n|L_Ender's Cataclysm"
  "SqnBX2qd|Lan Server Properties"
  "atHH8NyV|Legendary Tooltips"
  "gvQqBUqZ|Lithium"
  "EltpO5cN|Lootr"
  "nmDcB62a|ModernFix"
  "aC3cM3Vq|Mouse Tweaks"
  "BFbX9xcm|Mowzie's Mobs"
  "MPCX6s5C|NotEnoughAnimations"
  "DGiq4ZSW|Ocean's Delight"
  "esqWA0aQ|Paraglider"
  "gedNE4y2|Player Animator"
  "FFeAJNCx|PreloadingTricks"
  "aaRl8GiW|PrickleMC"
  "1OE8wbN0|Prism"
  "FCFcFw09|Pufferfish's Attributes"
  "hqQqvaa4|Pufferfish's Skills"
  "IAao6ECB|Pufferfish's Unofficial Additions"
  "QAGBst4M|Puzzles Lib"
  "M1953qlQ|Resourcefulconfig"
  "fuuu3xnx|Searchables"
  "ghrZDhGW|SkinRestorer"
  "rGWEHQrP|Small Ships"
  "AANobbMI|Sodium"
  "TyCTlI4b|Sophisticated Backpacks"
  "nmoqTijg|Sophisticated Core"
  "EvjGFdKp|Spartan Shields Unofficial"
  "w8V2GMiK|Spartan Weaponry Unofficial"
  "3dsI6Hle|Stormie's Spiders"
  "54eqfZSC|Towers of The Wild: Modded"
  "DjLobEOy|Towns and Towers"
  "8D0TiNOF|Vampire Spells Addon"
  "9Vo2deFq|Vampire's Delight"
  "FaUysFni|Vampires Need Umbrellas"
  "jVZ0F1wn|Vampirism"
  "OhduvhIc|Veinminer"
  "4sP0LXxp|Veinminer Enchantment"
  "LOpKHB2A|Waystones"
  "3ElBohKg|Werewolves"
  "nTApwmMc|Wind's Spellbooks"
  "AnpW69o3|XP Tome"
  "NcUtCpym|Xaero's World Map"
  "Ua7DFN59|YUNG's API"
  "o1C1Dkj5|YUNG's Better Dungeons"
  "Z2mXHnxP|YUNG's Better Nether Fortresses"
  "kidLKymU|YUNG's Better Strongholds"
  "Ht4BfYp6|YUNG's Bridges"
  "ZYgyPyfq|YUNG's Extras"
  "FoVacERa|lionfishapi"
  "TIo1UXXV|more_enchantment_info_container"
  "ccKDOlHs|oωo"
)

CURSEFORGE_PROJECTS=(
  "457570|Configured"
  "358700|More Dragon Eggs"
)

for entry in "${MODRINTH_PROJECTS[@]}"; do
  id="${entry%%|*}"
  name="${entry#*|}"
  install_modrinth "$id" "$name"
done

for entry in "${CURSEFORGE_PROJECTS[@]}"; do
  url="${entry%%|*}"
  name="${entry#*|}"
  install_curseforge "$url" "$name"
done

echo
echo "==> Refreshing packwiz index"
packwiz refresh

echo
if [ "${#FAILED[@]}" -eq 0 ]; then
  echo "All mods installed successfully."
else
  echo "Some mods failed:"
  printf ' - %s\n' "${FAILED[@]}"
  exit 1
fi
