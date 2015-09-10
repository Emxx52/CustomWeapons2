#pragma semicolon 1
#include <tf2_stocks>
#include <sdkhooks>
#include <customweaponstf>

#define PLUGIN_VERSION "beta 2"

public Plugin:myinfo = {
    name = "Custom Weapons: Basic Attributes",
    author = "MasterOfTheXP",
    description = "Standard custom attributes.",
    version = PLUGIN_VERSION,
    url = "http://mstr.ca/"
};

/* *** Attributes In This Plugin ***
  !  "speed boost on hit teammate"
       "<user's speed boost duration> <teammate's>"
	   Upon hitting a teammate, both of your speeds will be boosted
	   for N seconds.
	   Can currently only be used on hitscan weapons and melee weapons,
	   due to TraceAttack not having a weapon parameter. :c
  -> "aim punch multiplier"
       "<multiplier>"
	   Upon hitting an enemy, the "aim punch" applied to their aim
	   will be multiplied by this amount.
	   High amounts are useful for disorienting enemies,
	   and low amounts will disable aim punch to prevent throwing off enemies.
  -> "aim punch to self"
       "<multiplier>"
	   Upon attacking with this weapon, the user will receive this much aim punch.
  -> "look down attack velocity"
       "<start velocity> <push velocity>"
	   When the user looks down and attacks with this weapon,
	   they will be pushed up into the air by N Hammer units.
	   "Start" value is for if the user is on the ground,
	   "push" is applied when they are already vertically moving.
  -> "add metal on attack"
       "<amount>"
	   Each time the user attacks with this weapon, they will gain this much metal.
	   You probably want to use a negative value with this attribute.
	   If negative, the user won't be able to fire this weapon unless they have
	   sufficient metal.
  -> "infinite ammo"
       "<ammo counter>"
	   This weapon's offhand ammo count will always be set to this amount.
	   If you're going to use this attribute, you also ought to add either
	   "hidden primary max ammo bonus" or "hidden secondary max ammo penalty" (TF2 attributes)
	   to your weapon, setting them to 0.0.
	   That way, the user cannot pick up and waste precious ammo packs and dropped weapons.
  -> "crits ignite"
	   Critical hits from this weapon will ignite the victim.
  -> "crit damage multiplier"
	   <multiplier>
	   Scales the amount of crit damage from this weapon.
	   The multiplier is applied to the base damage, so 1.5 on a sniper rifle headshot =
	   50 * 1.5 = 75, and 75 * 3 = 225.
*/

// Here's where we store attribute values, which are received when the attribute is applied.
// There's one for each of the 2048 (+1) edict slots, which will sometimes be weapons.
// For example, when "crit damage multiplier" "0.6" is set on a weapon, we want
// CritDamage[thatweaponindex] to be set to 0.6, so we know to multiply the crit damage by 0.6x.
// There's also HasAttribute[2049], for a super-marginal performance boost. Don't touch it.
new bool:HasAttribute[2049];
new bool:TeammateSpeedBoost[2049];
new Float:TeammateSpeedBoost_User[2049];
new Float:TeammateSpeedBoost_Teammate[2049];
new Float:AimPunchMultiplier[2049] = {1.0, ...};
new Float:AimPunchToSelf[2049] = {0.0, ...};
new bool:LookDownAttackVelocity[2049];
new Float:LookDownAttackVelocity_Start[2049];
new Float:LookDownAttackVelocity_Push[2049];
new AddMetalOnAttack[2049];
new InfiniteAmmo[2049];
new bool:CritsIgnite[2049];
new Float:CritDamage[2049] = {1.0, ...};

// Here's a great spot to place "secondary" variables used by attributes, such as
// "ReduxHypeBonusDraining[2049]" (custom-attributes.sp) or client variables,
// like the one seen below, which shows the next time we can play a "click" noise.
new Float:NextOutOfAmmoSoundTime[MAXPLAYERS + 1];

public OnPluginStart()
{
	// We'll set weapons' ammo counts every ten times a second if they have infinite ammo.
	CreateTimer(0.1, Timer_TenTimesASecond, _, TIMER_REPEAT);
	
	// Since we're hooking damage (seen below), we need to hook the below hooks on players who were
	// already in the game when the plugin loaded, if any.
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		OnClientPutInServer(i);
	}
}

