#pragma semicolon 1
#include <tf2_stocks>
#include <sdkhooks>
#include <customweaponstf>
#include <tf2items>
#include <tf2attributes>

#define PLUGIN_VERSION "beta 2"

public Plugin:myinfo = {
    name = "Custom Weapons: Custom Attributes",
    author = "MasterOfTheXP",
    description = "Attributes that are usually unique to one weapon.",
    version = PLUGIN_VERSION,
    url = "http://mstr.ca/"
};

/* *** Attributes In This Plugin ***
  -> "fires fast fix bolts"
	   This weapon fires Fast Fix bolts.
	   Set TF2 attribute override projectile type to -1 on the weapon
	   if you want to use this.
  -> "heal on altfire hit"
       <amount>
	   The user will be healed by this much health whenever they get a hit
	   with this weapon while only holding down alt-fire.
  -> "user cannot use destroy"
	   If a player has a weapon with this attribute, they will not be able
	   to use the "destroy" console command to manually destroy their buildings.
  !  "kills charge sniper rifle"
       "<percentage, e.g. 0.5 for 50%>"
	   Each time a player gets a kill with this weapon, their sniper rifle (if they have one)
	   will have its "minimum charge" increased by the value.
	   Currently only works with sniper rifles.
	   Support for bows and other weapons planned.
  -> "cloak leeches health"
       "<health gained per second>"
	   Can only be applied onto invis weapons (watches).
	   This cloaking device adds this much health to the user for each second that they are cloaked.
	   You probably want to use a negative value with this.
	   Additionally, the user's cloak meter will remain at 100% while cloaked.
  -> "medi gun restores ammo"
       "<offhand ammo % to restore per second>"
	   Can only be applied onto medi guns.
	   While healing a player, the patient will slowly recover lost ammo.
	   Additionally, this medi gun's charge will grant the patient
	   infinite clip, infinite ammo, and 25% faster fire rate.
  -> "medi gun shares positive boosts"
	   Can only be applied onto medi guns.
	   While healing a player, the patient will recieve any conditions that the medic has
	   that positively affect players, such as UberCharge and crit boost.
  -> "medi gun speed boost ubercharge"
	   Can only be applied onto medi guns.
	   This medi gun's charge will grant a speed boost and "elastic band" effect
	   onto the medic and his patient.
	   Should the players get seperated too far, the slower of the two players
	   will be boosted towards the faster player.
  !  "turnabout ammo"
	   <ammo count> [ammo to restore on hit]
	   This weapon uses a "Turnabout" ammo system.
	   It will only have X ammo, but never needs to reload,
	   and should the user get a hit with this weapon,
	   they will instantly recieve Y ammo back.
	   Accepts a second argument for ammo to recieve on hit.
	   If not specified, assumes 1.
	   Currently not quite stable to use this with non-hitscan weapons.
	   Hits on bosses such as the Horsemann check the user's active weapon instead of
	   the weapon that actually got the hit.
  -> "sapper causes rage"
	   <rage duration in seconds>
	   Can only be applied onto sappers.
	   Sapping a building will immediately cause "rage" on its Engineer.
	   The Engineer will deal 100% critical hits against the weapon's user
	   for the duration of the rage.
  !  "sapper cooldown"
	   <cooldown duration in seconds>
	   Can only be applied onto sappers.
	   After sapping a building, the sapper won't be able to be used again
	   for N seconds.
	   Glitches up the viewmodel a little bit if the user tries to switch to
	   the sapper during the cooldown, and WILL cause issues with other plugins
	   hooking SDK Hooks' weapon switch hooks.
  -> "ubercharge is halloween spell"
	   <spell index> <percent of ubercharge required>
	   Sets the medi gun's UberCharge to be the usage of a specific Halloween spell.
	   Upon using the charge, the Medic will perform the spell, and lose the specified
	   amount of UberCharge.
	   0.0 for no cost, 0.25 for 25% "intervals",
	   1.0 for it to require and use the entire UberCharge meter.
	   Can only be applied onto medi guns.
  -> "syringe gun charge boost"
	   <percent of ubercharge required>
	   The amount of UberCharge that the user has on their medi gun can be used as
	   "boost" by this weapon. Right-clicking with at least N% UberCharge will enable
	   a Vaccinator-style mini-crit and speed boost.
	   Can be used on any weapon except for secondary weapons, but if the user does not
	   have a medi gun, this attribute will not do anything, or even appear.
  -> "redux hype bonus"
	  <approx. distance needed to fill hype>
	  Acts like the Soda Popper's hype, but grants +13% move speed and +35% jump height
	  while active.
	  Doesn't seem to be as stable as the standard hype meter, though.
	  Can be applied onto any weapon and any class.
  -> "fires lasers"
	  <base damage>
	  This weapon will fire lasers, in addition to its normal projectile/bullets.
	  Add "override projectile type" with a value of -1.0 onto the weapon to
	  make it only fire lasers.
	  While firing lasers, forces alt-fire to be held down if it isn't. This causes
	  it to fire lasers at a fixed rate from miniguns.
*/

new bool:HasAttribute[2049];
new bool:FiresFastFixBolts[2049];
new HealOnAltFireHit[2049];
new bool:UserCannotUseDestroy[2049];
new Float:KillsChargeSniperRifle[2049];
new CloakLeechesHealth[2049];
new Float:MediGunRestoresAmmo[2049];
new bool:MediGunSharesPositiveBoosts[2049];
new bool:MediGunSpeedBoostUber[2049];
new TurnaboutAmmo[2049];
new TurnaboutAmmoRestore[2049];
new Float:SapperCausesRage[2049];
new Float:SapperHasCooldown[2049];
new MediGunSpellUberCharge[2049] = {-1, ...};
new Float:MediGunSpellUberChargeDeplete[2049];
new Float:SyringeGunChargeBoost[2049];
new Float:ReduxHypeBonus[2049];
new Float:FiresLasers[2049];

new bool:TrackPatientChanges[2049];
new Float:MinimumRifleCharge[2049];
new Float:MinimumBowCharge[2049];
new MaxClip[2049];
new MaxAmmo[2049];
new Float:MaxEnergy[2049];
new Float:AmmoFractionFillProgress[2049]; // % 1
new bool:AmmoIsMetal[2049];
new Float:SyringeGunChargeBoostUntilUber[2049];
new Float:ReduxHypeBonusCharged[2049];
new bool:ReduxHypeBonusDraining[2049];

new LastWeaponHurtWith[MAXPLAYERS + 1];
new LastHealingTarget[MAXPLAYERS + 1];
new Handle:hRefillCloakTimer[MAXPLAYERS + 1];
new Handle:hLeechHealthTimer[MAXPLAYERS + 1];
new Float:CreateNextMedispenserParticle[MAXPLAYERS + 1];
new Float:NextBadMedispenserUberSoundsTime[MAXPLAYERS + 1];
new Float:SapperRageUntil[MAXPLAYERS + 1][MAXPLAYERS + 1];
new Float:SapperCooldownUntil[MAXPLAYERS + 1];

new Handle:hudText_Client;

new repairclawmodel;
new beamsprite, halosprite;

public OnPluginStart()
{
	AddCommandListener(Listener_destroy, "destroy");
	
	HookEvent("player_death", Event_Death);
	HookEvent("player_chargedeployed", Event_UberCharge);
	HookEvent("player_sapped_object", Event_SpysSappinMySentry, EventHookMode_Pre);
	HookEvent("npc_hurt", Event_NPCHurt);
	
	AddNormalSoundHook(SoundHook);
	
	CreateTimer(0.1, Timer_TenTimesASecond, _, TIMER_REPEAT);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		OnClientPutInServer(i);
	}
	
	hudText_Client = CreateHudSynchronizer();
	
	if (IsValidEntity(0))
	{
		new i = -1;
		while ((i = FindEntityByClassname(i, "obj_*")) != -1)
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage_Building);
	}
}

