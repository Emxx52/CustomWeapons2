# Custom Weapons 2
Valve still not adding new weapons to TF2? No problem. Custom Weapons 2 allows you to create your own weapons and let your players use them.

Once you've installed the plugin and some weapons, all players have to do is say /custom, /cus or /c for the list of custom weapons for that class.

It's somewhat like Advanced Weaponiser, except the creation, modification, and selection of weapons is not limited to a certain group of people; it's up to whoever installs the plugin.

You can create your own weapons with unique stats, and share them with other servers using Custom Weapons 2. Apply any Valve attribute you'd like onto your weapon.

Valve attributes not unique enough? Create your own attributes sub-plugin with ease. Each custom attribute added allows for more and more unique weapons to be created with it!

<hr>

# Commands
- **sm_custom** - Open custom weapons menu
- **sm_cus** - Open custom weapons menu
- **sm_c** - Open custom weapons menu

<hr>

# Admin commands
- **custom_addattribute** - <client> <slot> <"attribute name"> <"value"> <"plugin"> - Adds a custom attribute onto any weapon.

Want your melee weapon to ignite whoever it crits on? custom_addattribute @me 2 "crits ignite" "1" "basic-attributes"

Users marked as "ROOT" or Z flag can use /c reload as an alias to reloading the plugin. This is the expected way to reload.

<hr>

# ConVars
- **sm_customweapons_enable** *(1/0, def. 1)* Enables the plugin, of course! Set to 0 to remove all active custom weapons.
- **sm_customweapons_onlyinspawn** *(1/0, def. 1)* Only allow /custom to be used inside of a spawn room.
- **sm_customweapons_arena_time** *(def. 20)* Time, in seconds, to allow /custom after spawning in Arena.
- **sm_customweapons_bots** *(def. 0.15)* Percent chance, per slot, that bots will equip a random custom weapon.
- **sm_customweapons_menu** *(1/0, def. 1)* Clients are allowed to say /custom to equip weapons manually. Set to 0 to disable manual weapon selection without disabling the entire plugin.
- **sm_customweapons_killwearablesondeath** *(1/0, def. 1)* Removes custom weapon models when the user dies. Recommended unless bad things start happening.
- **sm_customweapons_sethealth** *(1/0, def. 1)* When a custom weapon is equipped, the user's health will be set to their maximum.
- **sm_customweapons_onlyteam** *(def. 0)* If non-zero, custom weapons can only be equipped by one team; 2 = RED, 3 = BLU.

<hr>

# Planned features (Chdata's TODO List)

* High priority
- Integrate clientprefs + reload player weapons on plugin reset.
- Load newly added weapons+attributes without plugin reset.
- Translation phrases
- Custom wearables! (e.g. Gunboats, Chargin' Targe)
- Make custom weapons start with the correct clip and ammo by default, unless overriden, via https://forums.alliedmods.net/showthread.php?t=262695

* Low priority
- Kill icons (this should probably be controlled through a custom attribute plugin as there are varying scenarios in which you may use a variety of different kill icons ... dunno if custom kill icons are possible/easy to do)
- Native or otherwise to see if a weapon has a certain attribute
- List registered attributes for devs.
- The ability to apply/not apply certain attributes if certain cvars (such as hale_enable) are active (Attribute plugin creators can do this on their own, however a standard naming convention should be created like cw2_orion_disable_x_attribute)
- Auto chat advertisements (just use an chat advert plugin for this ...)

* Completed, unimplemented
- Add lots of confirmation messages such as "Unequipped Weapon Name". (wait on translation phrases)
- When custom weapons are equipped, display in chat the names of the equipped items. (wait on translation phrases)
- Split menus by weapon slot. (wait on translation phrases)

Example naming scheme for translation phrases will be as follows:

"#CW2 Weapon Equip Msg"
{
    "en" "Equipped {1}!"
}

Follows a similar format to what Valve actually does.

* Completed, updated in the plugin
- Fix this botkiller nonsense that was fixed in VSH a year ago.
- SteamID keyvalue to force "Self Made" quality. Supports multiple steamids.
- weapon_logclassname overwriting on kill

<hr>

# How to make custom weapons
Creating a new custom weapon is plain easy. Simply duplicate a custom weapon's config file, and fill out its info with your own.

It is suggested to name your weaponconfigfile.txt with the following naming schemata:
https://forums.alliedmods.net/showpost.php?p=2345131&postcount=573

The weapon's name goes right at the top, in "quotes".
- "classes" is the array of player classes the weapon should be available for; the number next to each class is the weapon slot (0 = Primary, 1 = Secondary, 2 = Melee)
- "baseclass" is the classname of the weapon, without "tf_weapon_".
- "baseindex" is the item index of the base weapon, see above classname link. If unsure, stick within the 0-30s.
  - If it uses ammo (i.e. most non-melee weapons) it should have "mag" and "ammo" keys with the intended starting ammo.
- "logname" will be displayed in client consoles when a kill is made with the weapon.
- "killicon" will be able to change the weapon's icon in the kill feed if it's ever implemented
- "level" will set the item level
- "quality" will set the item quality. Use item quality numbers listed below. Defaults to 10 (Customized). Will always be overwritten by the "steamids" option.
- "steamids" SteamIDs of the creator(s) of the weapon, separated by ,commas, - Supports STEAM_0 and [U:] type IDs. Matching SteamIDs are given Self-Made quality.
- "description" is the stat list that players will see when selecting the weapon. \n = Newline. "\n \n" will skip an entire line.
- "attributes"; the bread-n-butter. Each attribute has:
  - An identifier, to set what attribute it is. This will either be a case-sensitive name (Custom Weapons, TF2Attributes) or an attribute index (TF2Items).
  - "plugin": Who will provide the attribute's functionality?
  - For official Valve attributes, you'll usually want to use TF2Attributes, so put "tf2attributes". A select few attributes require "tf2attributes.int" instead.
  - If TF2Attributes doesn't work for said attribute (so far I've only seen "alt-fire is vampire" not work with TF2Att) then try "tf2items" instead, with the identifier being the number beside the attribute's name. (e.g. "move speed penalty" should instead be "54")
  - Or, of course, a custom attribute! In which case, "plugin" should be set to the name of the attributes plugin, minus ".smx". The starter pack includes "basic-attributes" and "custom-attributes".
  - And of course, a value. Most attributes are multipliers; with "damage bonus/penalty", "2.0" is double (+100%), and "0.5" is halved (-50%). With time-based attributes such as "Reload time increased/decreased", "0.5" is half time (good), whereas "2.0" makes it take twice as long (bad). And some attributes are simply "1.0 = on, 0.0 = off".
  - If you're unsure about values, check out a weapon that already has that attribute (Ctrl+F the official weapon's name in tf/scripts/items_game.txt, or just look at the custom weapon's config)