// Usually, you'll want to hook damage done to players, using SDK Hooks.
// You'll need to do so in OnPluginStart (taken care of above) and in OnClientPutInServer.
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

// This is called whenever a custom attribute is added, so first...
public Action:CustomWeaponsTF_OnAddAttribute(weapon, client, const String:attrib[], const String:plugin[], const String:value[])
{
	// Filter out other plugins. If "plugin" is not "basic-attributes", then ignore this attribute.
	if (!StrEqual(plugin, "basic-attributes")) return Plugin_Continue;
	
	// "action" here is what we'll return to the base Custom Weapons plugin when we're done.
	// It defaults to "Plugin_Continue" which means the attribute wasn't recognized. So let's check if we
	// know what attribute this is...
	new Action:action;
	
	// Compare the attribute's name against each of our own.
	// In this case, if it's "aim punch multiplier"...
	if (StrEqual(attrib, "aim punch multiplier"))
	{
		// ...then get the number from the "value" string, and remember that.
		AimPunchMultiplier[weapon] = StringToFloat(value);
		
		// We recognize the attribute and are ready to make it work!
		action = Plugin_Handled;
	}
	// If it wasn't aim punch multiplier, was it any of our other attributes?
	else if (StrEqual(attrib, "speed boost on hit teammate"))
	{
		// Here, we use ExplodeString to get two numbers out of the same string.
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		// ...And then set them to two different variables.
		TeammateSpeedBoost_User[weapon] = StringToFloat(values[0]);
		TeammateSpeedBoost_Teammate[weapon] = StringToFloat(values[1]);
		
		// This attribute could potentially be used to ONLY give a speed boost to the user,
		// or ONLY the teammate, so we use a third boolean variable to see if it's on.
		TeammateSpeedBoost[weapon] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "aim punch to self"))
	{
		AimPunchToSelf[weapon] = StringToFloat(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "look down attack velocity"))
	{
		new String:values2[2][10];
		ExplodeString(value, " ", values2, sizeof(values2), sizeof(values[]));
		
		LookDownAttackVelocity_Start[weapon] = StringToFloat(values2[0]);
		LookDownAttackVelocity_Push[weapon] = StringToFloat(values2[1]);
		
		LookDownAttackVelocity[weapon] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "add metal on attack"))
	{
		AddMetalOnAttack[weapon] = StringToInt(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "infinite ammo"))
	{
		InfiniteAmmo[weapon] = StringToInt(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "crits ignite"))
	{
		// Some attributes are simply on/off, so we don't need to check the "value" string.
		CritsIgnite[weapon] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "crit damage multiplier"))
	{
		CritDamage[weapon] = StringToFloat(value);
		action = Plugin_Handled;
	}
	
	// If the weapon isn't already marked as custom (as far as this plugin is concerned)
	// then mark it as custom, but ONLY if we've set "action" to Plugin_Handled.
	if (!HasAttribute[weapon]) HasAttribute[weapon] = bool:action;
	
	// Let Custom Weapons know that we're going to make the attribute work (Plugin_Handled)
	// or let it print a warning (Plugin_Continue).
	return action;
}
// ^ Remember, this is called once for every custom attribute (attempted to be) applied!