public OnMapStart()
{
	repairclawmodel = PrecacheModel("models/weapons/w_models/w_repair_claw.mdl", true);
	
	beamsprite = PrecacheModel("materials/sprites/laser.vmt");
	halosprite = PrecacheModel("materials/sprites/halo01.vmt");
	
	PrecacheSound("weapons/flaregun/fire.wav", true);
	PrecacheSound("weapons/sapper_removed.wav", true);
	
	PrecacheSound("npc/attack_helicopter/aheli_charge_up.wav", true);
	PrecacheSound("npc/vort/health_charge.wav", true);
	PrecacheSound("vehicles/crane/crane_magnet_release.wav", true);
	PrecacheSound("ambient/machines/spinup.wav", true);
}

public OnClientPutInServer(client)
{
	LastWeaponHurtWith[client] = 0;
	for (new i = 0; i <= MAXPLAYERS; i++)
	{
		SapperRageUntil[client][i] = 0.0;
		SapperRageUntil[i][client] = 0.0;
	}
	SapperCooldownUntil[client] = 0.0;
	
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public Action:CustomWeaponsTF_OnAddAttribute(weapon, client, const String:attrib[], const String:plugin[], const String:value[])
{
	if (!StrEqual(plugin, "custom-attributes")) return Plugin_Continue;
	new Action:action;
	if (StrEqual(attrib, "fires fast fix bolts"))
	{
		FiresFastFixBolts[weapon] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "heal on altfire hit"))
	{
		HealOnAltFireHit[weapon] = StringToInt(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "user cannot use destroy"))
	{
		UserCannotUseDestroy[weapon] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "kills charge sniper rifle"))
	{
		KillsChargeSniperRifle[weapon] = StringToFloat(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "cloak leeches health"))
	{
		CloakLeechesHealth[weapon] = StringToInt(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "medi gun restores ammo"))
	{
		MediGunRestoresAmmo[weapon] = StringToFloat(value);
		TF2Attrib_SetByName(weapon, "medigun charge is crit boost", -1.0);
		TrackPatientChanges[weapon] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "medi gun shares positive boosts"))
	{
		MediGunSharesPositiveBoosts[weapon] = true;
		TrackPatientChanges[weapon] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "medi gun speed boost ubercharge"))
	{
		MediGunSpeedBoostUber[weapon] = true;
		TF2Attrib_SetByName(weapon, "medigun charge is crit boost", -1.0);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "turnabout ammo"))
	{
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		TurnaboutAmmo[weapon] = StringToInt(values[0]);
		if (strlen(values[1])) TurnaboutAmmoRestore[weapon] = StringToInt(values[1]);
		else TurnaboutAmmoRestore[weapon] = 1;
		
		TF2Attrib_SetByName(weapon, "mod max primary clip override", -1.0);
		SetAmmo_Weapon(weapon, TurnaboutAmmo[weapon]);
		SetClip_Weapon(weapon, TurnaboutAmmo[weapon]);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "sapper causes rage"))
	{
		SapperCausesRage[weapon] = StringToFloat(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "sapper cooldown"))
	{
		SapperHasCooldown[weapon] = StringToFloat(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "ubercharge is halloween spell"))
	{
		new String:values2[2][10];
		ExplodeString(value, " ", values2, sizeof(values2), sizeof(values2[]));
		MediGunSpellUberCharge[weapon] = StringToInt(values2[0]);
		MediGunSpellUberChargeDeplete[weapon] = StringToFloat(values2[1]);
		TF2Attrib_SetByName(weapon, "medigun charge is crit boost", -1.0);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "syringe gun charge boost"))
	{
		SyringeGunChargeBoost[weapon] = StringToFloat(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "redux hype bonus"))
	{
		ReduxHypeBonus[weapon] = StringToFloat(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "fires lasers"))
	{
		FiresLasers[weapon] = StringToFloat(value);
		action = Plugin_Handled;
	}
	if (!HasAttribute[weapon]) HasAttribute[weapon] = bool:action;
	return action;
}