<hr>

# Item quality numbers
- 0 - Stock
- 1 - Genuine
- 2 - rarity2 (Unused)
- 3 - Vintage
- 4 - rarity3 (Unused)
- 5 - Unusual
- 6 - Unique
- 7 - Community
- 8 - Valve
- 9 - Self-Made
- 10 - Customized
- 11 - Strange
- 12 - Completed (Unused)
- 13 - Haunted
- 14 - Collector's
- 15 - Decorated (Gun Mettle weapons)

<hr>

# How to make custom attributes
To be able to make custom attributes, all you need to know are the basics of SourcePawn. That's it! (Also, you need customweaponstf.inc from this repository)

Take a look at basic-attributes.sp in the Starter Weapons Pack; it's fairly simple, and has some comments here, there, and everywhere to explain things. Think of it as somewhat of a template for attributes plugins.

<hr>

# FAQ
**Q:** How is this different from Advanced Weaponiser?

**A:** You (who runs the game server) can change around the weapons in whatever ways you'd like. The weapons are always equippable, and not tied to any "master server". Also, this plugin isn't abandoned, private, or what have you.

<hr>

**Q:** I gave my custom weapon a model, can other players besides the user see it?

**A:** Nope. The player will be able to see it in both first and third person, though.

<hr>

**Q:** (weapon name) is overpowered/underpowered! Fix it!

**A:** No u! Change its stats, or disable it (after all, that's the point of this plugin!) and perhaps suggest a tweak to its stats once you've done so.

<hr>

**Q:** Was there a Custom Weapons 1?

**A:** Yes. It was 100% hardcoded, and terrible. Thankfully, it was private.

<hr>

**Q:** Why is it called "customweaponstf.smx"?

**A:** MasterOfTheXP actually, for some reason, originally made this for CS:GO; as a proof of concept, and because bot matches were getting a bit stale with CS:GO's plain, realistic weapons. So, this is the "TF2 edition" of Custom Weapons.

<hr>

# Installation
**Your server needs both [TF2Items](https://builds.limetech.org/?p=tf2items) and [TF2Attributes](https://forums.alliedmods.net/showthread.php?t=210221) loaded!**
* Install customweaponstf.smx into your sourcemod/plugins/ directory.
* Install tf2items.randomizer.txt into your sourcemod/gamedata/ directory.
* Install whatever custom weapons/attributes/packs you'd like. You need at least one custom weapon for this to work, and most likely, that weapon will require an attributes plugin.
* sm plugins load customweaponstf, or sm plugins reload customweaponstf when you install more.
* Done!

<hr>

# DLC?!
You need custom weapons (which usually require custom attributes) in order to run Custom Weapons. Why not start with these?

## Weapons + Attributes
- [Starter Custom Weapons + Basic Attributes + Custom Attributes](http://files.mstr.ca/customweapons/StarterWeaponPack.zip)
- [Orion's Attributes & Weapons](https://forums.alliedmods.net/showpost.php?p=2193855&postcount=254)
- [Khopesh Climber attribute with example Khopesh Climber weapon](https://forums.alliedmods.net/showpost.php?p=2209941&postcount=281)

## Weapons
- [Half-Life 2 Weapons (requires Starter Pack)](http://files.mstr.ca/customweapons/HL2Weapons.zip)
- [WIP Weapon Pack (requires Starter Pack)](http://files.mstr.ca/customweapons/WIPWeapons.zip)
- [Workshop Weapons Pack](https://forums.alliedmods.net/showpost.php?p=2188941&postcount=246)
- [Freak Fortress 2 Weapons Pack by MaSerkzn](https://forums.alliedmods.net/showpost.php?p=2350129&postcount=655)

## Attributes
- [NergalPak](https://forums.alliedmods.net/showpost.php?p=2121002&postcount=121)
- [Advanced Weaponiser 2 Attributes and Rays Attributes](https://forums.alliedmods.net/showpost.php?p=2193263&postcount=252)
- [Orion's Attributes](https://forums.alliedmods.net/showpost.php?p=2193855&postcount=254)
- [The655's Attributes](https://forums.alliedmods.net/showpost.php?p=2342151&postcount=558)

### Or you can make your own!

<hr>

# Forum Thread
https://forums.alliedmods.net/showthread.php?t=236242