// Now, let's start making those attributes work.
// Every time a player takes damage, we'll check if the weapon that the attacker used
// has one of our attributes.
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (attacker <= 0 || attacker > MaxClients) return Plugin_Continue; // Attacker isn't valid, so the weapon won't be either.
	if (weapon == -1) return Plugin_Continue; // Weapon is invalid, so it won't be custom.
	if (!HasAttribute[weapon]) return Plugin_Continue; // Weapon is valid, but doesn't have one of our attributes. We don't care!
	
	// If we've gotten this far, we might need to take "action" c:
	// But, seriously, we might. Our "action" will be set to Plugin_Changed if we
	// change anything about this damage.
	new Action:action;
	
	// Does this weapon have the "aim punch multiplier" attribute? 1.0 is the default for this attribute, so let's compare against that.
	// Also, make sure the victim is a player.
	if (AimPunchMultiplier[weapon] != 1.0 && victim > 0 && victim <= MaxClients)
	{
		// It does! So, we'll use this sorta-complex-looking data timer to multiply the victim's aim punch in one frame (0.0 seconds).
		new Handle:data;
		CreateDataTimer(0.0, Timer_DoAimPunch, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, GetClientUserId(victim));
		WritePackCell(data, EntIndexToEntRef(weapon));
		WritePackCell(data, false);
		ResetPack(data);
	}
	
	// Now, maybe the above was applied. Wether it was or not, the weapon might have ALSO had "crit damage multiplier".
	// So we'll use another "if" statement to check (NOT else if) but, of course, we also need to see if it's a crit (if "damagetype" includes DMG_CRIT)
	if (CritDamage[weapon] != 1.0 && damagetype & DMG_CRIT)
	{
		// It does, and this is a crit, so multiply the damage by the variable we just checked.
		damage *= CritDamage[weapon];
		
		// We changed the damage, so we need to return Plugin_Changed below...
		action = Plugin_Changed;
	}
	
	// Return Plugin_Continue if the damage wasn't changed, or Plugin_Changed if it was. Done!
	return action;
}

// We also check AFTER the damage was applied, which you should honestly try to do if your attribute
// is not going to change anything about the damage itself.
// This way, other plugins (and attributes!) can change the damage's information, and you will know.
public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype, weapon, const Float:damageForce[3], const Float:damagePosition[3])
{
	if (attacker <= 0 || attacker > MaxClients) return;
	if (weapon == -1) return;
	if (!HasAttribute[weapon]) return;
	
	if (CritsIgnite[weapon] && victim > 0 && victim <= MaxClients && damagetype & DMG_CRIT && damage > 0.0)
		TF2_IgnitePlayer(victim, attacker);
}

// Here's where we set the aim punch for "aim punch multiplier" and "aim punch to self".
public Action:Timer_DoAimPunch(Handle:timer, Handle:data)
{
	new client = GetClientOfUserId(ReadPackCell(data));
	if (!client) return;
	if (!IsPlayerAlive(client)) return;
	new weapon = EntRefToEntIndex(ReadPackCell(data));
	if (weapon <= MaxClients) return;
	new bool:self = bool:ReadPackCell(data);
	if (!self)
	{
		new Float:angle[3];
		GetEntPropVector(client, Prop_Send, "m_vecPunchAngle", angle);
		for (new i = 0; i <= 2; i++)
			angle[i] *= AimPunchMultiplier[weapon];
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", angle);
	}
	else
	{
		new Float:angle[3];
		angle[0] = AimPunchToSelf[weapon]*-1;
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", angle);
	}
}

// In addition to the above damage hooks, we also have TraceAttack, which is done before either of them,
// and also can detect most hits on teammates! Unfortunately, though, it doesn't have as much information as OnTakeDamage.
// Still, it can be really useful. We'll use it here for "speed boost on hit teammate".
public Action:OnTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if (attacker <= 0 || attacker > MaxClients) return Plugin_Continue;
	new weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon"); // We have to get the weapon manually, sadly; this also means that
	if (weapon == -1) return Plugin_Continue;								// attributes that use this can only be applied to "hitscan" weapons.
	if (!HasAttribute[weapon]) return Plugin_Continue;
	
	if (TeammateSpeedBoost[weapon])
	{
		if (GetClientTeam(attacker) == GetClientTeam(victim))
		{
			// Apply the speed boosts for the amounts of time that the weapon wants.
			TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, TeammateSpeedBoost_User[weapon]);
			TF2_AddCondition(victim, TFCond_SpeedBuffAlly, TeammateSpeedBoost_Teammate[weapon]);
		}
	}
	return Plugin_Continue;
}