public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	if (weapon == -1) return Plugin_Continue;
	if (MinimumRifleCharge[weapon]) MinimumRifleCharge[weapon] = 0.0;
	if (MinimumBowCharge[weapon]) MinimumBowCharge[weapon] = 0.0;
	if (GetEntProp(client, Prop_Send, "m_nNumHealers") > 0)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (client == i) continue;
			if (!IsClientInGame(i)) continue;
			if (!IsPlayerAlive(i)) continue;
			if (client != GetMediGunPatient(i)) continue;
			new medigun = GetPlayerWeaponSlot(i, 1);
			if (!HasAttribute[medigun]) continue;
			if (!MediGunRestoresAmmo[medigun]) continue;
			if (!GetEntProp(medigun, Prop_Send, "m_bChargeRelease")) continue;
			CreateTimer(0.0, Timer_IncreaseWeaponFireRate, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE);
			break;
		}
	}
	if (!HasAttribute[weapon]) return Plugin_Continue;
	if (FiresFastFixBolts[weapon])
	{
		// Code basically stolen from Advanced Tauntiser
		new projectile = CreateEntityByName("tf_projectile_flare");
		new Float:pos[3], Float:ang[3], team;
		GetClientEyePosition(client, pos);
		GetClientEyeAngles(client, ang);
		team = GetClientTeam(client);
		
		new Float:vel[3];
		GetAngleVectors(ang, vel, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vel, vel);
		ScaleVector(vel, 3000.0);
		
		TeleportEntity(projectile, pos, ang, vel);
		SetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity", client);
		SetEntPropEnt(projectile, Prop_Send, "m_hLauncher", weapon);
		SetEntProp(projectile, Prop_Send, "m_iTeamNum", team);
		SetEntDataFloat(projectile, FindSendPropOffs("CTFProjectile_Arrow", "m_iDeflected") + 4, 0.0, true);
		DispatchSpawn(projectile);
		SetEntityModel(projectile, "models/weapons/w_models/w_repair_claw.mdl");
		SetEntPropFloat(projectile, Prop_Send, "m_flModelScale", 1.2);
		
		new particle = CreateEntityByName("info_particle_system");
		DispatchKeyValue(particle, "effect_name", team == 2 ? "repair_claw_heal_red" : "repair_claw_heal_blue");
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", projectile);
		AcceptEntityInput(particle, "Start");
		
		EmitSoundToAll("weapons/flaregun/fire.wav", client, _, SNDLEVEL_SCREAMING);
		SDKHook(projectile, SDKHook_Touch, OnFastFixProjectileTouch);
	}
	if (TurnaboutAmmo[weapon])
	{
		new ammo = GetAmmo_Weapon(weapon) - 1;
		if (ammo < 0) ammo = 0;
		SetAmmo_Weapon(weapon, ammo);
	}
	if (FiresLasers[weapon])
	{
		new Float:start[3], Float:end[3], Float:ang[3];
		GetClientEyePosition(client, start);
		GetClientEyeAngles(client, ang);
		TR_TraceRayFilter(start, ang, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf, client);
		TR_GetEndPosition(end);
		new target = TR_GetEntityIndex();
		
		start[2] -= 20.0;
		new team = GetClientTeam(client);
		TE_SetupBeamPoints(start, end, beamsprite, halosprite, 0, 0, 0.2, 10.0, 9.9, 0, 0.5, team == 2 ? {255, 0, 0, 255} : {0, 0, 255, 255}, 10);
		TE_SendToAll();
		TE_SetupBeamPoints(start, end, beamsprite, halosprite, 0, 0, 0.2, 10.0, 9.9, 0, 0.5, team == 2 ? {255, 0, 0, 255} : {0, 0, 255, 255}, 10);
		TE_SendToAll();
		TE_SetupBeamPoints(start, end, beamsprite, halosprite, 0, 0, 0.2, 10.0, 9.9, 0, 0.5, team == 2 ? {255, 0, 0, 255} : {0, 0, 255, 255}, 10);
		TE_SendToAll();
		
		if (target > 0)
		{
			new bool:ok;
			if (target <= MaxClients)
			{
				if (IsPlayerAlive(target)) ok = true;
			}
			else if (-1 != GetEntSendPropOffs(target, "m_iTeamNum")) ok = true;
			
			if (ok)
			{
				if (team != GetEntProp(target, Prop_Send, "m_iTeamNum"))
				{
					new Float:targetPos[3];
					GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPos);
					new Float:damage = FiresLasers[weapon], Float:dist = GetVectorDistance(start, targetPos);
					while (dist > 0.0 && damage > 2.0)
						damage -= 2.0, dist -= 60.0;
					if (damage < 2.0) damage = 2.0;
					
					damage /= 2.0;
					
					SDKHooks_TakeDamage(target, client, client, damage, DMG_BULLET, weapon);
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:Timer_IncreaseWeaponFireRate(Handle:timer, any:ref)
{
	new ent = EntRefToEntIndex(ref);
	if (ent <= MaxClients) return;
	new Float:time = GetGameTime();
	new Float:remPri = GetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack") - time, Float:remSec = GetEntPropFloat(ent, Prop_Send, "m_flNextSecondaryAttack") - time;
	if (remPri > 0.0) SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", time + (remPri * 0.75));
	if (remSec > 0.0) SetEntPropFloat(ent, Prop_Send, "m_flNextSecondaryAttack", time + (remSec * 0.75));
}

public Action:OnFastFixProjectileTouch(entity, other)
{
	if (other <= 0)
	{
		DoClawBreakModel(entity);
		return;
	}
	if (other <= MaxClients)
	{
		if (GetClientTeam(other) != GetEntProp(entity, Prop_Send, "m_iTeamNum"))
		{
			new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			new launcher = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
			if (owner > 0 && launcher > 0) SDKHooks_TakeDamage(other, entity, owner, 23.5, DMG_SLOWBURN|DMG_BUCKSHOT, launcher);
		}
	}
	else
	{
		new String:class[7];
		GetEdictClassname(other, class, sizeof(class));
		if (!StrContains(class, "obj_", false))
		{
			if (GetEntProp(other, Prop_Send, "m_iTeamNum") == GetEntProp(entity, Prop_Send, "m_iTeamNum"))
			{
				if (!GetEntProp(other, Prop_Send, "m_bHasSapper"))
				{
					if (!GetEntProp(other, Prop_Send, "m_bBuilding") && !GetEntProp(other, Prop_Send, "m_bCarryDeploy"))
					{
						new amount = GetEntProp(other, Prop_Send, "m_iMaxHealth") - GetEntProp(other, Prop_Send, "m_iHealth");
						if (amount > 0)
						{
							if (amount > 20) amount = 20;
							SetVariantInt(20);
							AcceptEntityInput(other, "AddHealth");
							FireBuildingHealedEvent(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"), other, amount);
						}
						else if (3 > GetEntProp(other, Prop_Send, "m_iHighestUpgradeLevel") && !GetEntProp(other, Prop_Send, "m_bMiniBuilding"))
						{
							new upgradeMetal = GetEntProp(other, Prop_Send, "m_iUpgradeMetal");
							new hadMetal = upgradeMetal;
							upgradeMetal += 10;
							if (upgradeMetal >= 200)
							{
								SetEntProp(other, Prop_Send, "m_iUpgradeMetal", 0);
								SetEntProp(other, Prop_Send, "m_iHighestUpgradeLevel", GetEntProp(other, Prop_Send, "m_iHighestUpgradeLevel") + 1);
							}
							else SetEntProp(other, Prop_Send, "m_iUpgradeMetal", upgradeMetal);
							FireBuildingHealedEvent(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"), other, upgradeMetal - hadMetal);
						}
					}
				}
				else
				{
					new sapper = -1;
					while ((sapper = FindEntityByClassname(sapper, "obj_attachment_sapper")) != -1)
					{
						if (other != GetEntPropEnt(sapper, Prop_Send, "moveparent")) continue;
						new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
						new launcher = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
						if (owner > 0 && launcher > 0) SDKHooks_TakeDamage(sapper, entity, owner, 20.0, DMG_SLOWBURN|DMG_BUCKSHOT, launcher);
						FireBuildingHealedEvent(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"), other, 1);
						if (GetEntProp(sapper, Prop_Send, "m_iHealth") <= 0) EmitSoundToClient(owner, "weapons/sapper_removed.wav");
					}
				}
				DoClawBreakModel(entity);
			}
			else
			{
				SetVariantInt(20);
				AcceptEntityInput(other, "RemoveHealth");
			}
		}
	}
}

stock DoClawBreakModel(entity)
{
	new Handle:data;
	CreateDataTimer(0.0, Timer_ClawBreakModel, data, TIMER_FLAG_NO_MAPCHANGE);
	new Float:pos[3], Float:ang[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
	for (new i = 0; i <= 2; i++)
	{
		WritePackFloat(data, pos[i]);
		WritePackFloat(data, ang[i]);
	}
	ResetPack(data);
}

public Action:Timer_ClawBreakModel(Handle:timer, Handle:data)
{
	new Float:pos[3], Float:ang[3];
	for (new i = 0; i <= 2; i++)
	{
		pos[i] = ReadPackFloat(data);
		ang[i] = ReadPackFloat(data);
	}
	
	new Handle:message = StartMessageAll("BreakModel");
	BfWriteShort(message, repairclawmodel);
	BfWriteVecCoord(message, pos);
	BfWriteAngles(message, ang);
	EndMessage();
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (attacker <= 0 || attacker > MaxClients) return Plugin_Continue;
	new Action:action;
	if (SapperRageUntil[attacker][victim])
	{
		if (SapperRageUntil[attacker][victim] > GetTickedTime())
		{
			damagetype |= DMG_CRIT;
			action = Plugin_Changed;
		} else SapperRageUntil[attacker][victim] = 0.0;
	}
	if (weapon > -1)
	{
		LastWeaponHurtWith[attacker] = weapon;
		if (HasAttribute[weapon])
		{
			if (HealOnAltFireHit[weapon])
			{
				if ((GetClientButtons(attacker) & (IN_ATTACK|IN_ATTACK2)) == IN_ATTACK2)
				{ // This whole block is from Give Weapon, including that ^ neat bitwise check. I couldn't possibly have done it any better than this.
					new health = GetClientHealth(attacker);
					if (health < GetEntProp(attacker, Prop_Data, "m_iMaxHealth"))
					{
						health += 3;
						SetEntityHealth(attacker, health);
					}
					new Handle:healevent = CreateEvent("player_healonhit", true);
					SetEventInt(healevent, "entindex", attacker);
					SetEventInt(healevent, "amount", 3);
					FireEvent(healevent);
				}
			}
			if (TurnaboutAmmo[weapon] && victim != attacker)
			{
				new ammo = GetAmmo_Weapon(weapon) + TurnaboutAmmoRestore[weapon];
				if (ammo > TurnaboutAmmo[weapon]) ammo = TurnaboutAmmo[weapon];
				SetAmmo_Weapon(weapon, ammo);
				SetClip_Weapon(weapon, ammo);
			}
		}
	}
	return action;
}

public Action:OnTakeDamage_Building(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (attacker <= 0 || attacker > MaxClients) return Plugin_Continue;
	if (GetClientTeam(attacker) == GetEntProp(victim, Prop_Send, "m_iTeamNum")) return Plugin_Continue;
	if (weapon > -1)
	{
		if (HasAttribute[weapon])
		{
			if (TurnaboutAmmo[weapon])
			{
				new ammo = GetAmmo_Weapon(weapon) + 1;
				if (ammo > TurnaboutAmmo[weapon]) ammo = TurnaboutAmmo[weapon];
				SetAmmo_Weapon(weapon, ammo);
				SetClip_Weapon(weapon, ammo);
			}
		}
	}
	return Plugin_Continue;
}

public Action:Listener_destroy(client, const String:command[], args)
{
	for (new i = 0; i < 5; i++)
	{
		new wep = GetPlayerWeaponSlot(client, i);
		if (wep == -1) continue;
		if (!HasAttribute[wep]) continue;
		if (!UserCannotUseDestroy[wep]) continue;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new bool:feign = bool:(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER);
	if (attacker)
	{
		new weapon = LastWeaponHurtWith[attacker];
		if (HasAttribute[weapon])
		{
			if (KillsChargeSniperRifle[weapon] && !feign)
			{
				new primary = GetPlayerWeaponSlot(attacker, 0);
				if (primary > -1)
				{
					new String:class[25];
					GetEdictClassname(primary, class, sizeof(class));
					if (!StrContains(class, "tf_weapon_sniperrifle", false))
					{
						MinimumRifleCharge[primary] += 150.0*KillsChargeSniperRifle[weapon];
						if (MinimumRifleCharge[primary] > 150.0) MinimumRifleCharge[primary] = 150.0;
					}
					else if (!StrContains(class, "tf_weapon_compound_bow", false))
					{
						//m_flChargeBeginTime;
					}
				}
			}
		}
	}
	
	if (feign)
	{
		// Reset minimum rifle charge.
		new primary = GetPlayerWeaponSlot(victim, 0);
		if (primary > -1)
		{
			new String:class[25];
			GetEdictClassname(primary, class, sizeof(class));
			if (!StrContains(class, "tf_weapon_sniperrifle", false)) MinimumRifleCharge[primary] = 0.0;
			else if (!StrContains(class, "tf_weapon_compound_bow", false))
			{
				//m_flChargeBeginTime;
			}
		}
	}
}

public Action:Event_UberCharge(Handle:event, const String:name[], bool:dontBroadcast)
{
	new medic = GetClientOfUserId(GetEventInt(event, "userid"));
	new sec = GetPlayerWeaponSlot(medic, 1);
	if (!HasAttribute[sec]) return;
	if (MediGunRestoresAmmo[sec])
	{
		PlayBadMedispenserUberSounds(medic);
		PlayBadMedispenserUberSounds(GetClientOfUserId(GetEventInt(event, "targetid")));
	}
}

public Action:Event_NPCHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker_player"));
	if (!attacker) return;
	new weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	if (weapon == -1) return;
	if (!HasAttribute[weapon]) return;
	if (!TurnaboutAmmo[weapon]) return;
	new ammo = GetAmmo_Weapon(weapon) + TurnaboutAmmoRestore[weapon];
	if (ammo > TurnaboutAmmo[weapon]) ammo = TurnaboutAmmo[weapon];
	SetAmmo_Weapon(weapon, ammo);
	SetClip_Weapon(weapon, ammo);
}

stock PlayBadMedispenserUberSounds(client)
{
	if (!client) return;
	if (GetTickedTime() < NextBadMedispenserUberSoundsTime[client]) return;
	ClientCommand(client, "playgamesound npc/scanner/cbot_discharge1.wav");
	ClientCommand(client, "playgamesound weapons/physcannon/physcannon_charge.wav");
	NextBadMedispenserUberSoundsTime[client] = GetTickedTime() + 0.2;
}

public Action:Event_SpysSappinMySentry(Handle:event, const String:name[], bool:dontBroadcast)
{
	new spy = GetClientOfUserId(GetEventInt(event, "userid")),
	builder = GetClientOfUserId(GetEventInt(event, "ownerid"));
	
	new sec = GetPlayerWeaponSlot(spy, 1);
	if (!HasAttribute[sec]) return;
	if (SapperCausesRage[sec])
		SapperRageUntil[builder][spy] = GetTickedTime() + SapperCausesRage[sec];
	if (SapperHasCooldown[sec])
	{
		SwitchAwayFromSapper(spy);
		SapperCooldownUntil[spy] = GetTickedTime() + SapperHasCooldown[sec];
	}
	return;
}

stock SwitchAwayFromSapper(spy, Float:delay = 0.2)
{
	CreateTimer(delay, Timer_SwitchAwayFromSapper, GetClientUserId(spy), TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_SwitchAwayFromSapper(Handle:timer, any:uid)
{
	new spy = GetClientOfUserId(uid);
	if (!spy) return;
	new otherwep = GetPlayerWeaponSlot(spy, 0);
	if (otherwep == -1) otherwep = GetPlayerWeaponSlot(spy, 2);
	if (otherwep == -1) otherwep = GetPlayerWeaponSlot(spy, 3);
	SetEntPropEnt(spy, Prop_Send, "m_hActiveWeapon", otherwep); // If this errors with -1 is invalid...oh well.
}

public Action:OnWeaponSwitch(client, Wep)
{
	if (!IsValidEntity(Wep)) return Plugin_Continue;
	if (SapperCooldownUntil[client] >= GetTickedTime())
	{
		new String:class[20];
		GetEdictClassname(Wep, class, sizeof(class));
		if (StrEqual(class, "tf_weapon_builder", false))
		{
			SwitchAwayFromSapper(client, 0.0);
			return Plugin_Stop;
		}
	}
	new wepWithSyringeBoost;
	for (new i = 0; i <= 2; i++)
	{
		new j = GetPlayerWeaponSlot(client, i);
		if (j == -1) continue;
		if (j == Wep) continue;
		if (!HasAttribute[j]) continue;
		if (!SyringeGunChargeBoostUntilUber[j]) continue;
		wepWithSyringeBoost = j;
	}
	if (wepWithSyringeBoost)
	{
		new sec = GetPlayerWeaponSlot(client, 1);
		if (sec > -1)
		{
			if (GetEntProp(sec, Prop_Send, "m_bChargeRelease"))
			{
				SetEntProp(sec, Prop_Send, "m_bChargeRelease", 0);
				CreateTimer(0.0, Timer_ReSetMedigunChargeRelease, EntIndexToEntRef(sec), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	return Plugin_Continue;
}

public Action:Timer_ReSetMedigunChargeRelease(Handle:timer, any:ref)
{
	new ent = EntRefToEntIndex(ref);
	if (ent <= MaxClients) return;
	SetEntProp(ent, Prop_Send, "m_bChargeRelease", 1);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:ang[3], &weapon2)
{
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon <= 0 || weapon > 2048) return Plugin_Continue;
	if (MinimumRifleCharge[weapon])
	{
		new Float:chargeLevel = GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage");
		if (chargeLevel && chargeLevel < MinimumRifleCharge[weapon])
			SetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage", MinimumRifleCharge[weapon]);
	}
	if (!HasAttribute[weapon]) return Plugin_Continue;
	new Action:action;
	if (MediGunSpellUberCharge[weapon] > -1 && buttons & IN_ATTACK2)
	{
		new Float:charge = GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel");
		if (charge >= MediGunSpellUberChargeDeplete[weapon] && (TF2_GetPlayerClass(client) != TFClass_Medic || -1 == GetPlayerWeaponSlot(client, 3)) && !GetEntProp(weapon, Prop_Send, "m_bChargeRelease"))
		{
			new Handle:hWeapon = TF2Items_CreateItem(OVERRIDE_ALL);
			TF2Items_SetClassname(hWeapon, "tf_weapon_spellbook");
			TF2Items_SetItemIndex(hWeapon, 1069);
			TF2Items_SetLevel(hWeapon, 1);
			TF2Items_SetQuality(hWeapon, 0);
			TF2Items_SetNumAttributes(hWeapon, 0);
			
			new entity = TF2Items_GiveNamedItem(client, hWeapon);
			CloseHandle(hWeapon);
			EquipPlayerWeapon(client, entity);
			
			SetEntProp(entity, Prop_Send, "m_iSelectedSpellIndex", MediGunSpellUberCharge[weapon]);
			SetEntProp(entity, Prop_Send, "m_iSpellCharges", 1);
			
			CreateTimer(1.25, Timer_RemoveEnt, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
			
	//		SetEntProp(weapon, Prop_Send, "m_bChargeRelease", 0);
			
			new Float:newAmount;
			while (charge > newAmount && newAmount+MediGunSpellUberChargeDeplete[weapon] <= charge && newAmount >= 0.0)
				newAmount += MediGunSpellUberChargeDeplete[weapon];
			newAmount -= MediGunSpellUberChargeDeplete[weapon];
			SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", newAmount);
			
			EmitSoundToAll("ambient/machines/spinup.wav", client);
		}
	}
	if (SyringeGunChargeBoost[weapon])
	{
		new sec = GetPlayerWeaponSlot(client, 1);
		if (sec > -1)
		{
			new String:cls[17];
			GetEdictClassname(sec, cls, sizeof(cls));
			if (!StrContains(cls[10], "med", false))
			{
				new Float:charge = GetEntPropFloat(sec, Prop_Send, "m_flChargeLevel"), bool:release = bool:GetEntProp(sec, Prop_Send, "m_bChargeRelease");
				if (!release && charge >= SyringeGunChargeBoost[weapon] && buttons & IN_ATTACK2 && GetTickedTime() >= GetEntPropFloat(client, Prop_Send, "m_flNextAttack"))
				{
					SetEntProp(sec, Prop_Send, "m_bChargeRelease", 1);
					TF2_AddCondition(client, TFCond_SpeedBuffAlly, 1.8);
					TF2_AddCondition(client, TFCond_Buffed, 1.8);
					
					EmitSoundToAll("npc/attack_helicopter/aheli_charge_up.wav", client);
					EmitSoundToAll("npc/vort/health_charge.wav", client, _, _, _, _, 70);
					EmitSoundToAll("vehicles/crane/crane_magnet_release.wav", client);
					
					new Float:newAmount;
					while (charge > newAmount && newAmount+SyringeGunChargeBoost[weapon] <= charge && newAmount >= 0.0)
						newAmount += SyringeGunChargeBoost[weapon];
					SetEntPropFloat(sec, Prop_Send, "m_flChargeLevel", newAmount);
					charge = newAmount;
					
					SyringeGunChargeBoostUntilUber[weapon] = charge - (SyringeGunChargeBoost[weapon]*0.98);
					if (SyringeGunChargeBoostUntilUber[weapon] < 0.0) SyringeGunChargeBoostUntilUber[weapon] = 0.0;
					
					/*new Handle:data;
					CreateDataTimer(0.1, Timer_CheckIfTheyArentUsingSyringeGunBoost, data, TIMER_FLAG_NO_MAPCHANGE);
					WritePackCell(data, GetClientUserId(client));
					WritePackCell(data, EntIndexToEntRef(weapon));
					ResetPack(data);*/
					
					TF2Attrib_SetByName(weapon, "honorbound", 1.0);
				}
				if (release && charge <= SyringeGunChargeBoostUntilUber[weapon])
				{
					if (!(buttons & IN_ATTACK2) || charge < SyringeGunChargeBoost[weapon])
					{
						// Stop the boost
						SetEntProp(sec, Prop_Send, "m_bChargeRelease", 0);
						SyringeGunChargeBoostUntilUber[weapon] = 0.0;
						
						StopSound(client, SNDCHAN_AUTO, "npc/attack_helicopter/aheli_charge_up.wav");
						StopSound(client, SNDCHAN_AUTO, "npc/vort/health_charge.wav");
						StopSound(client, SNDCHAN_AUTO, "vehicles/crane/crane_magnet_release.wav");
						
						TF2Attrib_RemoveByName(weapon, "honorbound");
					}
					else
					{
						TF2_AddCondition(client, TFCond_SpeedBuffAlly, 1.8);
						TF2_AddCondition(client, TFCond_Buffed, 1.8);
						
						SyringeGunChargeBoostUntilUber[weapon] = charge - SyringeGunChargeBoost[weapon];
						if (SyringeGunChargeBoostUntilUber[weapon] < 0.0) SyringeGunChargeBoostUntilUber[weapon] = 0.0;
					}
				}
			}
		}
		buttons &= ~IN_ATTACK2;
		action = Plugin_Changed;
	}
	if (ReduxHypeBonus[weapon] && !ReduxHypeBonusDraining[weapon])
	{
		new bool:charged;
		if (ReduxHypeBonusCharged[weapon] < ReduxHypeBonus[weapon])
		{
			new Float:myVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", myVel);
			for (new i = 0; i <= 2; i++)
			{
				if (myVel[i] < 0.0) myVel[i] *= -1.0;
				myVel[i] /= ReduxHypeBonus[weapon]/60.0;
				ReduxHypeBonusCharged[weapon] += myVel[i];
			}
			if (ReduxHypeBonusCharged[weapon] >= ReduxHypeBonus[weapon])
			{
				charged = true;
				ReduxHypeBonusCharged[weapon] = ReduxHypeBonus[weapon];
				ClientCommand(client, "playgamesound player/recharged.wav");
			}
		}
		else charged = true;
		
		if (charged && buttons & IN_ATTACK2)
		{
			ReduxHypeBonusDraining[weapon] = true;
			TF2Attrib_SetByName(weapon, "move speed bonus", 1.125);
			TF2Attrib_SetByName(weapon, "increased jump height from weapon", 1.35);
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.001);
			ClientCommand(client, "playgamesound weapons/discipline_device_power_up.wav");
			CreateTimer(0.0, Timer_DrainHype, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE);
			CreateTimer(10.0, Timer_RemoveHypeBonus, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	if (FiresLasers[weapon])
	{
		if (buttons & IN_ATTACK && !(buttons & IN_ATTACK2))
		{
			buttons |= IN_ATTACK2;
			action = Plugin_Changed;
		}
	}
	return action;
}

public Action:Timer_DrainHype(Handle:timer, any:ref)
{	// kinda horrible, but meh
	new ent = EntRefToEntIndex(ref);
	if (ent <= MaxClients) return;
	ReduxHypeBonusCharged[ent] -= ReduxHypeBonus[ent]/100.0;
	if (ReduxHypeBonusCharged[ent] <= 0.0 || !ReduxHypeBonusDraining[ent])
	{
		ReduxHypeBonusCharged[ent] = 0.0;
//		ReduxHypeBonusDraining[ent] = false;
	}
	else CreateTimer(0.0, Timer_DrainHype, ref, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_RemoveHypeBonus(Handle:timer, any:ref)
{
	new ent = EntRefToEntIndex(ref);
	if (ent <= MaxClients) return;
	ReduxHypeBonusDraining[ent] = false;
	ReduxHypeBonusCharged[ent] = 0.0;
	TF2Attrib_RemoveByName(ent, "move speed bonus");
	TF2Attrib_RemoveByName(ent, "increased jump height from weapon");
	new client = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	if (client == -1) return; // uwotm8
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.001);
	ClientCommand(client, "playgamesound weapons/discipline_device_power_down.wav");
}

/*public Action:Timer_CheckIfTheyArentUsingSyringeGunBoost(Handle:timer, Handle:data)
{
	new client = GetClientOfUserId(ReadPackCell(data));
	if (!client) return;
	new weapon = EntRefToEntIndex(ReadPackCell(data));
	if (weapon <= MaxClients) return;
	if (!HasAttribute[weapon]) return; // Attribute lost.
	if (!SyringeGunChargeBoost[weapon]) return; // Attribute lost.
	if (!SyringeGunChargeBoostUntilUber[weapon]) return; // Uber ended.
	if (weapon == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
	{ // OnPlayerRunCmd will handle this.
		new Handle:data2;
		CreateDataTimer(0.1, Timer_CheckIfTheyArentUsingSyringeGunBoost, data2, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data2, GetClientUserId(client));
		WritePackCell(data2, EntIndexToEntRef(weapon));
		ResetPack(data2);
		return;
	}
	new sec = GetPlayerWeaponSlot(client, 1);
	if (sec == -1) return; // Uber basically lost.
	if (!GetEntProp(sec, Prop_Send, "m_bChargeRelease")) return; // Uber ended. (Shouldn't happen...? Maybe. Just to be safe.)
	if (GetEntPropFloat(sec, Prop_Send, "m_flChargeLevel") > SyringeGunChargeBoostUntilUber[weapon])
	{ // Charge still draining.
		new Handle:data2;
		CreateDataTimer(0.1, Timer_CheckIfTheyArentUsingSyringeGunBoost, data2, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data2, GetClientUserId(client));
		WritePackCell(data2, EntIndexToEntRef(weapon));
		ResetPack(data2);
		return;
	}
	
	// If we're this far, then the boost should be over. End it.
	SetEntProp(sec, Prop_Send, "m_bChargeRelease", 0);
	SyringeGunChargeBoostUntilUber[weapon] = 0.0;
	
	StopSound(client, SNDCHAN_AUTO, "npc/attack_helicopter/aheli_charge_up.wav");
	StopSound(client, SNDCHAN_AUTO, "npc/vort/health_charge.wav");
	StopSound(client, SNDCHAN_AUTO, "vehicles/crane/crane_magnet_release.wav");
}*/

public TF2_OnConditionAdded(client, TFCond:cond)
{
	new sec = GetPlayerWeaponSlot(client, 1);
	if (sec > -1)
	{
		if (MediGunSharesPositiveBoosts[sec]) CheckAndShareGoodConditions(client, GetMediGunPatient(client));
	}
	if (cond == TFCond_Cloaked)
	{
		new invis = GetPlayerWeaponSlot(client, 4);
		if (invis > -1)
		{
			if (HasAttribute[invis])
			{
				if (CloakLeechesHealth[invis])
				{
					new uid = GetClientUserId(client);
					hRefillCloakTimer[client] = CreateTimer(0.1, Timer_RefillCloak, uid, TIMER_FLAG_NO_MAPCHANGE);
					hLeechHealthTimer[client] = CreateTimer(1.0, Timer_LeechHealth, uid, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

public TF2_OnConditionRemoved(client, TFCond:cond)
{
	if (cond == TFCond_Cloaked)
	{
//		if (hRefillCloakTimer[client] != INVALID_HANDLE) CloseHandle(hRefillCloakTimer[client]);
//		if (hLeechHealthTimer[client] != INVALID_HANDLE) CloseHandle(hLeechHealthTimer[client]);
		hRefillCloakTimer[client] = INVALID_HANDLE;
		hLeechHealthTimer[client] = INVALID_HANDLE;
	}
}

public Action:Timer_RefillCloak(Handle:timer, any:uid)
{
	new client = GetClientOfUserId(uid);
	if (timer != hRefillCloakTimer[client]) return;
	new invis = GetPlayerWeaponSlot(client, 4);
	if (invis == -1) return;
	if (!HasAttribute[invis]) return;
	if (!CloakLeechesHealth[invis]) return;
	SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", 120.0);
	hRefillCloakTimer[client] = CreateTimer(0.1, Timer_RefillCloak, uid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_LeechHealth(Handle:timer, any:uid)
{
	new client = GetClientOfUserId(uid);
	if (timer != hLeechHealthTimer[client]) return;
	new invis = GetPlayerWeaponSlot(client, 4);
	if (invis == -1) return;
	if (!HasAttribute[invis]) return;
	if (!CloakLeechesHealth[invis]) return;
	if (!TF2_IsPlayerInCondition(client, TFCond_Cloaked)) return;
	new HP = GetClientHealth(client), leech = CloakLeechesHealth[invis];
	if (HP > leech*-1)
	{
		hLeechHealthTimer[client] = CreateTimer(1.0, Timer_LeechHealth, uid, TIMER_FLAG_NO_MAPCHANGE);
		SetEntityHealth(client, HP + leech);
		/*new Handle:healevent = CreateEvent("player_healonhit", true);
		SetEventInt(healevent, "entindex", client);
		SetEventInt(healevent, "amount", leech);
		FireEvent(healevent);*/ // causes particles to appear while the spy is cloaked
	}
	else
	{
		SDKHooks_TakeDamage(client, client, client, float((leech*-1)*10));
		hLeechHealthTimer[client] = INVALID_HANDLE;
	}
}

public Action:SoundHook(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (entity <= 0 || entity > MaxClients) return Plugin_Continue;
	new client = entity;
	if (StrContains(sound, "vo", false) > -1)
	{
		if (StrContains(sound, "medic_specialcompleted04", false) > -1 ||
		StrContains(sound, "medic_specialcompleted05", false) > -1 ||
		StrContains(sound, "medic_specialcompleted06", false) > -1 ||
		StrContains(sound, "medic_taunts03", false) > -1 ||
		StrContains(sound, "medic_taunts09", false) > -1)
		{
			new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (wep > -1)
			{
				if (HasAttribute[wep])
				{
					if (MediGunSpeedBoostUber[wep])
					{
						Format(sound, sizeof(sound), "vo/medic_go0%i.wav", GetRandomInt(1,5));
						PrecacheSound(sound);
						return Plugin_Changed;
					}
					else if (MediGunRestoresAmmo[wep])
					{
						switch (GetRandomInt(1,5))
						{
							case 1: Format(sound, sizeof(sound), "vo/medic_sf12_taunts02.wav");
							case 2: Format(sound, sizeof(sound), "vo/medic_sf12_taunts03.wav");
							case 3: Format(sound, sizeof(sound), "vo/medic_sf13_influx_big02.wav");
							case 4: Format(sound, sizeof(sound), "vo/taunts/medic_taunts07.wav");
							case 5: Format(sound, sizeof(sound), "vo/medic_mvm_heal_shield02.wav");
						}
						PrecacheSound(sound);
						return Plugin_Changed;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:Timer_TenTimesASecond(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		if (!IsPlayerAlive(client)) continue;
		
		new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (wep == -1) continue;
		if (!HasAttribute[wep]) continue;
		
		new healingTargetChanged;
		if (TrackPatientChanges[wep])
		{
			new patient = GetMediGunPatient(client);
			if (patient != LastHealingTarget[client])
				healingTargetChanged = patient;
			LastHealingTarget[client] = patient;
		}
		
		if (MediGunRestoresAmmo[wep])
		{
			new patient = GetMediGunPatient(client);
			if (patient > -1 && patient <= MaxClients)
			{
				if (IsPlayerAlive(patient))
				{
					if (!GetEntProp(wep, Prop_Send, "m_bChargeRelease"))
					{
						for (new j = 0; j <= 2; j++)
						{
							new patientWeapon = GetPlayerWeaponSlot(patient, j);
							if (patientWeapon == -1) continue;
							switch (GetEntProp(patientWeapon, Prop_Send, "m_iItemDefinitionIndex"))
							{	case 527, 528: continue;	}
							new maxAmmo = MaxAmmo[patientWeapon];
							if (maxAmmo < 2) continue;
							new Ammo = GetAmmo_Weapon(patientWeapon);
							if (Ammo == maxAmmo) continue;
							new Float:flAmmo = float(Ammo);
							flAmmo += maxAmmo*(MediGunRestoresAmmo[wep]*0.1);
							Ammo = RoundToFloor(flAmmo);
							AmmoFractionFillProgress[patientWeapon] += (flAmmo - Ammo);
							if (AmmoFractionFillProgress[patientWeapon] > 1.0)
							{
								AmmoFractionFillProgress[patientWeapon] -= 1.0;
								Ammo++;
							}
							SetAmmo_Weapon(patientWeapon, Ammo);
						}
					}
					else
					{
						new activeWeapon;
						for (new j = 0; j <= 2; j++)
						{
							new patientWeapon = GetPlayerWeaponSlot(patient, j);
							if (patientWeapon == -1) continue;
							switch (GetEntProp(patientWeapon, Prop_Send, "m_iItemDefinitionIndex"))
							{	case 527, 528: continue;	}
							if (patientWeapon == GetEntPropEnt(patient, Prop_Send, "m_hActiveWeapon")) activeWeapon = patientWeapon;
							new maxAmmo = MaxAmmo[patientWeapon], maxClip = MaxClip[patientWeapon], Float:maxEnergy = MaxEnergy[patientWeapon];
							if (maxAmmo > 1) SetAmmo_Weapon(patientWeapon, maxAmmo);
							if (maxClip > 1) SetClip_Weapon(patientWeapon, maxClip);
							if (maxEnergy > 1.0) SetEntPropFloat(patientWeapon, Prop_Send, "m_flEnergy", maxEnergy);
						}
						
						if (GetTickedTime() >= CreateNextMedispenserParticle[patient] && activeWeapon)
						{	
							for (new p = 0; p <= 2; p++)
							{
								new particle = CreateEntityByName("info_particle_system");
								DispatchKeyValue(particle, "effect_name", "flare_sparks");
								new Float:pos[3];
								GetClientEyePosition(patient, pos);
								pos[2] -= 70.0; // In case the weapon does not have a weapon_bone. Some weapons do not, such as the stock minigun
								TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
								SetVariantString("!activator");
								AcceptEntityInput(particle, "SetParent", activeWeapon);
								SetVariantString("weapon_bone");
								AcceptEntityInput(particle, "SetParentAttachment");
								DispatchSpawn(particle);
								ActivateEntity(particle);
								AcceptEntityInput(particle, "Start");
								CreateTimer(0.5, Timer_RemoveEnt, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
							}
							CreateNextMedispenserParticle[patient] = GetTickedTime() + 0.5;
						}
						
						if (healingTargetChanged)
						{
							PlayBadMedispenserUberSounds(patient);
						}
					}
				}
			}
		}
		if (MediGunSharesPositiveBoosts[wep])
		{
			if (healingTargetChanged && healingTargetChanged > -1 && healingTargetChanged <= MaxClients)
				if (IsPlayerAlive(healingTargetChanged)) CheckAndShareGoodConditions(client, healingTargetChanged);
		}
		if (MediGunSpeedBoostUber[wep])
		{
			if (GetEntProp(wep, Prop_Send, "m_bChargeRelease"))
			{
				TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.2);
				new patient = GetMediGunPatient(client);
				if (patient > -1 && patient <= MaxClients)
				{
					if (IsPlayerAlive(patient))
					{
						TF2_AddCondition(patient, TFCond_SpeedBuffAlly, 0.2);
						new Float:myPos[3], Float:patientPos[3];
						GetClientAbsOrigin(client, myPos);
						GetClientAbsOrigin(patient, patientPos);
						if (375.0 < GetVectorDistance(myPos, patientPos))
						{
							new Float:medicSpeed = GetCurrentSpeed(client), Float:patientSpeed = GetCurrentSpeed(patient);
							
							new faster = medicSpeed > patientSpeed ? client : patient;
							new slower = faster == client ? patient : client;
							
							new Float:fastestSpeed = medicSpeed > patientSpeed ? medicSpeed : patientSpeed;
							
							if (fastestSpeed && GetClientButtons(slower) & IN_JUMP)
							{
								new Float:vel[3];
								GetEntPropVector(faster, Prop_Data, "m_vecVelocity", vel);
								for (new i = 0; i <= 1; i++)
									vel[i] *= 1.9;
								if (vel[2] != 0.0)
								{
									for (new i = 0; i <= 1; i++)
										vel[i] *= 0.6;
								}
								TeleportEntity(slower, NULL_VECTOR, NULL_VECTOR, vel);
							}
						}
					}
				}
			}
		}
		if (TurnaboutAmmo[wep])
		{
			SetClip_Weapon(wep, GetAmmo_Weapon(wep));
		}
		if (SyringeGunChargeBoost[wep])
		{
			new sec = GetPlayerWeaponSlot(client, 1);
			if (sec > -1)
			{
				new String:cls[17];
				GetEdictClassname(sec, cls, sizeof(cls));
				if (!StrContains(cls[10], "med", false))
				{
					new Float:charge = GetEntPropFloat(sec, Prop_Send, "m_flChargeLevel");
					new boosts = -1; // cruddy method, but ech
					for (new Float:i; i <= charge; i += SyringeGunChargeBoost[wep])
					{
						if (SyringeGunChargeBoost[wep] < 0.0) break;
						boosts++;
					}
					SetHudTextParams(-1.0, 0.7, 0.2, 255, 255, 255, 255);
					//ShowSyncHudText(client, hudText_Client, "%s\nUberCharge: %i%%", (!SyringeGunChargeBoostUntilUber[wep] && charge > SyringeGunChargeBoost[wep] && !GetEntProp(sec, Prop_Send, "m_bChargeRelease")) ? "- ALTFIRE to use BOOST -" : "", RoundToFloor(charge*100));
					ShowSyncHudText(client, hudText_Client, "%s\nBoosts: %i (%i%%)", (!SyringeGunChargeBoostUntilUber[wep] && charge >= SyringeGunChargeBoost[wep] && !GetEntProp(sec, Prop_Send, "m_bChargeRelease")) ? "- ALTFIRE to use BOOST -" : "", boosts, RoundToFloor(charge*100));
				}
			}
		}
		if (MediGunSpellUberCharge[wep] > -1)
		{
			new sec = GetPlayerWeaponSlot(client, 1);
			if (sec > -1)
			{
				new Float:charge = GetEntPropFloat(sec, Prop_Send, "m_flChargeLevel");
				new ubers = -1;
				for (new Float:i; i <= charge; i += MediGunSpellUberChargeDeplete[wep])
				{
					if (MediGunSpellUberChargeDeplete[wep] < 0.0) break;
					ubers++;
				}
				SetHudTextParams(0.75, 0.82, 0.2, 255, 255, 255, 255);
				ShowSyncHudText(client, hudText_Client, "UberCharges: %i", ubers);
			}
		}
		if (ReduxHypeBonus[wep])
		{
			new Float:flOtherClr = 255.0 - (255.0 * ReduxHypeBonusCharged[wep] / ReduxHypeBonus[wep]);
			if (ReduxHypeBonusDraining[wep])
			{
				flOtherClr /= 2.5;
				if (flOtherClr > 255.0) flOtherClr = 255.0;
			}
			new otherClr = RoundFloat(flOtherClr);
			SetHudTextParams(0.75, 0.82, 0.2, 255, otherClr, otherClr, 255);
			ShowSyncHudText(client, hudText_Client, "Hype: %i%%", RoundToFloor(100.0 * ReduxHypeBonusCharged[wep] / ReduxHypeBonus[wep]));
		}
		
//		for (new i = 0; i <= 5; i++)
//		{
//			new wep = GetPlayerWeaponSlot(client, i);
//			if (wep == -1) continue;
//			if (!HasAttribute[wep]) continue;
//			...
//		}
	}
}

stock Float:GetCurrentSpeed(client, bool:air = false)
{
	new Float:vel[3], Float:speed;
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	for (new i = 0; i <= ((air) ? 2 : 1); i++)
	{
		if (vel[i] < 0.0) vel[i] *= -1.0;
		speed += vel[i];
	}
	return speed;
}

public OnEntityCreated(Ent, const String:cls[])
{
	if (Ent < 0 || Ent > 2048) return;
	if (!StrContains(cls, "tf_weapon_")) CreateTimer(0.3, OnWeaponSpawned, EntIndexToEntRef(Ent));
	else if (!StrContains(cls, "obj_")) CreateTimer(0.3, OnBuildingSpawned, EntIndexToEntRef(Ent));
}

public Action:OnWeaponSpawned(Handle:timer, any:ref)
{
	new Ent = EntRefToEntIndex(ref);
	if (!IsValidEntity(Ent) || Ent == -1) return;
	new owner = GetEntPropEnt(Ent, Prop_Send, "m_hOwnerEntity");
	if (owner == -1) return;
	new String:cls[20];
	GetEdictClassname(Ent, cls, sizeof(cls));
	if (StrEqual(cls, "tf_weapon_wrench", false) && TFClass_Engineer == TF2_GetPlayerClass(owner))
	{
		MaxAmmo[Ent] = 200;
		AmmoIsMetal[Ent] = true;
	}
	else MaxAmmo[Ent] = GetAmmo_Weapon(Ent);
	switch (GetEntProp(Ent, Prop_Send, "m_iItemDefinitionIndex"))
	{
		case 441, 442, 588: MaxEnergy[Ent] = GetEntPropFloat(Ent, Prop_Send, "m_flEnergy");
		default: MaxClip[Ent] = GetClip_Weapon(Ent);
	}
	return;
}

public Action:OnBuildingSpawned(Handle:timer, any:ref)
{
	new Ent = EntRefToEntIndex(ref);
	if (!IsValidEntity(Ent) || Ent == -1) return;
	SDKHook(Ent, SDKHook_OnTakeDamage, OnTakeDamage_Building);
	return;
}

public OnEntityDestroyed(Ent)
{
	if (Ent <= 0 || Ent > 2048) return;
	HasAttribute[Ent] = false;
	FiresFastFixBolts[Ent] = false;
	HealOnAltFireHit[Ent] = 0;
	UserCannotUseDestroy[Ent] = false;
	KillsChargeSniperRifle[Ent] = 0.0;
	CloakLeechesHealth[Ent] = 0;
	MediGunRestoresAmmo[Ent] = 0.0;
	MediGunSharesPositiveBoosts[Ent] = false;
	MediGunSpeedBoostUber[Ent] = false;
	TurnaboutAmmo[Ent] = 0;
	TurnaboutAmmoRestore[Ent] = 0;
	SapperCausesRage[Ent] = 0.0;
	SapperHasCooldown[Ent] = 0.0;
	MediGunSpellUberCharge[Ent] = -1;
	MediGunSpellUberChargeDeplete[Ent] = 0.0;
	SyringeGunChargeBoost[Ent] = 0.0;
	ReduxHypeBonus[Ent] = 0.0;
	FiresLasers[Ent] = 0.0;
	
	MinimumRifleCharge[Ent] = 0.0;
	MinimumBowCharge[Ent] = 0.0;
	MaxClip[Ent] = 0;
	MaxAmmo[Ent] = 0;
	MaxEnergy[Ent] = 0.0;
	AmmoFractionFillProgress[Ent] = 0.0;
	AmmoIsMetal[Ent] = false;
	SyringeGunChargeBoostUntilUber[Ent] = 0.0;
	ReduxHypeBonusCharged[Ent] = 0.0;
	ReduxHypeBonusDraining[Ent] = false;
}

stock FireBuildingHealedEvent(client, building, amount)
{
	if (client <= 0 || client > MaxClients) return;
	
	new Handle:event = CreateEvent("building_healed");
	SetEventInt(event, "building", building);
	SetEventInt(event, "healer", client);
	SetEventInt(event, "amount", amount);
	FireEvent(event);
}

stock GetClip_Weapon(weapon)
{
	new iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
	return GetEntData(weapon, iAmmoTable, 4);
}

stock GetAmmo_Weapon(weapon)
{
	if (weapon == -1) return 0;
	new owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner == -1) return 0;
	if (!AmmoIsMetal[weapon])
	{
		new iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		return GetEntData(owner, iAmmoTable+iOffset, 4);
	}
	else return GetEntProp(owner, Prop_Data, "m_iAmmo", 4, 3);
}

stock SetClip_Weapon(weapon, newClip)
{
	new iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
	SetEntData(weapon, iAmmoTable, newClip, 4, true);
}

stock SetAmmo_Weapon(weapon, newAmmo)
{
	new owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner == -1) return;
	if (!AmmoIsMetal[weapon])
	{
		new iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(owner, iAmmoTable+iOffset, newAmmo, 4, true);
	}
	else SetEntProp(owner, Prop_Data, "m_iAmmo", newAmmo, 4, 3);
}

stock CheckAndShareGoodConditions(client, patient)
{
	new TFCond:cond, TFCond:actualcond;
	for (new i = 0; i <= 23; i++)
	{
		switch (i)
		{
			case 0: cond = TFCond_Ubercharged;
			case 1: cond = TFCond_Kritzkrieged;
			case 2: cond = TFCond_Buffed;
			case 3: cond = TFCond_DefenseBuffed;
			case 4: cond = TFCond_MegaHeal;
			case 5: cond = TFCond_RegenBuffed;
			case 6: cond = TFCond_SpeedBuffAlly;
			case 7: cond = TFCond_HalloweenCritCandy;
			case 8: cond = TFCond_CritCanteen;
			case 9: cond = TFCond_CritHype;
			case 10: cond = TFCond_CritOnFirstBlood;
			case 11: cond = TFCond_CritOnWin;
			case 12: cond = TFCond_CritOnFlagCapture;
			case 13: cond = TFCond_CritOnKill;
			case 14: cond = TFCond_UberchargedHidden;
			case 15: cond = TFCond_UberchargedCanteen;
			case 16: cond = TFCond_CritOnDamage;
			case 17: cond = TFCond_UberchargedOnTakeDamage;
			case 18: cond = TFCond_UberBulletResist;
			case 19: cond = TFCond_UberBlastResist;
			case 20: cond = TFCond_UberFireResist;
			case 21: cond = TFCond_SmallBulletResist;
			case 22: cond = TFCond_SmallBlastResist;
			case 23: cond = TFCond_SmallFireResist;
		}
		actualcond = cond;
		if (patient == -1) continue; // wat
		if (GetMediGunPatient(patient) == client) continue;
		if (!TF2_IsPlayerInCondition(client, cond)) continue;
		if (actualcond == TFCond_Kritzkrieged) cond = TFCond_HalloweenCritCandy;
		TF2_AddCondition(patient, cond, 0.3);
		new Handle:data;
		CreateDataTimer(0.2, Timer_CheckMedispenserCondition, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, GetClientUserId(client));
		WritePackCell(data, GetClientUserId(patient));
		WritePackCell(data, _:actualcond);
		ResetPack(data);
	}
}

public Action:Timer_CheckMedispenserCondition(Handle:timer, Handle:data)
{
	new client = GetClientOfUserId(ReadPackCell(data));
	if (!client) return;
	if (!IsPlayerAlive(client)) return;
	new patient = GetClientOfUserId(ReadPackCell(data));
	if (!patient) return;
	if (!IsPlayerAlive(patient)) return;
	new TFCond:cond = TFCond:ReadPackCell(data);
	new TFCond:actualcond = cond;
	if (actualcond == TFCond_Kritzkrieged) cond = TFCond_HalloweenCritCandy;
	if (GetMediGunPatient(client) != patient ||
	GetMediGunPatient(patient) == client ||
	!TF2_IsPlayerInCondition(client, actualcond))
	{
//		TF2_RemoveCondition(patient, cond);
		return;
	}
	TF2_AddCondition(patient, cond, 0.3);
	new Handle:data2;
	CreateDataTimer(0.2, Timer_CheckMedispenserCondition, data2, TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(data2, GetClientUserId(client));
	WritePackCell(data2, GetClientUserId(patient));
	WritePackCell(data2, _:actualcond);
	ResetPack(data2);
}

stock GetMediGunPatient(client)
{
	new wep = GetPlayerWeaponSlot(client, 1);
	if (wep == -1 || wep != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")) return -1;
	new String:class[15];
	GetEdictClassname(wep, class, sizeof(class));
	if (StrContains(class, "tf_weapon_med", false)) return -1;
	return GetEntProp(wep, Prop_Send, "m_bHealing") ? GetEntPropEnt(wep, Prop_Send, "m_hHealingTarget") : -1;
}

public Action:Timer_RemoveEnt(Handle:timer, any:ref)
{
	new ent = EntRefToEntIndex(ref);
	if (ent <= MaxClients) return;
	AcceptEntityInput(ent, "Kill");
}

public bool:TraceRayDontHitSelf(Ent, Mask, any:Hit) return Ent != Hit;