// Here's another great thing to track; TF2_CalcIsAttackCritical.
// It's a simple forward (no hooking needed) that fires whenever a client uses a weapon. Very handy!
public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	if (!HasAttribute[weapon]) return Plugin_Continue;
	
	if (LookDownAttackVelocity[weapon])
	{
		new Float:ang[3];
		GetClientEyeAngles(client, ang);
		if (ang[0] >= 50.0)
		{
			new Float:vel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
			if (vel[2] == 0.0) vel[2] = LookDownAttackVelocity_Start[weapon];
			else vel[2] += LookDownAttackVelocity_Push[weapon];
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
		}
	}
	if (AddMetalOnAttack[weapon])
	{
		new metal = GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3);
		metal += AddMetalOnAttack[weapon];
		if (metal < 0) metal = 0;
		if (metal > 200) metal = 200;
		SetEntProp(client, Prop_Data, "m_iAmmo", metal, 4, 3);
	}
	if (AimPunchToSelf[weapon] != 0.0)
	{
		new Handle:data;
		CreateDataTimer(0.0, Timer_DoAimPunch, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, GetClientUserId(client));
		WritePackCell(data, EntIndexToEntRef(weapon));
		WritePackCell(data, true);
		ResetPack(data);
	}
	return Plugin_Continue;
}

// Here's another one, OnPlayerRunCmd. It's called once every frame for every single player.
// You can use it to change around what the client is pressing (like fire/alt-fire) and do other
// precise actions. But it's once every frame (66 times/second), so avoid using expensive things like
// comparing strings or TF2_IsPlayerInCondition!
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:ang[3], &weapon2)
{
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon <= 0 || weapon > 2048) return Plugin_Continue;
	if (!HasAttribute[weapon]) return Plugin_Continue;
	
	new Action:action;
	if (AddMetalOnAttack[weapon] < 0)
	{
		new required = AddMetalOnAttack[weapon] * -1;
		
		if (required > GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3))
		{
			new Float:nextattack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack"),
			Float:nextsec = GetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack"), Float:time = GetGameTime();
			if (nextattack-0.1 <= time) SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", time+0.1);
			if (nextsec-0.1 <= time) SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", time+0.1);
			if (buttons & IN_ATTACK || buttons & IN_ATTACK2)
			{
				buttons &= ~(IN_ATTACK|IN_ATTACK2);
				action = Plugin_Changed;
				if (GetTickedTime() >= NextOutOfAmmoSoundTime[client])
				{
					ClientCommand(client, "playgamesound weapons/shotgun_empty.wav");
					NextOutOfAmmoSoundTime[client] = GetTickedTime() + 0.5;
				}
			}
		}
	}
	return action;
}

// If you need to check things like strings or conditions, a repeating-0.1-second timer like this one
// is a much better choice. Though, really, you should try to keep things out of OnGameFrame/OnPlayerRunCmd
// as often as possible. Even if the below "infinite ammo" was being set 66 times a second instead of 10 times,
// client prediction still makes it look like 10 times per second.
public Action:Timer_TenTimesASecond(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		if (!IsPlayerAlive(client)) continue;
		new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (wep == -1) continue;
		if (!HasAttribute[wep]) continue;
		
		if (InfiniteAmmo[wep])
			SetAmmo_Weapon(wep, InfiniteAmmo[wep]);
	}
}

// Once a weapon entity has been "destroyed", it's been unequipped.
// Unfortunately, that also means that we need to reset all of its variables.
// If you don't, really bad things will happen to the next weapon that occupies that entity slot,
// custom or not!
public OnEntityDestroyed(Ent)
{
	if (Ent <= 0 || Ent > 2048) return;
	HasAttribute[Ent] = false;
	TeammateSpeedBoost[Ent] = true;
	TeammateSpeedBoost_User[Ent] = 0.0;
	TeammateSpeedBoost_Teammate[Ent] = 0.0;
	AimPunchMultiplier[Ent] = 1.0;
	LookDownAttackVelocity[Ent] = false;
	LookDownAttackVelocity_Start[Ent] = 0.0;
	LookDownAttackVelocity_Push[Ent] = 0.0;
	AddMetalOnAttack[Ent] = 0;
	InfiniteAmmo[Ent] = 0;
	AimPunchToSelf[Ent] = 0.0;
	CritsIgnite[Ent] = false;
	CritDamage[Ent] = 1.0;
}

stock SetAmmo_Weapon(weapon, newAmmo)
{
	new owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner == -1) return;
	new iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
	new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
	SetEntData(owner, iAmmoTable+iOffset, newAmmo, 4, true);
}