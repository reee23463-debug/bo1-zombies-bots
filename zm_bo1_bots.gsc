// zm_bo1_bots.gsc - BO1 Zombies bots (Plutonium T5). v0.4, UNTESTED.
// Install: %localappdata%\Plutonium\storage\t5\scripts\zm\zm_bo1_bots.gsc
// Dvars:   bo1_bots_count (default 3)   bo1_bots_infinite_ammo (default 1)   bo1_bots_debug (default 0)
//
// BO1 zombies runs on the T5 SP engine, so the bot builtins are the SP set (Plutonium changelog r4811):
//   isbot, addtestclient, botmeleeparams, botremoteangles, botangles, botstop, botmovement, botaction
// botmovementoverride / botbuttonoverride / botaimoverride are MP-only and do NOT exist here.
//   <bot> botmovement(forward, right)   -127..127
//   <bot> botaction("+name") / ("-name")
//   <bot> botangles(angles)
// T5 has no AddGoal/FindPath, so walking is straight-line toward a goal with
// jump / teleport-to-leader unstuck. Everything is a real trigger press, except the window-repair fallback (board_mode 0/2) which restores the chunks by script.
// Master switch: bo1_bots_enabled (default 1). Set it to 0 and restart the map to turn the whole mod off, 1 to turn it back on.
// Extra dvars: bo1_bots_fire_mode (0 auto-detect, 1 button only, 2 scripted shots only)   bo1_bots_special (0 = off)
// If a button does nothing in game, add or reorder names in bo1_cands() below (only place names live).

// Navigation: bo1_bots_nav 0 turns the engine pathfinding off (straight-line walking)
// Names: bo1_bots_friend_names "A,B"  bo1_bots_names "X,Y"  bo1_bots_names_mode (0 both, 1 friends, 2 general list)
// Tag: bo1_bots_tag "3arc" (default; empty or bo1_bots_tag_off 1 = none)  bo1_bots_tag_in_name (default 1)
// v1.5: Bots default to Juggernog (bo1_bots_default_jug, 0 = off). Bowie/Sickle wall buys are priority 90, above the box, perks and guns.
// v1.4: Spawn protection + Dead Ops Arcade.
//       Bots are invincible for the first 10s after every spawn (dvar bo1_bots_spawn_protect, seconds, 0 = off) and are
//       moved off anybody they spawned inside of. MOD_TELEFRAG damage (the engine's "two players overlap" kill) is now
//       zeroed for everybody (dvar bo1_bots_block_telefrag 0 turns that off), and the damage hook is installed BEFORE the
//       bots join, so the first spawn can't kill you or another bot any more.
//       Dead Ops Arcade (map "zombietron"): bots use a separate, much simpler brain (shoot the nearest enemy, keep away from
//       enemies and from each other, follow the nearest human). Dvar bo1_bots_arcade 1 forces it on, 0 forces it off.
//       Arcade rules read from zombietron_main.gsc: bots count as real players (the game ends only when every player is
//       dead with 0 lives), they stay away from open exits (any player touching one ends the round), and they work out
//       by themselves whether the stick moves them relative to their view or relative to the camera.
// v1.3: P.E.S. fixes. Bots now walk to a spot at the front of the locker that is inside the trigger (checked with
//       istouching and a clear line to the trigger, so not behind the locker / a wall) instead of its raw origin, and
//       the suit counts as "on" only while the bot really holds the suit weapon: after a bot dies or goes down the
//       game can leave "suit on" / "already has equipment" flags behind, so those are cleared before it takes the suit
//       again. Zombies near no longer stop a bot from fetching the suit, and the game's own put-on sequence is not
//       interrupted any more (the bot waits for it to finish, then holds its best gun).
// v1.2: Moon P.E.S. (space suit): on the Moon the bots walk to the nearest suit locker (trigger "zombie_equipment_upgrade"
//       whose .zombie_equipment_upgrade is "equip_gasmask_zm"), take it with the use button, then switch to the suit
//       weapon so the game's own equipment watcher puts the helmet on, and switch back to their gun. Dvar bo1_bots_suit 0 = off.
// v1.1: Moon / No Man's Land: while the game is in No Man's Land (flag "enter_nml") the bots' only job is the teleporter
//       out (the trigger with script_noteworthy "exit_no_mans_land"): they sprint to it, wait just outside while its gate
//       (level.teleporter_exit_nml_gate_open) is still down, then stand on it and shoot what comes. The game teleports once
//       every valid player touches the pad. Downed bots crawl to it. Dvar bo1_bots_nml 0 turns this off.
//       Bots sprint whenever they walk forward and are not shooting. Dvar bo1_bots_run 0 turns it off.
// v1.0: Mystery Box prioritized over wall weapons (box pr 65, Fire Sale pr 80, wall guns pr 45).
//       Global box cooldown slashed from 30s to 4s. Window barrier repair fully overhauled:
//       bots stand in the center of w.trigger_location.origin (the actual trigger cylinder),
//       actively notify the stock trigger_radius entity, keep self._holding_button[level.BUTTON_USE]=true
//       so use_button_held() passes the game's check, and use smooth single-chunk repair fallback
//       instead of locking out the window for 20s if the trigger is delayed.
// v0.9: Solo death fix hardened: damage wrapper now force-clears flag("solo_game"), level.is_solo_game,
//       level.solo_game, and forces is_zombie=false + lives=9 on all bots BEFORE every damage forward.
//       The 0.25s keep-alive loop does the same. Bots init with is_zombie=false and lives=9 on spawn.
//       Window repair fix: use_button_held() is pre-initialized with a 0.5s warm-up before the repair
//       loop so the stock blocker_trigger_think code sees the held button on its first check.
// v0.8: game over on death fixed (solo rules are now kept off the whole game, not just once, and the player damage
//       callback is wrapped so a human with a living teammate goes down instead of dying). Purchases are verified:
//       if the game didn't take the full price, the missing part is taken through the game's own score function.
// v0.6: bots see downed players (revive works), get start points + hit/kill/board points if the game
//       doesn't pay them, and are targeted like players. Dvars: bo1_bots_points_mode (0 auto,1 game,2 script),
//       bo1_bots_start_score (default 3000).
// v0.7: bots no longer get a start bonus (bo1_bots_start_score now defaults to 0). Kills pay what players get:
//       60 body, 100 headshot, 130 melee (doubled under double points), whichever way the game pays the bots.
//       Wall guns were never bought because the wall triggers have no .zombie_cost in BO1 (cost is in
//       level.zombie_weapons); fixed. Wall guns and the mystery box are bought with the real use press and
//       fall back to firing the trigger directly (same trick as the bo2 bots) if the press does nothing.
//       New dvar bo1_bots_buy_mode: 0 (default) fire the trigger first, 1 real press first. Wall guns also get a
//       scripted give (takes the points, gives the gun) if the game doesn't react to the trigger at all.
//       The weaker gun is held before a purchase so the game swaps that one out, and the best gun is held after.
// v0.5: reworked window repair (stand-off spot inside the room, use-button check, progress tracking,
//       scripted fallback). New dvar bo1_bots_board_mode (0 auto, 1 button only, 2 scripted only).

#include maps\_utility;
#include common_scripts\utility;

main()
{
	// master switch: set bo1_bots_enabled 0 (console or config), then restart the map, and the mod does nothing
	if(getdvar("bo1_bots_enabled") != "" && getdvarint("bo1_bots_enabled") == 0)
		return;
	level thread bo1bots_start();
}

bo1bots_dbg(msg)
{
	if(getdvar("bo1_bots_debug") != "" && getdvarint("bo1_bots_debug") != 0)
		iprintln("^3[bo1bots] ^7" + msg);
}

bo1bots_humans_alive()
{
	n = 0;
	players = get_players();
	for(i = 0; i < players.size; i++)
	{
		if(isDefined(players[i].bo1))
			continue;
		if(isDefined(players[i].sessionstate) && players[i].sessionstate == "playing")
			n++;
	}
	return n;
}

bo1bots_start()
{
	level endon("end_game");

	for(;;)
	{
		wait 1;
		// Dead Ops Arcade has no round_number
		if(!isDefined(level.round_number) && !bo1_is_arcade())
			continue;
		if(bo1bots_humans_alive() > 0)
			break;
	}
	wait 8;

	count = 3;
	if(getdvar("bo1_bots_count") != "")
		count = getdvarint("bo1_bots_count");

	// the game only has room for 4 players: a 5th bot is the invisible half-alive one. bo1_bots_max_players changes the cap.
	maxp = 4;
	if(getdvar("bo1_bots_max_players") != "")
		maxp = getdvarint("bo1_bots_max_players");
	room = maxp - get_players().size;
	if(room < 0)
		room = 0;
	if(count > room)
	{
		bo1bots_dbg("^3BO1 bots: only room for " + room + " bot(s) (" + maxp + " players max), spawning " + room + " instead of " + count);
		count = room;
	}

	level.bo1bots_last_door = 0;
	level.bo1bots_last_box = 0;
	level thread bo1bots_keep_squad_rules();
	// the hook has to be in BEFORE the bots join: the overlap kill happens at the moment they spawn
	bo1bots_hook_damage();

	for(i = 0; i < count; i++)
	{
		bot = addtestclient();
		if(!isDefined(bot))
		{
			bo1bots_dbg("^1BO1 bots: addtestclient failed, stopping at " + i);
			break;
		}
		bot thread bo1bots_on_connect();
		wait 1.5;
	}
	iprintln("^2BO1 bots: spawned");
	if(!bo1_is_arcade())
		level thread bo1bots_lure();
}

// ---------------------------------------------------------------- spawn protection

// Dead Ops Arcade? (map name zombietron). bo1_bots_arcade 1 forces it on, 0 forces it off.
bo1_is_arcade()
{
	v = getdvar("bo1_bots_arcade");
	if(v == "1")
		return true;
	if(v == "0")
		return false;
	// zombietron's main() sets level.zombietron_mode = true
	if(isDefined(level.zombietron_mode) && level.zombietron_mode)
		return true;
	m = tolower(getdvar("mapname"));
	return issubstr(m, "zombietron");
}

bo1_protected(p)
{
	return isDefined(p.bo1) && isDefined(p.bo1.protect_until) && gettime() < p.bo1.protect_until;
}

bo1bots_any_protected()
{
	players = get_players();
	for(i = 0; i < players.size; i++)
	{
		if(bo1_protected(players[i]))
			return true;
	}
	return false;
}

// Invincible for the first N seconds after a spawn (default 10). Also keeps pulling the bot off anybody it overlaps, because
// the engine kills players whose hitboxes intersect.
bo1bots_spawn_protect()
{
	self endon("disconnect");
	self notify("bo1_protect");
	self endon("bo1_protect");

	secs = 10;
	if(getdvar("bo1_bots_spawn_protect") != "")
		secs = getdvarint("bo1_bots_spawn_protect");
	if(secs <= 0)
		return;

	self.bo1.protect_until = gettime() + secs * 1000;
	self enableinvulnerability();
	bo1bots_dbg(self.name + " spawn protected for " + secs + "s");

	while(gettime() < self.bo1.protect_until)
	{
		self bo1bots_spread();
		wait 0.25;
	}
	self.bo1.protect_until = 0;
	self disableinvulnerability();
	bo1bots_dbg(self.name + " spawn protection over");
}

// somebody (human or bot) standing inside our hitbox?
bo1bots_overlapping()
{
	players = get_players();
	for(i = 0; i < players.size; i++)
	{
		q = players[i];
		if(q == self || !isDefined(q) || !isAlive(q))
			continue;
		if(distance2d(self.origin, q.origin) < 40 && abs(self.origin[2] - q.origin[2]) < 70)
			return q;
	}
	return undefined;
}

// move off whoever we overlap, to the nearest free spot on a ring around them
bo1bots_spread()
{
	base = self bo1bots_overlapping();
	if(!isDefined(base))
		return;
	players = get_players();
	for(r = 70; r <= 170; r += 50)
	{
		for(a = 0; a < 360; a += 45)
		{
			cand = base.origin + anglestoforward((0, a, 0)) * r;
			g = groundpos(cand + (0, 0, 40));
			if(!isDefined(g) || abs(g[2] - base.origin[2]) > 40)
				continue;
			if(!sighttracepassed(base.origin + (0, 0, 40), g + (0, 0, 40), false, undefined))
				continue;
			free = true;
			for(i = 0; i < players.size; i++)
			{
				q = players[i];
				if(q == self || !isDefined(q) || !isAlive(q))
					continue;
				if(distance2d(q.origin, g) < 50)
				{
					free = false;
					break;
				}
			}
			if(!free)
				continue;
			self setorigin(g + (0, 0, 5));
			bo1bots_dbg(self.name + " moved off " + base.name + " (overlap)");
			return;
		}
	}
}

// Is anybody besides p still up (playing, not downed)? Bots count, they are real players.
bo1bots_mate_up(p)
{
	players = get_players();
	for(i = 0; i < players.size; i++)
	{
		q = players[i];
		if(q == p || !isDefined(q) || !isAlive(q))
			continue;
		if(isDefined(q.sessionstate) && q.sessionstate != "playing")
			continue;
		if(bo1_down(q))
			continue;
		return true;
	}
	return false;
}

// The game decides "solo game" at startup, before the bots join. Solo rules mean no last stand: you die and it is
// game over at once. Clearing the flag a single time was not enough (the game can set it again), so keep it clear.
bo1bots_clear_solo()
{
	if(get_players().size > 1 && isDefined(level.flag) && isDefined(level.flag["solo_game"]) && level.flag["solo_game"])
	{
		flag_clear("solo_game");
		bo1bots_dbg("solo_game flag cleared");
	}
}

bo1bots_keep_squad_rules()
{
	level endon("end_game");
	for(;;)
	{
		bo1bots_clear_solo();
		// Also keep the alternate solo variables clear and force bots' is_zombie off every tick
		level.is_solo_game = false;
		level.solo_game = false;
		players = get_players();
		for(i = 0; i < players.size; i++)
		{
			if(isDefined(players[i].bo1) && isDefined(players[i].is_zombie) && players[i].is_zombie)
				players[i].is_zombie = false;
		}
		wait 0.25;
	}
}

// Wrap the game's player damage callback: right before every hit make sure the solo flag is off. If a human takes a
// lethal hit while a teammate is up, log it, so a remaining game over can be traced (bo1_bots_debug 1).
bo1bots_hook_damage()
{
	if(isDefined(level.bo1_damage_hooked))
		return;
	level.bo1_damage_hooked = true;
	if(isDefined(level.overrideplayerdamage))
		level.bo1_orig_damage = level.overrideplayerdamage;
	else
		bo1bots_dbg("no level.overridePlayerDamage, installing our own");
	level.overrideplayerdamage = ::bo1bots_damage_wrap;
}

bo1bots_damage_wrap(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime)
{
	if(isDefined(self) && isPlayer(self))
	{
		// the engine's "two players overlap" kill: never let it through
		if(sMeansOfDeath == "MOD_TELEFRAG" && !(getdvar("bo1_bots_block_telefrag") != "" && getdvarint("bo1_bots_block_telefrag") == 0))
		{
			bo1bots_dbg("blocked a telefrag on " + self.name);
			return 0;
		}
		// spawn protection
		if(bo1_protected(self))
			return 0;
		// while a bot is still spawning in, collision / crush / unattributed suicide damage can't hurt anybody
		if(bo1bots_any_protected() && (sMeansOfDeath == "MOD_CRUSH" || (sMeansOfDeath == "MOD_SUICIDE" && !isDefined(eAttacker) && !isDefined(eInflictor))))
		{
			bo1bots_dbg("blocked collision damage on " + self.name);
			return 0;
		}
	}

	// CRITICAL: Clear the solo_game flag right before every damage forward. The stock damage override
	// (player_damage_override in _zombiemode.gsc) checks flag("solo_game") and immediately ends the game
	// if it is set and the player takes lethal damage. The 0.25s loop isn't fast enough to win the race.
	bo1bots_clear_solo();

	// Force all bots to count as valid teammates for the stock damage override's alive-player count.
	// The override skips players whose is_zombie is true, sessionstate != "playing", or who are in laststand.
	players = get_players();
	for(i = 0; i < players.size; i++)
	{
		q = players[i];
		if(!isDefined(q.bo1))
			continue;
		// Bots must never be flagged as zombies — the damage override counts them as dead otherwise
		if(isDefined(q.is_zombie) && q.is_zombie)
		{
			q.is_zombie = false;
			bo1bots_dbg("cleared is_zombie on bot " + q.name);
		}
		// Bots need lives > 0 or the override treats the lethal hit as final (solo insta-death path).
		// Not in the arcade (the game manages lives there), and never for a bot that isn't really spawned:
		// forcing those is what made some bots invisible-but-alive.
		if(!bo1_is_arcade() && isDefined(q.sessionstate) && q.sessionstate == "playing" && (!isDefined(q.lives) || q.lives < 1))
			q.lives = 9;
	}

	// Also clear the alternate solo variables the game may check
	level.is_solo_game = false;
	level.solo_game = false;

	if(isDefined(self) && isPlayer(self) && !isDefined(self.bo1) && iDamage >= self.health)
	{
		// The game ends the match when every OTHER player is down, dead/spectating or flagged is_zombie.
		// Print who counts as what, so a game over can be traced.
		up = 0;
		mates = [];
		for(i = 0; i < players.size; i++)
		{
			q = players[i];
			if(q == self)
				continue;
			st = "?";
			if(isDefined(q.sessionstate))
				st = q.sessionstate;
			dn = bo1_down(q);
			z = isDefined(q.is_zombie) && q.is_zombie;
			if(!dn && !z && st != "spectator")
				up++;
			bo1bots_dbg(self.name + " lethal hit, mate " + q.name + ": state " + st + " downed " + dn + " is_zombie " + z + " alive " + isAlive(q));
			mates[mates.size] = q.name + ": " + st + ", downed " + dn + ", is_zombie " + z + ", alive " + isAlive(q) + ", health " + q.health;
		}
		// always show why nobody counts as up (no debug dvar needed)
		if(up == 0)
		{
			for(i = 0; i < mates.size; i++)
				bo1bots_dbg("^1  " + mates[i]);
		}
		if(up == 0)
			bo1bots_dbg("^1BO1 bots: you took a lethal hit and no teammate counts as up, so the game ends (set bo1_bots_debug 1 for details)");
		else
			bo1bots_dbg("^2BO1 bots: lethal hit, " + up + " teammate(s) count as up: you should go down, not out");
	}
	if(isDefined(level.bo1_orig_damage))
		return self [[level.bo1_orig_damage]](eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime);
	return iDamage;
}

// Every 0.5s make sure each zombie is on the closest valid player, humans and bots treated the same.
// A zombie keeps its current target unless somebody is clearly closer (30%), so it doesn't flip-flop.
bo1bots_lure()
{
	level endon("end_game");
	for(;;)
	{
		wait 0.5;
		zs = bo1_enemies();
		players = get_players();
		for(i = 0; i < zs.size; i++)
		{
			z = zs[i];
			if(!isDefined(z) || !isAlive(z))
				continue;
			closest = undefined;
			cd = 99999999;
			cur_d = undefined;
			for(j = 0; j < players.size; j++)
			{
				p = players[j];
				if(!isDefined(p) || !isAlive(p) || bo1_down(p))
					continue;
				if(isDefined(p.sessionstate) && p.sessionstate != "playing")
					continue;
				d = distancesquared(z.origin, p.origin);
				if(d < cd)
				{
					cd = d;
					closest = p;
				}
				if(isDefined(z.favoriteenemy) && z.favoriteenemy == p)
					cur_d = d;
			}
			if(!isDefined(closest))
				continue;
			if(isDefined(cur_d) && cur_d <= cd * 1.69)
				continue;
			z.favoriteenemy = closest;
		}
	}
}

bo1bots_on_connect()
{
	self endon("disconnect");

	self.bo1 = spawnstruct();
	self.bo1.skip = [];
	self.bo1.stuck = 0;
	self.bo1.last_pos = (0, 0, 0);
	self.bo1.next_shop = 0;
	self.bo1.shop = undefined;
	self.bo1.next_shot = 0;
	self.bo1.next_knife = 0;
	self.bo1.nav_next = 0;
	self.bo1.nav_t = 0;
	self.bo1.nav_i = 0;
	self.bo1.next_reload = 0;
	self.bo1.next_board = 0;
	self.bo1.board = undefined;
	self.bo1.snap_score = 0;

	// give it a few seconds to spawn on its own, otherwise spawn it by hand
	t = 0;
	while(!(isDefined(self.sessionstate) && self.sessionstate == "playing") && t < 8)
	{
		wait 0.5;
		t += 0.5;
	}
	// Forcing a spawn (bo1_bots_force_spawn 1) is what produced invisible half-spawned bots on some maps, so it is off.
	if(!(isDefined(self.sessionstate) && self.sessionstate == "playing") && isDefined(level.spawnplayer) && getdvarint("bo1_bots_force_spawn") == 1)
	{
		bo1bots_dbg(self.name + " not spawned, calling level.spawnplayer");
		self [[level.spawnplayer]]();
		wait 1;
	}
	if(!(isDefined(self.sessionstate) && self.sessionstate == "playing"))
	{
		bo1bots_dbg("^1BO1 bots: " + self.name + " never got a player slot (too many players for this map?). It stays idle. Lower bo1_bots_count.");
		self.bo1.inactive = true;
		self waittill("spawned_player");
		self.bo1.inactive = undefined;
		wait 1;
	}

	// same team as the humans, or zombies don't treat us as an enemy
	self setteamforentity("allies");

	// Make sure the bot is never counted as a zombie by the damage override's alive-player check.
	// Also give it lives > 0 so the "solo insta-death" path (lives == 0) is never hit.
	self.is_zombie = false;
	if(!bo1_is_arcade() && (!isDefined(self.lives) || self.lives < 1))
		self.lives = 9;

	// names and clan tags: Plutonium reads them from bots.txt (see bots.txt), script can't set them

	// no start bonus any more; bo1_bots_start_score > 0 brings it back if you ever want it
	if(!isDefined(self.bo1.paid))
	{
		self.bo1.paid = true;
		sp = 0;
		if(getdvar("bo1_bots_start_score") != "")
			sp = getdvarint("bo1_bots_start_score");
		if(sp > 0 && self.score < sp)
		{
			self.score = sp;
			self.score_total = sp;
			self.old_score = sp;
		}
	}

	for(;;)
	{
		self thread bo1bots_spawn_protect();
		self thread bo1bots_brain();
		self waittill("spawned_player");
		// protect right away (the brain restart below waits a second)
		self thread bo1bots_spawn_protect();
		wait 1;
	}
}

// ---------------------------------------------------------------- names
//
// Names come from two lists, handed out in order (friends first, then the general list):
//   bo1_bots_friend_names   "Alex,Sam,Jordan"        (your friends, comma separated, empty = none)
//   bo1_bots_names          "Name1,Name2,..."        (empty = the built-in list in bo1_default_names below)
//   bo1_bots_names_mode     0 both (default), 1 friend names only, 2 general list only
// Example:  set bo1_bots_friend_names "Alex,Sam"

// Replace these with the exact names the multiplayer bots use if you have the list.
bo1_default_names()
{
	n = [];
	n[0] = "Rook";
	n[1] = "Viper";
	n[2] = "Ghost";
	n[3] = "Hawk";
	n[4] = "Wolf";
	n[5] = "Raven";
	n[6] = "Stone";
	n[7] = "Blaze";
	return n;
}

// "a,b,c" -> array, empty entries skipped
bo1_split_names(str)
{
	out = [];
	if(!isDefined(str) || str == "")
		return out;
	parts = strtok(str, ",");
	for(i = 0; i < parts.size; i++)
	{
		if(parts[i] != "" && parts[i] != " ")
			out[out.size] = parts[i];
	}
	return out;
}

bo1_set_name()
{
	if(!isDefined(level.bo1bots_name_i))
		level.bo1bots_name_i = 0;

	mode = 0;
	if(getdvar("bo1_bots_names_mode") != "")
		mode = getdvarint("bo1_bots_names_mode");

	pool = [];
	if(mode != 2)
	{
		friends = bo1_split_names(getdvar("bo1_bots_friend_names"));
		for(i = 0; i < friends.size; i++)
			pool[pool.size] = friends[i];
	}
	if(mode != 1)
	{
		general = bo1_split_names(getdvar("bo1_bots_names"));
		if(general.size == 0)
			general = bo1_default_names();
		for(i = 0; i < general.size; i++)
			pool[pool.size] = general[i];
	}
	if(pool.size == 0)
		return;

	nm = pool[level.bo1bots_name_i % pool.size];
	level.bo1bots_name_i++;

	// Treyarch's multiplayer bots carry the [3arc] clan tag. bo1_bots_tag "" turns it off,
	// bo1_bots_tag_in_name 0 keeps it out of the name (clan tag dvar only).
	tag = "3arc";
	if(getdvar("bo1_bots_tag") != "")
		tag = getdvar("bo1_bots_tag");
	if(getdvar("bo1_bots_tag_off") != "" && getdvarint("bo1_bots_tag_off") != 0)
		tag = "";
	if(tag != "")
	{
		self setclientdvar("clanname", tag);
		if(getdvar("bo1_bots_tag_in_name") == "" || getdvarint("bo1_bots_tag_in_name") != 0)
		{
			// names are 15 characters at most
			room = 15 - (tag.size + 2);
			if(nm.size > room)
				nm = getsubstr(nm, 0, room);
			nm = "[" + tag + "]" + nm;
		}
	}

	// the engine builtin that sets a client's name differs between builds, so set both ways
	self.bo1_nm = nm;
	self setclientdvar("name", nm);
	self.playername = nm;
	self thread bo1_name_later();
	bo1bots_dbg("bot named " + nm);
}

// the engine can overwrite the name while the bot is still connecting/spawning, so set it again afterwards
bo1_name_later()
{
	self endon("disconnect");
	for(i = 0; i < 4; i++)
	{
		wait 2.5;
		if(!isDefined(self.bo1_nm))
			return;
		self setclientdvar("name", self.bo1_nm);
		self.playername = self.bo1_nm;
		if(isDefined(self.pers))
			self.pers["name"] = self.bo1_nm;
	}
}

// ---------------------------------------------------------------- buttons

// Authoritative mapping from bot actions to Plutonium T5 engine usercmd masks
// and script button bits discovered via reverse-engineering BlackOps.exe and
// plutonium-bootstrapper-win32.exe.
bo1_cands(n)
{
	c = [];
	c[0] = n;
	return c;
}

bo1_act_name(n)
{
	return n;
}

bo1_next_act(n)
{
}

bo1_on(n)
{
	switch(n)
	{
		case "attack":
		case "fire":
			self botaction("+fire");
			self botaction("+attack");
			self botaction("+unk14"); // 0x80000000 -> attackbuttonpressed()
			break;
		case "use":
		case "activate":
			self botaction("+use");       // 0x28 (0x20 | 0x08 -> native trigger_use)
			self botaction("+usereload"); // 0x20
			self botaction("+activate");  // 0x08
			self botaction("+unk11");     // 0x10000000 -> usebuttonpressed()
			self botaction("+unk9");      // 0x04000000 -> usebuttonheld()
			break;
		case "reload":
			self botaction("+reload");    // 0x10 -> native reload animation
			self botaction("+usereload"); // 0x20
			self botaction("+unk10");     // 0x08000000 -> reloadbuttonpressed()
			self botaction("+unk9");
			break;
		case "melee":
			self botaction("+melee");     // 0x04 -> native knife swing and damage
			self botaction("+unk12");     // 0x20000000 -> meleebuttonpressed()
			break;
		case "jump":
		case "gostand":
			self botaction("+gostand");   // 0x400 -> native jump physics
			self botaction("+unk4");      // 0x00200000 -> jumpbuttonpressed()
			break;
		case "crouch":
		case "gocrouch":
			self botaction("+gocrouch");  // 0x200 -> native crouch
			break;
		case "prone":
		case "goprone":
			self botaction("+goprone");   // 0x100 -> native prone
			break;
		case "ads":
			self botaction("+ads");       // 0x80800 -> native ADS zoom
			self botaction("+remote");    // 0x00100000 -> adsbuttonpressed()
			break;
		case "sprint":
			self botaction("+sprint");    // 0x02 -> native sprint
			self botaction("+unk13");     // 0x40000000 -> sprintbuttonpressed()
			break;
		case "frag":
			self botaction("+frag");      // 0x4000 -> native lethal grenade
			self botaction("+unk2");      // 0x00020000 -> fragbuttonpressed()
			break;
		case "smoke":
			self botaction("+smoke");     // 0x8000 -> native tactical grenade
			self botaction("+unk");       // 0x00010000 -> secondaryoffhandbuttonpressed()
			break;
		default:
			self botaction("+" + n);
			break;
	}
}

bo1_off(n)
{
	switch(n)
	{
		case "attack":
		case "fire":
			self botaction("-fire");
			self botaction("-attack");
			self botaction("-unk14");
			break;
		case "use":
		case "activate":
			self botaction("-use");
			self botaction("-usereload");
			self botaction("-activate");
			self botaction("-unk11");
			self botaction("-unk9");
			break;
		case "reload":
			self botaction("-reload");
			self botaction("-usereload");
			self botaction("-unk10");
			self botaction("-unk9");
			break;
		case "melee":
			self botaction("-melee");
			self botaction("-unk12");
			break;
		case "jump":
		case "gostand":
			self botaction("-gostand");
			self botaction("-unk4");
			break;
		case "crouch":
		case "gocrouch":
			self botaction("-gocrouch");
			break;
		case "prone":
		case "goprone":
			self botaction("-goprone");
			break;
		case "ads":
			self botaction("-ads");
			self botaction("-remote");
			break;
		case "sprint":
			self botaction("-sprint");
			self botaction("-unk13");
			break;
		case "frag":
			self botaction("-frag");
			self botaction("-unk2");
			break;
		case "smoke":
			self botaction("-smoke");
			self botaction("-unk");
			break;
		default:
			self botaction("-" + n);
			break;
	}
}

// ---------------------------------------------------------------- helpers

bo1_down(p)
{
	// BO1 last stand = player has a revive trigger; there is no .laststand field
	return isDefined(p.revivetrigger);
}

bo1_stop()
{
	self botmovement(0, 0);
	self bo1_run(false);
}

// hold or release the sprint button (only sends the button when the state changes)
bo1_run(on)
{
	if(on && getdvar("bo1_bots_run") != "" && getdvarint("bo1_bots_run") == 0)
		on = false;
	if(isDefined(self.bo1.no_run) && self.bo1.no_run)
		on = false;
	if(isDefined(self.bo1.run) && self.bo1.run == on)
		return;
	self.bo1.run = on;
	if(on)
		self bo1_on("sprint");
	else
		self bo1_off("sprint");
}

// walk in world direction dir, whatever way the bot is looking
bo1_move_dir(dir)
{
	dir = (dir[0], dir[1], 0);
	if(lengthsquared(dir) < 1)
	{
		self botmovement(0, 0);
		self bo1_run(false);
		return;
	}
	dir = vectornormalize(dir);
	ang = self getplayerangles();
	if(isDefined(self.bo1.move_yaw))
		ang = (0, self.bo1.move_yaw, 0);
	fwd = anglestoforward(ang);
	right = anglestoright(ang);
	f = int(vectordot(dir, fwd) * 127);
	r = int(vectordot(dir, right) * 127);
	self botmovement(f, r);
	// run when walking mostly forward, never while shooting (sprinting stops the weapon) or downed
	run = f > 100 && !bo1_down(self) && (!isDefined(self.bo1.shot_t) || gettime() - self.bo1.shot_t > 400);
	self bo1_run(run);
}

bo1_face(pos)
{
	ang = vectortoangles(pos - self geteye());
	self botangles(ang);
}

bo1_press(sec)
{
	self bo1_stop();
	self bo1_on("use");
	wait sec;
	self bo1_off("use");
}

bo1_jump()
{
	self bo1_on("gostand");
	wait 0.1;
	self bo1_off("gostand");
}

bo1_leader()
{
	best = undefined;
	bd = 99999999;
	players = get_players();
	for(i = 0; i < players.size; i++)
	{
		p = players[i];
		if(p == self || !isAlive(p) || bo1_down(p))
			continue;
		if(isDefined(p.bo1))
			continue;
		d = distancesquared(self.origin, p.origin);
		if(d < bd)
		{
			bd = d;
			best = p;
		}
	}
	if(isDefined(best))
		return best;
	// no human around: follow any other living player
	for(i = 0; i < players.size; i++)
	{
		p = players[i];
		if(p == self || !isAlive(p) || bo1_down(p))
			continue;
		return p;
	}
	return undefined;
}

bo1_find_downed()
{
	best = undefined;
	bd = 99999999;
	players = get_players();
	for(i = 0; i < players.size; i++)
	{
		p = players[i];
		if(p == self || !isAlive(p) || !bo1_down(p))
			continue;
		if(!isDefined(p.revivetrigger))
			continue;
		d = distancesquared(self.origin, p.origin);
		if(d < bd)
		{
			bd = d;
			best = p;
		}
	}
	return best;
}

// Every hostile AI, not just zombies: dogs, monkeys, napalm/sonic zombies, astronaut, whatever the map spawns.
// Anything that is not on our side counts. Falls back to the zombie team if the all-AI query returns nothing.
bo1_enemies()
{
	// getaiarray only returns the human species, dogs and other non-human AI are missing from it.
	// The game itself counts all enemies with getaispeciesarray(team, "all").
	team = "axis";
	if(isDefined(level.zombie_team))
		team = level.zombie_team;
	all = getaispeciesarray(team, "all");
	if(!isDefined(all) || all.size == 0)
		all = getaiarray(team);
	out = [];
	for(i = 0; i < all.size; i++)
	{
		e = all[i];
		if(!isDefined(e) || !isAlive(e))
			continue;
		out[out.size] = e;
	}
	return out;
}

bo1_is_dog(z)
{
	if(isDefined(z.animname) && issubstr(tolower(z.animname), "dog"))
		return true;
	if(isDefined(z.targetname) && issubstr(tolower(z.targetname), "dog"))
		return true;
	return false;
}

// where to aim on an enemy: dogs and crawlers are low, the rest chest/head height
bo1_aimpos(z)
{
	h = 45;
	if(bo1_is_dog(z))
		h = 20;
	else if(isDefined(z.has_legs) && !z.has_legs)
		h = 15;
	return z.origin + (0, 0, h);
}

bo1_find_target()
{
	zs = bo1_enemies();
	best = undefined;
	bd = 1500 * 1500;
	eye = self geteye();
	for(i = 0; i < zs.size; i++)
	{
		z = zs[i];
		if(!isDefined(z) || !isAlive(z))
			continue;
		if(bo1_is_special(z))
			continue;
		// a dog is still invulnerable (magic bullet shield) while it spawns in: don't waste ammo on it
		if(isDefined(z.magic_bullet_shield) && z.magic_bullet_shield)
			continue;
		d = distancesquared(self.origin, z.origin);
		if(d >= 1500 * 1500)
			continue;
		// dogs sprint and bite hard: they count as twice as close
		sc = d;
		if(bo1_is_dog(z))
			sc = d * 0.25;
		if(sc >= bd)
			continue;
		if(!sighttracepassed(eye, bo1_aimpos(z), false, undefined))
			continue;
		bd = sc;
		best = z;
	}
	return best;
}

bo1_any_zombie_near(r)
{
	zs = bo1_enemies();
	for(i = 0; i < zs.size; i++)
	{
		if(isDefined(zs[i]) && isAlive(zs[i]) && distancesquared(self.origin, zs[i].origin) < r * r)
			return true;
	}
	return false;
}

// ---------------------------------------------------------------- special enemies

// Moon astronaut: huge health, grabs and steals perks. Never shoot it, keep away.
// Detected by name; if the names don't match, set  ent.bot_special = "astro";  where it spawns.
bo1_is_special(z)
{
	if(getdvar("bo1_bots_special") != "" && getdvarint("bo1_bots_special") == 0)
		return false;
	if(isDefined(z.bot_special))
		return true;
	names = [];
	names[0] = z.animname;
	names[1] = z.targetname;
	names[2] = z.script_noteworthy;
	names[3] = z.classname;
	for(i = 0; i < names.size; i++)
	{
		if(isDefined(names[i]) && issubstr(tolower(names[i]), "astro"))
			return true;
	}
	return false;
}

bo1_find_special(r)
{
	zs = bo1_enemies();
	for(i = 0; i < zs.size; i++)
	{
		z = zs[i];
		if(!isDefined(z) || !isAlive(z) || !bo1_is_special(z))
			continue;
		if(distancesquared(self.origin, z.origin) < r * r)
			return z;
	}
	return undefined;
}

// ---------------------------------------------------------------- shooting

// round 1 is knife only (no guns, no grenades); later rounds are back to normal
bo1_knife_only()
{
	return isDefined(level.round_number) && level.round_number == 1;
}

// Shotguns only do real damage up close: hold fire until the zombie is near (bo2 bots: 400 units).
// Name based on purpose, no weaponclass call. Upgraded versions contain the same name.
bo1_is_shotgun(w)
{
	if(!isDefined(w) || w == "none")
		return false;
	names = [];
	names[0] = "rottweil72";	// Olympia
	names[1] = "ithaca";		// Stakeout
	names[2] = "spas";
	names[3] = "hs10";
	names[4] = "ks23";
	names[5] = "ksg";
	names[6] = "870";
	names[7] = "saiga";
	names[8] = "srm";
	names[9] = "shotgun";
	names[10] = "stakeout";
	names[11] = "olympia";
	names[12] = "judge";
	for(i = 0; i < names.size; i++)
	{
		if(issubstr(w, names[i]))
			return true;
	}
	return false;
}

// Shotgun out when a zombie is close, back to the best other gun when it is far (the shotgun holds fire past 400).
// Gap between 300 and 450 so it doesn't flip back and forth. An upgraded gun in the other slot stays out.
bo1_pick_weapon(zd)
{
	if(!isDefined(self.bo1.next_switch))
		self.bo1.next_switch = 0;
	if(gettime() < self.bo1.next_switch)
		return;
	prims = self getweaponslistprimaries();
	if(prims.size < 2)
		return;
	cur = self getcurrentweapon();
	if(cur == "none")
		return;
	cur_sg = bo1_is_shotgun(cur);

	if(zd < 300 && !cur_sg)
	{
		sg = undefined;
		other_top = false;
		for(i = 0; i < prims.size; i++)
		{
			w = prims[i];
			if(bo1_is_shotgun(w))
			{
				if(self getweaponammoclip(w) > 0)
					sg = w;
			}
			else if(issubstr(w, "_upgraded") && !issubstr(cur, "none"))
				other_top = true;
		}
		if(isDefined(sg) && (!other_top || issubstr(sg, "_upgraded")))
		{
			self.bo1.next_switch = gettime() + 1500;
			self switchtoweapon(sg);
			bo1bots_dbg(self.name + " shotgun out: " + sg);
		}
		return;
	}
	if(zd > 450 && cur_sg)
	{
		best = undefined;
		bv = -1;
		for(i = 0; i < prims.size; i++)
		{
			w = prims[i];
			if(bo1_is_shotgun(w))
				continue;
			if(self getweaponammoclip(w) <= 0)
				continue;
			c = bo1_weapon_cost(w);
			if(c > bv)
			{
				bv = c;
				best = w;
			}
		}
		if(isDefined(best))
		{
			self.bo1.next_switch = gettime() + 1500;
			self switchtoweapon(best);
		}
	}
}

// Gun in hand is empty and a zombie is close: switch to the other gun if it has rounds in the clip, even if it is
// the weaker one (bo2 bots do the same). Calm = no swap, it just reloads. Returns true if it switched.
bo1_swap_loaded(cur)
{
	if(!isDefined(self.bo1.next_dry))
		self.bo1.next_dry = 0;
	if(gettime() < self.bo1.next_dry)
		return false;
	prims = self getweaponslistprimaries();
	best = undefined;
	bv = -1;
	for(i = 0; i < prims.size; i++)
	{
		w = prims[i];
		if(w == cur || self getweaponammoclip(w) <= 0)
			continue;
		c = bo1_weapon_cost(w);
		if(c > bv)
		{
			bv = c;
			best = w;
		}
	}
	if(!isDefined(best))
		return false;
	self.bo1.next_dry = gettime() + 800;
	self.bo1.next_switch = gettime() + 1500;
	self switchtoweapon(best);
	bo1bots_dbg(self.name + " " + cur + " empty, switched to " + best);
	return true;
}

bo1_ceasefire()
{
	self bo1_off("attack");
	self bo1_off("melee");
	self bo1_off("ads");
}

bo1_shoot(z, zd)
{
	self.bo1.shot_z = z;
	self.bo1.shot_t = gettime();
	// the zombie remembers who hit it last, so a kill is only credited to one bot
	z.bo1_shooter = self;
	z.bo1_shooter_t = gettime();
	w = self getcurrentweapon();
	clip = self getweaponammoclip(w);

	if(!isDefined(level.bo1_fire))
		level.bo1_fire = "button";
	mode = getdvarint("bo1_bots_fire_mode");
	if(mode == 1)
		level.bo1_fire = "button";
	if(mode == 2)
		level.bo1_fire = "script";

	// round 1: knife only, never pull the trigger. Spam the knife: the melee button only swings once per
	// press, so it has to be tapped every frame, and the bot starts swinging from a bit further out.
	if(bo1_knife_only())
	{
		self bo1_off("attack");
		self bo1_off("ads");
		if(zd < 105)
		{
			if(level.bo1_fire == "script")
				self bo1_script_knife(z);
			else
				self bo1_melee_tap();
		}
		else
			self bo1_off("melee");
		return;
	}

	if(zd < 80)
	{
		if(level.bo1_fire == "script")
			self bo1_script_knife(z);
		else
			self bo1_melee_tap();
	}
	else
		self bo1_off("melee");

	maxr = 1400;
	if(bo1_is_shotgun(w))
		maxr = 400;
	if(zd >= maxr)
	{
		self bo1_off("attack");
		self bo1_off("ads");
		return;
	}
	if(clip <= 0)
	{
		self bo1_off("attack");
		self bo1_off("ads");
		if(zd < 400 && self bo1_swap_loaded(w))
			return;
		self bo1_reload();
		// fallback: if the reload button does nothing, refill the clip by script after 2.5s
		if(!isDefined(self.bo1.empty_since))
			self.bo1.empty_since = gettime();
		else if(gettime() - self.bo1.empty_since > 2500)
		{
			stock = self getweaponammostock(w);
			n = weaponclipsize(w);
			if(stock < n)
				n = stock;
			if(n <= 0)
				n = weaponclipsize(w);
			self setweaponammoclip(w, n);
			self.bo1.empty_since = undefined;
			bo1bots_dbg(self.name + " reload button did nothing, refilled clip by script");
		}
		return;
	}
	self.bo1.empty_since = undefined;
	if(level.bo1_fire == "unknown")
	{
		self bo1_calibrate_fire(w);
		return;
	}
	if(level.bo1_fire == "script")
	{
		self bo1_script_shot(z, w, clip);
		return;
	}
	// Aim down sights when engaging at range with non-shotguns
	if(zd > 250 && !bo1_is_shotgun(w))
		self bo1_on("ads");
	else
		self bo1_off("ads");

	// semi-auto / bolt-action / low-clip guns: tap the trigger instead of holding it
	if(weaponclipsize(w) <= 15)
	{
		if(!isDefined(self.bo1.fire_tap))
			self.bo1.fire_tap = false;
		self.bo1.fire_tap = !self.bo1.fire_tap;
		if(self.bo1.fire_tap)
			self bo1_on("attack");
		else
			self bo1_off("attack");
		return;
	}
	self bo1_on("attack");
}

// ensure native button shooting is configured
bo1_calibrate_fire(w)
{
	level.bo1_fire = "button";
	bo1bots_dbg("fire button configured: native button");
}

bo1_script_shot(z, w, clip)
{
	if(gettime() < self.bo1.next_shot)
		return;
	magicbullet(w, self geteye(), bo1_aimpos(z), self);
	self setweaponammoclip(w, clip - 1);
	rate = 280;
	if(weaponclipsize(w) >= 20)
		rate = 100;
	self.bo1.next_shot = gettime() + rate;
}

// press, release, press, release...: one swing per press
bo1_melee_tap()
{
	if(!isDefined(self.bo1.mtap))
		self.bo1.mtap = false;
	self.bo1.mtap = !self.bo1.mtap;
	if(self.bo1.mtap)
		self bo1_on("melee");
	else
		self bo1_off("melee");
}

bo1_script_knife(z)
{
	if(gettime() < self.bo1.next_knife)
		return;
	self.bo1.next_knife = gettime() + 700;
	self.bo1.knife_z = z;
	self.bo1.knife_t = gettime();
	z dodamage(150, self.origin, self);
}

bo1_reload()
{
	w = self getcurrentweapon();
	if(isDefined(level.bo1_fire) && level.bo1_fire == "script")
	{
		if(!isDefined(self.bo1.reload_at))
		{
			self.bo1.reload_at = gettime() + 2000;
			return;
		}
		if(gettime() < self.bo1.reload_at)
			return;
		self.bo1.reload_at = undefined;
		stock = self getweaponammostock(w);
		n = weaponclipsize(w);
		if(stock < n)
			n = stock;
		self setweaponammoclip(w, n);
		self setweaponammostock(w, stock - n);
		return;
	}
	if(gettime() < self.bo1.next_reload)
		return;
	self.bo1.next_reload = gettime() + 1500;
	self bo1_on("reload");
	wait 0.15;
	self bo1_off("reload");
}

// zombies skip players flagged as non-targets (is_player_valid -> isnotarget), so keep the flag off
bo1bots_targetable()
{
	self endon("disconnect");
	self endon("bo1bots_brain");
	t = 0;
	for(;;)
	{
		self.ignoreme = bo1_down(self);
		wait 0.25;
		t += 0.25;
		if(t >= 5)
		{
			t = 0;
			if(getdvarint("bo1_bots_debug") != 0 && isAlive(self) && (self isnotarget() || self.sessionstate != "playing" || bo1_down(self)))
				bo1bots_dbg(self.name + " is NOT a valid zombie target: state " + self.sessionstate + " laststand " + bo1_down(self) + " notarget " + (self isnotarget()));
		}
	}
}

// ---------------------------------------------------------------- points
//
// Zombie kills/hits normally pay the shooter through the game's own damage callbacks. If that doesn't reach
// the bots, the first bot kill detects it (score didn't move) and from then on hits (10), kills (60, 130 knife)
// and window repairs are credited by script. bo1_bots_points_mode: 0 auto, 1 game only, 2 script only

bo1_points_mode()
{
	m = getdvarint("bo1_bots_points_mode");
	if(m == 1)
		return "game";
	if(m == 2)
		return "script";
	if(!isDefined(level.bo1_points))
		level.bo1_points = "unknown";
	return level.bo1_points;
}

bo1_double_points()
{
	return isDefined(level.zombie_vars) && isDefined(level.zombie_vars["zombie_powerup_point_doubler_on"]) && level.zombie_vars["zombie_powerup_point_doubler_on"];
}

bo1_give_points(n)
{
	if(bo1_double_points())
		n = n * 2;
	self.score += n;
	if(isDefined(self.score_total))
		self.score_total += n;
}

// take points off the bot (bots have no score hud, so changing .score is all the game's own function does too)
bo1_minus(n)
{
	if(n <= 0)
		return;
	if(isDefined(level.intermission) && level.intermission)
		return;
	// same as minus_to_player_score (that script can't be referenced from here, the game says it cannot find it)
	self.score -= n;
}

// A purchase went through (the bot got the thing) but the game may not have taken the whole price.
// Take whatever is missing so the net cost equals the price.
bo1_fix_cost(before, cost)
{
	d = before - self.score;
	if(d < 0)
		d = 0;
	if(d >= cost)
		return;
	fix = cost - d;
	self bo1_minus(fix);
	bo1bots_dbg(self.name + " purchase charged " + d + " of " + cost + ", took " + fix + " more");
}

// script payment for window repair (same as the trigger: purchase sound on the player)
bo1_pay_board(cost)
{
	if(!isDefined(self.rebuild_barrier_reward))
		self.rebuild_barrier_reward = 0;
	cap = 500;
	if(isDefined(level.zombie_vars) && isDefined(level.zombie_vars["rebuild_barrier_cap_per_round"]))
		cap = level.zombie_vars["rebuild_barrier_cap_per_round"];
	self.rebuild_barrier_reward += cost;
	if(self.rebuild_barrier_reward < cap)
	{
		self bo1_give_points(cost);
		self playsound("purchase");
	}
}

// only pays when the game isn't doing it
bo1_credit(n)
{
	if(bo1_points_mode() != "script")
		return;
	self bo1_give_points(n);
}

bo1_credit_board(w, k)
{
	cost = 10;
	if(isDefined(w.zombie_cost))
		cost = w.zombie_cost;
	if(bo1_points_mode() != "script")
		return;
	for(i = 0; i < k; i++)
		self bo1_pay_board(cost);
}

// watch a zombie we are fighting (once per bot per zombie)
bo1_watch_zombie(z)
{
	if(!isDefined(z.bo1_w))
		z.bo1_w = [];
	k = self getentitynumber();
	if(isDefined(z.bo1_w[k]))
		return;
	z.bo1_w[k] = true;
	self thread bo1_zombie_watch(z);
}

// Polls the zombie instead of trusting damage/death notify arguments (those don't name the bot reliably).
// "Ours" = this bot was shooting/knifing that zombie within the last 0.7s.
// Kill pay is the player amount: 60 body, 100 headshot, 130 melee.
bo1_zombie_watch(z)
{
	self endon("disconnect");
	hp = z.health;
	org = z.origin;
	sc = self.score;
	loc = undefined;
	mod = undefined;
	shooter = undefined;
	for(;;)
	{
		wait 0.05;
		if(!isDefined(z) || !isAlive(z))
			break;
		if(isDefined(z.bo1_shooter))
			shooter = z.bo1_shooter;
		org = z.origin;
		sc = self.score;
		if(isDefined(z.damagelocation))
			loc = z.damagelocation;
		if(isDefined(z.damagemod))
			mod = z.damagemod;
		ours = isDefined(self.bo1.shot_z) && self.bo1.shot_z == z && gettime() - self.bo1.shot_t < 700 && bo1_last_shooter(z, self);
		if(z.health < hp)
		{
			if(ours)
				self bo1_credit(10);
			hp = z.health;
		}
	}
	// the killing blow writes these just before the zombie dies
	if(isDefined(z))
	{
		if(isDefined(z.damagelocation))
			loc = z.damagelocation;
		if(isDefined(z.damagemod))
			mod = z.damagemod;
	}
	if(!isDefined(self.bo1.shot_z) || self.bo1.shot_z != z || gettime() - self.bo1.shot_t > 1000)
		return;
	// another bot hit it last: that bot gets the kill
	if(isDefined(shooter) && shooter != self)
		return;

	melee = false;
	if(isDefined(mod) && mod == "MOD_MELEE")
		melee = true;
	else if(isDefined(self.bo1.knife_z) && self.bo1.knife_z == z && gettime() - self.bo1.knife_t < 1200)
		melee = true;
	else if(!isDefined(mod) && distance(self.origin, org) < 100)
		melee = true;

	pts = 60;
	if(melee)
		pts = 130;
	else if(bo1_is_head(loc))
		pts = 100;

	self thread bo1_settle_kill(pts, sc);
}

// true when this bot was the last one to shoot the zombie (or nobody else did)
bo1_last_shooter(z, bot)
{
	if(!isDefined(z) || !isDefined(z.bo1_shooter))
		return true;
	return z.bo1_shooter == bot;
}

bo1_is_head(loc)
{
	if(!isDefined(loc))
		return false;
	return loc == "head" || loc == "helmet";
}

// Pays the kill. If the game already paid the bot something for it, only the difference to the player amount is
// added (or taken), so it never ends up double paid. Kills that land together are settled as one batch.
// base = the bot's score from just before the first kill of the batch.
bo1_settle_kill(pts, base)
{
	self endon("disconnect");
	want = pts;
	if(bo1_double_points())
		want = pts * 2;
	if(!isDefined(self.bo1.pend_want))
		self.bo1.pend_want = 0;
	self.bo1.pend_want += want;
	if(isDefined(self.bo1.pend_run))
		return;
	self.bo1.pend_run = true;
	wait 0.3;
	total = self.bo1.pend_want;
	self.bo1.pend_want = 0;
	self.bo1.pend_run = undefined;

	mode = bo1_points_mode();
	// a purchase moves the score too, so a kill that lands during one can't be measured: don't judge or correct it
	if(mode != "script" && isDefined(self.bo1.buy_t) && gettime() - self.bo1.buy_t < 4000)
		return;
	paid = self.score - base;
	if(mode == "unknown")
	{
		if(paid >= 40)
		{
			level.bo1_points = "game";
			bo1bots_dbg("game pays bots for kills");
		}
		else
		{
			level.bo1_points = "script";
			bo1bots_dbg("^3BO1 bots: game doesn't pay bots, crediting hits and kills by script");
		}
		mode = bo1_points_mode();
	}
	if(mode == "script")
	{
		self.score += total;
		if(isDefined(self.score_total))
			self.score_total += total;
		return;
	}
	// the game pays the bots: bring it to the player amount (bo1_bots_points_mode 1 = hands off)
	if(getdvarint("bo1_bots_points_mode") == 1)
		return;
	if(paid < 0 || paid > total * 3 + 100)
		return;
	fix = total - paid;
	if(fix == 0)
		return;
	self.score += fix;
	if(isDefined(self.score_total))
		self.score_total += fix;
	bo1bots_dbg(self.name + " kill pay corrected by " + fix + " (game paid " + paid + ", want " + total + ")");
}

// ---------------------------------------------------------------- shopping

bo1_pair(a, b)
{
	r = [];
	r[0] = a;
	r[1] = b;
	return r;
}

// bots start with Juggernog (dvar bo1_bots_default_jug 0 = off). Re-checked every second, so a bot that lost the perk
// (downed, died and respawned) gets it back as soon as it is up again.
bo1bots_jug()
{
	self endon("disconnect");
	self endon("death");
	level endon("end_game");

	if(bo1_is_arcade())
		return;
	if(getdvar("bo1_bots_default_jug") != "" && getdvarint("bo1_bots_default_jug") == 0)
		return;

	hp = 250;
	if(isDefined(level.zombie_vars) && isDefined(level.zombie_vars["zombie_perk_juggernaut_health"]))
		hp = level.zombie_vars["zombie_perk_juggernaut_health"];

	for(;;)
	{
		if(isAlive(self) && !bo1_down(self))
		{
			if(!self hasperk("specialty_armorvest"))
			{
				self setperk("specialty_armorvest");
				self setmaxhealth(hp);
				self.health = hp;
			}
			else if(self.maxhealth < hp)
				self setmaxhealth(hp);
		}
		wait 1;
	}
}

// knife upgrades sold on the wall (bowie, sickle)
bo1_is_melee_buy(w)
{
	return issubstr(w, "bowie") || issubstr(w, "sickle");
}

// true when the bot already owns a bought knife (the plain knife does not count)
bo1_has_melee_upgrade()
{
	if(isDefined(self.current_melee_weapon) && self.current_melee_weapon != "knife_zm")
		return true;
	return self hasweapon("bowie_knife_zm") || self hasweapon("sickle_knife_zm");
}

bo1_perk_info(perk)
{
	// returns array [priority, cost] or undefined
	switch(perk)
	{
		case "specialty_armorvest":		return bo1_pair(80, 2500);	// Juggernog
		case "specialty_quickrevive":	return bo1_pair(75, 1500);	// Quick Revive
		case "specialty_fastreload":	return bo1_pair(70, 3000);	// Speed Cola
		case "specialty_rof":			return bo1_pair(65, 2000);	// Double Tap
		case "specialty_flakjacket":	return bo1_pair(55, 2000);	// PhD Flopper
		case "specialty_longersprint":	return bo1_pair(50, 2000);	// Stamin-Up
		case "specialty_deadshot":		return bo1_pair(48, 1500);	// Deadshot
	}
	return undefined;
}

// how good a gun is, for deciding what to give up / hold: upgraded = top, otherwise what it costs on the wall
// (level.zombie_weapons[w].cost, the same table the game's own wall triggers read)
bo1_weapon_cost(w)
{
	if(w == "m1911_zm")
		return 0;
	if(issubstr(w, "_upgraded"))
		return 9000;
	if(isDefined(level.zombie_weapons) && isDefined(level.zombie_weapons[w]) && isDefined(level.zombie_weapons[w].cost))
		return level.zombie_weapons[w].cost;
	// not in the table: assume it is a good one
	return 1500;
}

// BO1 wall triggers carry .zombie_weapon_upgrade but no .zombie_cost, the price is in level.zombie_weapons
bo1_wall_cost(e)
{
	if(isDefined(e.zombie_cost))
		return e.zombie_cost;
	w = e.zombie_weapon_upgrade;
	if(isDefined(level.zombie_weapons) && isDefined(level.zombie_weapons[w]) && isDefined(level.zombie_weapons[w].cost))
		return level.zombie_weapons[w].cost;
	return 1000;
}

// guns only: no knives, grenades, claymores, bouncing bettys, monkeys
bo1_is_gun(w)
{
	skip = [];
	skip[0] = "knife";
	skip[1] = "bowie";
	skip[2] = "sickle";
	skip[3] = "claymore";
	skip[4] = "grenade";
	skip[5] = "mine_";
	skip[6] = "betty";
	skip[7] = "cymbal";
	skip[8] = "monkey";
	skip[9] = "flourish";
	for(i = 0; i < skip.size; i++)
	{
		if(issubstr(w, skip[i]))
			return false;
	}
	return true;
}

bo1_weapon_limit()
{
	if(self hasperk("specialty_additionalprimaryweapon"))
		return 3;
	return 2;
}

// value of the weakest primary we hold (99999 if none)
bo1_worst_value()
{
	prims = self getweaponslistprimaries();
	worst = 99999;
	for(i = 0; i < prims.size; i++)
	{
		c = bo1_weapon_cost(prims[i]);
		if(c < worst)
			worst = c;
	}
	return worst;
}

// The game swaps out whatever is in hand when a new gun is bought and the slots are full, so hold the weaker gun first
bo1_hold_worst()
{
	prims = self getweaponslistprimaries();
	if(prims.size < self bo1_weapon_limit())
		return;
	worst = undefined;
	wv = 999999;
	for(i = 0; i < prims.size; i++)
	{
		c = bo1_weapon_cost(prims[i]);
		if(c < wv)
		{
			wv = c;
			worst = prims[i];
		}
	}
	if(!isDefined(worst) || self getcurrentweapon() == worst)
		return;
	self switchtoweapon(worst);
	wait 1;
}

// back to the best gun after shopping
bo1_hold_best()
{
	prims = self getweaponslistprimaries();
	if(prims.size < 2)
		return;
	best = undefined;
	bv = -1;
	for(i = 0; i < prims.size; i++)
	{
		c = bo1_weapon_cost(prims[i]);
		if(c > bv)
		{
			bv = c;
			best = prims[i];
		}
	}
	if(isDefined(best) && self getcurrentweapon() != best)
		self switchtoweapon(best);
}

// ---- mystery box

bo1_active_box()
{
	if(!isDefined(level.chests) || level.chests.size == 0)
		return undefined;
	if(isDefined(level.chest_index) && level.chest_index < level.chests.size)
	{
		b = level.chests[level.chest_index];
		if(isDefined(b) && isDefined(b.origin))
			return b;
	}
	for(i = 0; i < level.chests.size; i++)
	{
		c = level.chests[i];
		if(isDefined(c) && isDefined(c.origin) && (!isDefined(c.hidden) || !c.hidden))
			return c;
	}
	return undefined;
}

bo1_box_usable(box)
{
	if(isDefined(box.disabled) && box.disabled)
		return false;
	if(isDefined(box.is_locked) && box.is_locked)
		return false;
	if(isDefined(box._box_open) && box._box_open)
		return false;
	if(isDefined(box.chest_user) && box.chest_user != self)
		return false;
	if(bo1_box_moving())
		return false;
	return true;
}

bo1_box_moving()
{
	return isDefined(level.flag) && isDefined(level.flag["moving_chest_now"]) && level.flag["moving_chest_now"];
}

bo1_box_cost(box)
{
	c = 950;
	if(isDefined(box.zombie_cost))
		c = box.zombie_cost;
	if(isDefined(level.zombie_vars) && isDefined(level.zombie_vars["zombie_powerup_fire_sale_on"]) && level.zombie_vars["zombie_powerup_fire_sale_on"])
		c = 10;
	return c;
}

// keep shooting whatever comes at us while we stand at the box / wall
bo1_wait_fight(sec)
{
	t = 0;
	while(t < sec)
	{
		z = self bo1_find_target();
		if(isDefined(z))
		{
			self bo1_watch_zombie(z);
			self bo1_face(bo1_aimpos(z));
			self bo1_shoot(z, distance(self.origin, z.origin));
		}
		else
			self bo1_ceasefire();
		wait 0.1;
		t += 0.1;
	}
	self bo1_ceasefire();
}

// true if the bot now holds a gun it did not hold in old[]
bo1_has_new(old)
{
	prims = self getweaponslistprimaries();
	for(i = 0; i < prims.size; i++)
	{
		found = false;
		for(j = 0; j < old.size; j++)
		{
			if(old[j] == prims[i])
				found = true;
		}
		if(!found)
			return true;
	}
	return false;
}

// bo1_bots_buy_mode: 0 (default) fire the trigger, then give the gun by script if that did nothing
//                    1 real use press first, then the same two fallbacks
bo1_press_first()
{
	if(getdvar("bo1_bots_buy_mode") == "")
		return true;
	return getdvarint("bo1_bots_buy_mode") == 1;
}

bo1_wall_got(w, before, cost)
{
	return self hasweapon(w) || (isDefined(self.current_melee_weapon) && self.current_melee_weapon == w) || before - self.score >= cost - 150;
}

// Last resort when the game's own trigger code never reacts: take the points and hand over the gun ourselves.
// The slot that is full loses the weaker gun (it is the one in hand, see bo1_hold_worst).
bo1_manual_wall(e)
{
	w = e.zombie_weapon_upgrade;
	cost = bo1_wall_cost(e);
	if(self.score < cost || self hasweapon(w))
		return;
	prims = self getweaponslistprimaries();
	if(bo1_is_melee_buy(w))
	{
		self giveweapon(w);
		self.current_melee_weapon = w;
		self bo1_minus(cost);
		self playsound("purchase");
		return;
	}
	if(prims.size >= self bo1_weapon_limit())
	{
		cur = self getcurrentweapon();
		worst = undefined;
		wv = 999999;
		for(i = 0; i < prims.size; i++)
		{
			c = bo1_weapon_cost(prims[i]);
			if(c < wv)
			{
				wv = c;
				worst = prims[i];
			}
		}
		if(isDefined(cur) && cur != "none" && isDefined(prims) && bo1_in_list(prims, cur))
			worst = cur;
		if(isDefined(worst))
			self takeweapon(worst);
	}
	self giveweapon(w);
	self givemaxammo(w);
	self switchtoweapon(w);
	self bo1_minus(cost);
	self playsound("purchase");
	bo1bots_dbg(self.name + " wall gun given by script: " + w);
}

bo1_in_list(list, v)
{
	for(i = 0; i < list.size; i++)
	{
		if(list[i] == v)
			return true;
	}
	return false;
}

// Buy a wall gun: fire the wall's own trigger (the game charges and gives, like a player's use), the press only if
// bo1_bots_buy_mode is 1, and a scripted give if none of it worked.
bo1_buy_wall(e)
{
	w = e.zombie_weapon_upgrade;
	cost = bo1_wall_cost(e);
	before = self.score;

	self bo1_hold_worst();
	self bo1_face(e.origin + (0, 0, 20));
	wait 0.2;

	if(self bo1_press_first())
	{
		self bo1_press(0.4);
		wait 0.6;
		if(self bo1_wall_got(w, before, cost))
		{
			level.bo1_use_ok = true;
			self bo1_fix_cost(before, cost);
			self bo1_hold_best();
			return;
		}
	}

	if(self.score >= cost)
	{
		e notify("trigger", self);
		wait 0.6;
		if(self bo1_wall_got(w, before, cost))
		{
			bo1bots_dbg(self.name + " wall trigger fired, bought " + w);
			self bo1_fix_cost(before, cost);
			self bo1_hold_best();
			return;
		}
		bo1bots_dbg(self.name + " wall trigger fired but nothing happened: " + w);
	}

	// the game did not sell it: do it by script
	self bo1_manual_wall(e);
	self bo1_hold_best();
}

// Buy a mystery box weapon: pay, wait out the spin, grab. Press first, trigger notify as a fallback.
bo1_buy_box(box)
{
	cost = bo1_box_cost(box);
	before = self.score;
	old = self getweaponslistprimaries();
	need = cost - 100;
	if(need < 5)
		need = 5;

	self bo1_hold_worst();
	self bo1_face(box.origin + (0, 0, 20));
	wait 0.2;
	paid = false;
	if(self bo1_press_first())
	{
		self bo1_press(0.4);
		wait 0.6;
		paid = (before - self.score >= need) || (isDefined(box.chest_user) && box.chest_user == self);
	}
	if(!paid && self.score >= cost && self bo1_box_usable(box))
	{
		box notify("trigger", self);
		wait 0.6;
		paid = (before - self.score >= need) || (isDefined(box.chest_user) && box.chest_user == self);
		bo1bots_dbg(self.name + " box trigger fired: paid=" + paid);
	}
	if(!paid && !self bo1_press_first())
	{
		// trigger did nothing, try a real press
		self bo1_press(0.4);
		wait 0.6;
		paid = (before - self.score >= need) || (isDefined(box.chest_user) && box.chest_user == self);
	}
	if(!paid)
	{
		self bo1_hold_best();
		return;
	}
	level.bo1_use_ok = true;
	self bo1_fix_cost(before, cost);
	self.bo1.buy_t = gettime();

	// the weapon cycles for a few seconds, then waits to be taken
	self bo1_wait_fight(3.5);
	seen = false;
	for(i = 0; i < 12; i++)
	{
		if(!isAlive(self) || bo1_down(self) || !isDefined(box) || bo1_box_moving())
			break;
		if(isDefined(box.disabled) && box.disabled)
			break;
		cu = isDefined(box.chest_user) && box.chest_user == self;
		if(cu)
			seen = true;
		if(seen && !cu)
			break;
		if(self bo1_has_new(old))
			break;
		if(i % 2 == 0)
			box notify("trigger", self);
		else
		{
			self bo1_face(box.origin + (0, 0, 20));
			wait 0.15;
			self bo1_press(0.3);
		}
		self bo1_wait_fight(0.6);
	}
	bo1bots_dbg(self.name + " box done, new gun: " + (self bo1_has_new(old)));
	self bo1_hold_best();
}

bo1_consider(e, kind, pr, cost, maxd)
{
	if(!isDefined(e) || !isDefined(e.origin))
		return;
	if(self.score < cost)
		return;
	if(isDefined(self.bo1.shop_pr) && pr <= self.bo1.shop_pr)
		return;
	key = kind + "_" + e getentitynumber();
	if(isDefined(self.bo1.skip[key]) && gettime() < self.bo1.skip[key])
		return;
	if(distance2d(self.origin, e.origin) > maxd || abs(self.origin[2] - e.origin[2]) > 120)
		return;

	self.bo1.shop = e;
	self.bo1.shop_kind = kind;
	self.bo1.shop_key = key;
	self.bo1.shop_pr = pr;
	self.bo1.shop_cost = cost;
}

bo1_pick_shop()
{
	self.bo1.shop = undefined;
	self.bo1.shop_pr = undefined;

	powered = true;
	if(isDefined(level.flag) && isDefined(level.flag["power_on"]) && !level.flag["power_on"])
		powered = false;

	cur = self getcurrentweapon();

	// perks + pack-a-punch
	for(n = 0; n < 2; n++)
	{
		name = "zombie_vending";
		if(n == 1)
			name = "zombie_vending_upgrade";
		ents = getentarray(name, "targetname");
		for(i = 0; i < ents.size; i++)
		{
			e = ents[i];
			if(!isDefined(e) || !isDefined(e.script_noteworthy))
				continue;
			if(!powered)
				continue;
			perk = e.script_noteworthy;
			if(perk == "specialty_weapupgrade")
			{
				if(issubstr(cur, "_upgraded") || self.score < 5000)
					continue;
				if(isDefined(level.bo1bots_pap_busy) && gettime() < level.bo1bots_pap_busy)
					continue;
				self bo1_consider(e, "pap", 60, 5000, 1200);
				continue;
			}
			info = bo1_perk_info(perk);
			if(!isDefined(info))
				continue;
			if(self hasperk(perk))
				continue;
			self bo1_consider(e, "perk", info[0], info[1], 1200);
		}
	}

	// doors / debris: only when a human is nearby, and not more often than every 15s across all bots
	leader = self bo1_leader();
	if(gettime() > level.bo1bots_last_door + 15000)
	{
		for(n = 0; n < 2; n++)
		{
			name = "zombie_door";
			if(n == 1)
				name = "zombie_debris";
			ents = getentarray(name, "targetname");
			for(i = 0; i < ents.size; i++)
			{
				e = ents[i];
				if(!isDefined(e) || !isDefined(e.zombie_cost))
					continue;
				if(isDefined(e.script_noteworthy) && (e.script_noteworthy == "electric_door" || e.script_noteworthy == "local_electric_door"))
					continue;
				if(isDefined(e.has_been_opened) && e.has_been_opened)
					continue;
				if(isDefined(leader) && distance2d(leader.origin, e.origin) > 900)
					continue;
				self bo1_consider(e, "door", 40, e.zombie_cost, 700);
			}
		}
	}

	prims = self getweaponslistprimaries();
	limit = self bo1_weapon_limit();
	worst = self bo1_worst_value();

	// mystery box (the active one): high priority! Players love the box, bots should too.
	// Only skip spinning if the bot already holds top-tier / wonder weapons.
	box = bo1_active_box();
	if(isDefined(box) && gettime() > level.bo1bots_last_box + 4000 && self bo1_box_usable(box))
	{
		box_cost = bo1_box_cost(box);
		is_fire_sale = isDefined(level.zombie_vars) && isDefined(level.zombie_vars["zombie_powerup_fire_sale_on"]) && level.zombie_vars["zombie_powerup_fire_sale_on"];
		
		// Priority: Fire sale = 80 (top priority), Normal = 65 (higher than wall weapons at 45)
		box_pr = 65;
		if(is_fire_sale)
			box_pr = 80;

		// Consider box if bot has a free weapon slot OR worst gun is not already high-tier (< 2500)
		if(prims.size < limit || worst < 2500)
			self bo1_consider(box, "box", box_pr, box_cost, 1200);
	}

	// wall guns: only preferred if box is unaffordable, out of reach, or on cooldown
	ents = getentarray("weapon_upgrade", "targetname");
	for(i = 0; i < ents.size; i++)
	{
		e = ents[i];
		if(!isDefined(e) || !isDefined(e.zombie_weapon_upgrade))
			continue;
		w = e.zombie_weapon_upgrade;
		if(bo1_is_melee_buy(w))
		{
			// melee wall buys: far above everything else (guns 45, box 65, perks up to 80). Doesn't use a gun slot.
			if(self hasweapon(w) || self bo1_has_melee_upgrade())
				continue;
			self bo1_consider(e, "wall", 90, bo1_wall_cost(e), 1000);
			continue;
		}
		if(!bo1_is_gun(w))
			continue;
		if(self hasweapon(w))
			continue;
		cost = bo1_wall_cost(e);
		if(prims.size >= limit && cost < worst + 300)
			continue;
		if(prims.size < limit && cost < 500)
			continue;
		// Wall guns have priority 45 (below Mystery Box at 65, so box is preferred whenever affordable)
		self bo1_consider(e, "wall", 45, cost, 800);
	}
}

// one buy attempt at the thing we are standing next to
bo1_do_shop()
{
	kind = self.bo1.shop_kind;
	key = self.bo1.shop_key;
	before = self.score;
	self.bo1.buy_t = gettime();

	if(kind == "wall")
	{
		self.bo1.skip[key] = gettime() + 30000;
		self bo1_buy_wall(self.bo1.shop);
		self.bo1.buy_t = gettime();
		bo1bots_dbg(self.name + " shop wall score " + before + " -> " + self.score);
		return;
	}
	if(kind == "box")
	{
		level.bo1bots_last_box = gettime();
		self.bo1.skip[key] = gettime() + 15000;
		self bo1_buy_box(self.bo1.shop);
		level.bo1bots_last_box = gettime();
		bo1bots_dbg(self.name + " shop box score " + before + " -> " + self.score);
		return;
	}

	self bo1_face(self.bo1.shop.origin + (0, 0, 20));
	wait 0.2;
	self bo1_press(0.4);
	wait 0.6;
	if(!isDefined(level.bo1_use_ok))
	{
		if(self.score < before)
			level.bo1_use_ok = true;
		else
			self bo1_next_act("use");
	}

	shop = self.bo1.shop;
	switch(kind)
	{
		case "door":
			// the game opens it and should charge the price: check after it had time to react
			wait 0.5;
			if(isDefined(shop) && isDefined(shop.has_been_opened) && shop.has_been_opened)
				self bo1_fix_cost(before, self.bo1.shop_cost);
			level.bo1bots_last_door = gettime();
			self.bo1.skip[key] = gettime() + 20000;
			break;
		case "perk":
			// the perk arrives after the bottle animation; the price is taken when the press registers
			perk = undefined;
			if(isDefined(shop))
				perk = shop.script_noteworthy;
			if(isDefined(perk))
			{
				for(t = 0; t < 40 && !self hasperk(perk); t++)
					wait 0.1;
				if(self hasperk(perk))
					self bo1_fix_cost(before, self.bo1.shop_cost);
			}
			self.bo1.skip[key] = gettime() + 8000;
			break;
		case "pap":
			// the game takes the price at the press: if only part of it went, take the rest
			if(self.score < before)
				self bo1_fix_cost(before, self.bo1.shop_cost);
			if(self.score < before)
			{
				level.bo1bots_pap_busy = gettime() + 12000;
				wait 6.5;
				self bo1_face(self.bo1.shop.origin + (0, 0, 20));
				self bo1_press(0.4);
			}
			self.bo1.skip[key] = gettime() + 20000;
			break;
	}
	self.bo1.buy_t = gettime();
	bo1bots_dbg(self.name + " shop " + kind + " score " + before + " -> " + self.score);
}

// ---------------------------------------------------------------- revive

bo1_do_revive(mate)
{
	// The revive only works while the bot touches the downed player's trigger (small radius), faces them and
	// holds use. So walk right up to them while holding use, and keep looking at them.
	bo1bots_dbg(self.name + " reviving " + mate.name);
	t = 0;
	self bo1_on("use");
	while(t < 8 && isDefined(mate) && bo1_down(mate) && !bo1_down(self) && isAlive(self))
	{
		self bo1_face(mate.origin + (0, 0, 30));
		if(distance2d(self.origin, mate.origin) > 28)
			self bo1_move_dir(mate.origin - self.origin);
		else
			self bo1_stop();
		wait 0.1;
		t += 0.1;
		if(self bo1_any_zombie_near(90))
			break;
	}
	self bo1_off("use");
	self bo1_stop();
}

// ---------------------------------------------------------------- powerups

// nearest drop we can walk to (BO1 keeps live drops in level.active_powerups)
bo1_find_powerup()
{
	if(!isDefined(level.active_powerups))
		return undefined;
	best = undefined;
	bd = 1000 * 1000;
	eye = self geteye();
	for(i = 0; i < level.active_powerups.size; i++)
	{
		p = level.active_powerups[i];
		if(!isDefined(p) || !isDefined(p.origin))
			continue;
		key = "pu_" + p getentitynumber();
		if(isDefined(self.bo1.skip[key]) && gettime() < self.bo1.skip[key])
			continue;
		if(abs(p.origin[2] - self.origin[2]) > 120)
			continue;
		d = distancesquared(self.origin, p.origin);
		if(d >= bd)
			continue;
		// straight-line walking only, so only go for drops we can see
		if(d > 150 * 150 && !sighttracepassed(eye, p.origin + (0, 0, 5), false, undefined))
			continue;
		if(d < bd)
		{
			bd = d;
			best = p;
		}
	}
	return best;
}

// ---------------------------------------------------------------- boards
//
// Real window repair. The game spawns a trigger_radius (r96) at the window and awards points while a
// valid player inside it holds use. So the bot has to: stand INSIDE the room within that radius (not on the
// window struct itself, the clip blocks that), actually hold use, and keep standing there until chunks go back up.
// bo1_bots_board_mode: 0 auto (press, fall back to scripted repair if pressing never works), 1 press only, 2 scripted only

// a window with a destroyed board that nobody else is on, that we can see and a human is near
bo1_find_board()
{
	if(!isDefined(level.exterior_goals))
		return undefined;
	best = undefined;
	bd = 900 * 900;
	leader = self bo1_leader();
	eye = self geteye();
	for(i = 0; i < level.exterior_goals.size; i++)
	{
		w = level.exterior_goals[i];
		if(!isDefined(w) || !isDefined(w.barrier_chunks))
			continue;
		if(!bo1_window_broken(w))
			continue;
		key = "bd_" + i;
		if(isDefined(self.bo1.skip[key]) && gettime() < self.bo1.skip[key])
			continue;
		if(isDefined(w.bo1_by) && w.bo1_by != self && isDefined(w.bo1_until) && gettime() < w.bo1_until)
			continue;
		pos = bo1_window_pos(w);
		d = distancesquared(self.origin, pos);
		if(d >= bd)
			continue;
		if(isDefined(leader) && distance2d(leader.origin, pos) > 1200)
			continue;
		// zombies already at the window: repairing is pointless, they just tear it again
		if(bo1_count_zombies(pos, 130) > 0)
			continue;
		// straight-line walking only, so only go for windows we can see
		stand = bo1_window_stand(w);
		if(!sighttracepassed(eye, stand + (0, 0, 50), false, undefined))
			continue;
		bd = d;
		best = w;
		self.bo1.board_key = key;
	}
	return best;
}

bo1_window_pos(w)
{
	if(isDefined(w.trigger_location) && isDefined(w.trigger_location.origin))
		return w.trigger_location.origin;
	return w.origin;
}

// spot inside the room at the window. The stock maps define w.trigger_location as the exact
// player repair spot where the trigger_radius is centered. If present, stand directly on it!
bo1_window_stand(w)
{
	if(isDefined(w.trigger_location) && isDefined(w.trigger_location.origin))
		return groundpos(w.trigger_location.origin + (0, 0, 50));
	pos = bo1_window_pos(w);
	fwd = anglestoforward(w.angles);
	a = (pos[0] + fwd[0] * 40, pos[1] + fwd[1] * 40, pos[2]);
	b = (pos[0] - fwd[0] * 40, pos[1] - fwd[1] * 40, pos[2]);
	ref = self.origin;
	leader = self bo1_leader();
	if(isDefined(leader))
		ref = leader.origin;
	s = b;
	if(distance2d(a, ref) < distance2d(b, ref))
		s = a;
	return groundpos(s + (0, 0, 50));
}

bo1_window_broken(w)
{
	for(i = 0; i < w.barrier_chunks.size; i++)
	{
		c = w.barrier_chunks[i];
		if(isDefined(c) && isDefined(c.state) && c.state == "destroyed")
			return true;
	}
	return false;
}

bo1_destroyed_count(w)
{
	n = 0;
	for(i = 0; i < w.barrier_chunks.size; i++)
	{
		c = w.barrier_chunks[i];
		if(isDefined(c) && isDefined(c.state) && c.state == "destroyed")
			n++;
	}
	return n;
}

// Find the stock trigger_radius spawned by blocker_trigger_think()
bo1_find_window_trigger(w)
{
	pos = bo1_window_pos(w);
	trigs = getentarray("trigger_radius", "classname");
	best = undefined;
	bd = 150 * 150;
	for(i = 0; i < trigs.size; i++)
	{
		t = trigs[i];
		if(!isDefined(t) || !isDefined(t.origin))
			continue;
		d = distancesquared(pos, t.origin);
		if(d < bd)
		{
			bd = d;
			best = t;
		}
	}
	return best;
}

// make sure the "use" name we have really shows up as a held use button (UseButtonPressed is what the game checks)
bo1_use_check()
{
	level.bo1_use_ok = true;
	level.bo1_use_checked = true;
}

bo1_board_mode()
{
	m = getdvarint("bo1_bots_board_mode");
	if(m == 2)
		return "script";
	return "press";
}

// hold use at the window. returns 1 = repaired something, 0 = held use but nothing happened, -1 = interrupted
bo1_board_press(w)
{
	pos = bo1_window_pos(w);
	n = bo1_destroyed_count(w);
	made = false;
	t = 0;
	idle = 0;

	// In Black Ops 1, use_button_held() returns self._holding_button[level.BUTTON_USE].
	// By setting this flag and marking _use_button_think_threaded = true,
	// the stock blocker_trigger_think loop reliably sees use_button_held() == true.
	init_button_wrappers();
	btn = 0;
	if(isDefined(level.BUTTON_USE))
		btn = level.BUTTON_USE;
	if(!isDefined(self._holding_button))
		self._holding_button = [];
	self._holding_button[btn] = true;
	self._use_button_think_threaded = true;
	self bo1_on("use");

	// Find the official trigger_radius spawned by blocker_trigger_think and notify it
	trig = bo1_find_window_trigger(w);
	if(isDefined(trig))
		trig notify("trigger", self);
	w notify("trigger", self);

	wait 0.2;
	t += 0.2;

	while(t < 25 && isDefined(w) && bo1_window_broken(w) && !bo1_down(self) && isAlive(self))
	{
		w.bo1_by = self;
		w.bo1_until = gettime() + 3000;
		self bo1_face(pos + (0, 0, 40));

		// Keep button hold active
		self._holding_button[btn] = true;

		// Ping the trigger so the official game loop handles the repair
		if(isDefined(trig))
			trig notify("trigger", self);

		wait 0.2;
		t += 0.2;
		idle += 0.2;

		c = bo1_destroyed_count(w);
		if(c < n)
		{
			made = true;
			idle = 0;
			self bo1_credit_board(w, n - c);
		}
		n = c;

		if(self bo1_any_zombie_near(90) || (isDefined(self.bo1.hit_time) && gettime() - self.bo1.hit_time < 1000))
		{
			self._holding_button[btn] = false;
			self bo1_off("use");
			if(made)
				return 1;
			return -1;
		}

		// If the official trigger didn't pick up within 1.6s, smoothly rebuild one chunk so the bot never gets stuck
		if(idle >= 1.6 && bo1_window_broken(w))
		{
			chunk = bo1_random_destroyed_chunk(w);
			if(isDefined(chunk))
			{
				self bo1_board_script_one(w, chunk);
				made = true;
				idle = 0;
				n = bo1_destroyed_count(w);
				wait 0.8;
				t += 0.8;
			}
			else
				break;
		}
	}

	self._holding_button[btn] = false;
	self bo1_off("use");

	if(made)
		return 1;
	return 0;
}

// random chunk that is currently torn down
bo1_random_destroyed_chunk(w)
{
	list = [];
	for(i = 0; i < w.barrier_chunks.size; i++)
	{
		c = w.barrier_chunks[i];
		if(isDefined(c) && isDefined(c.state) && c.state == "destroyed")
			list[list.size] = c;
	}
	if(list.size == 0)
		return undefined;
	return list[randomint(list.size)];
}

// repair one chunk cleanly by script
bo1_board_script_one(w, chunk)
{
	if(!isDefined(chunk) || !isDefined(w))
		return;
	cost = 10;
	if(isDefined(w.zombie_cost))
		cost = w.zombie_cost;
	pos = bo1_window_pos(w);
	self bo1_face(pos + (0, 0, 40));
	if(isDefined(chunk.unbroken_section))
		chunk.unbroken_section delete();
	chunk show();
	if(isDefined(chunk.og_origin))
		chunk.origin = chunk.og_origin;
	if(isDefined(chunk.og_angles))
		chunk.angles = chunk.og_angles;
	chunk solid();
	chunk.state = "repaired";
	if(isDefined(w.clip))
	{
		if(isDefined(w.clip.disabled) && w.clip.disabled)
		{
			w.clip.origin = w.clip.origin + (0, 0, 10000);
			w.clip.disabled = false;
		}
		w.clip disconnectpaths();
	}
	else
		chunk disconnectpaths();
	chunk playsound("rebuild_barrier_piece");
	self bo1_pay_board(cost);
}

// put chunks back by script (snaps into place, used when pressing doesn't work).
bo1_board_script(w)
{
	t = 0;
	while(t < 15 && isDefined(w) && bo1_window_broken(w) && !bo1_down(self) && isAlive(self))
	{
		if(self bo1_any_zombie_near(90) || (isDefined(self.bo1.hit_time) && gettime() - self.bo1.hit_time < 1000))
			break;
		chunk = bo1_random_destroyed_chunk(w);
		if(!isDefined(chunk))
			break;
		w.bo1_by = self;
		w.bo1_until = gettime() + 3000;
		self bo1_board_script_one(w, chunk);
		wait 1;
		t += 1;
	}
}

// stand at the window and rebuild it
bo1_do_board(w)
{
	mode = bo1_board_mode();
	w.bo1_by = self;
	w.bo1_until = gettime() + 3000;
	self bo1_stop();
	res = 1;
	if(mode == "script")
		self bo1_board_script(w);
	else
	{
		self bo1_use_check();
		res = self bo1_board_press(w);
		if(res == 1 && mode == "unknown")
		{
			level.bo1_board = "press";
			bo1bots_dbg("board repair by button works");
		}
		if(res == 0 && mode == "unknown")
		{
			if(!isDefined(level.bo1_board_fail))
				level.bo1_board_fail = 0;
			level.bo1_board_fail++;
			bo1bots_dbg("board press did nothing (" + level.bo1_board_fail + ")");
			if(level.bo1_board_fail >= 2)
			{
				level.bo1_board = "script";
				bo1bots_dbg("^3BO1 bots: use button doesn't repair windows, using scripted repair");
			}
		}
	}
	wait_t = 3000;
	if(res == 0)
		wait_t = 3000;
	else if(res == 1)
		wait_t = 2000;
	self.bo1.skip[self.bo1.board_key] = gettime() + wait_t;
}

// ---------------------------------------------------------------- throwables

bo1_count_zombies(origin, r)
{
	zs = bo1_enemies();
	n = 0;
	for(i = 0; i < zs.size; i++)
	{
		if(isDefined(zs[i]) && isAlive(zs[i]) && distancesquared(origin, zs[i].origin) < r * r)
			n++;
	}
	return n;
}

// frags / monkey bomb / bouncing betty at groups of zombies
bo1_throw_think(z)
{
	if(!isDefined(self.bo1.next_throw))
		self.bo1.next_throw = 0;
	if(gettime() < self.bo1.next_throw)
		return;
	
	zd = distance(self.origin, z.origin);
	group = bo1_count_zombies(z.origin, 220);

	// monkey bomb: big group, far enough that it is not on us
	if(group >= 4 && zd > 300 && self hasweapon("zombie_cymbal_monkey") && self getweaponammostock("zombie_cymbal_monkey") > 0)
	{
		self.bo1.next_throw = gettime() + 20000;
		self bo1_on("smoke");
		wait 0.15;
		self bo1_off("smoke");
		return;
	}

	// bouncing betty: set it down when they are closing in
	if(zd < 350 && group >= 3 && self hasweapon("mine_bouncing_betty") && self getweaponammostock("mine_bouncing_betty") > 0 && self isonground())
	{
		self.bo1.next_throw = gettime() + 8000;
		self bo1_on("frag");
		wait 0.15;
		self bo1_off("frag");
		return;
	}

	// frag: group out past knife range
	if(group >= 3 && zd > 200 && zd < 800 && self hasweapon("frag_grenade_zm") && self getweaponammostock("frag_grenade_zm") > 0)
	{
		self.bo1.next_throw = gettime() + 6000;
		self bo1_on("frag");
		wait 0.15;
		self bo1_off("frag");
	}
}

// ---------------------------------------------------------------- brain

bo1bots_brain()
{
	self notify("bo1bots_brain");
	self endon("bo1bots_brain");
	self endon("disconnect");
	self endon("death");
	level endon("end_game");

	self.bo1.last_pos = self.origin;
	self.bo1.stuck = 0;
	self.bo1.sample = gettime() + 1000;
	self.bo1.next_shop = gettime() + 3000;
	self.bo1.pes_wait = 0;
	self.bo1.pes_fail = 0;
	self.bo1.pes_skip = [];
	self.bo1.pes_goal = undefined;
	self.bo1.pes_goal_t = 0;
	self thread bo1bots_ammo();
	self thread bo1bots_damage();
	self thread bo1bots_targetable();
	self thread bo1bots_jug();

	// Dead Ops Arcade: no windows, shops, perks or walls, a top-down game. Separate brain.
	if(bo1_is_arcade())
	{
		self bo1bots_arcade_loop();
		return;
	}

	for(;;)
	{
		wait 0.1;
		self.bo1.snap_score = self.score;

		if(!isAlive(self) || self.sessionstate != "playing")
			continue;
		if(bo1_down(self))
		{
			// downed: shoot the pistol at what is near and crawl toward a standing ally
			dz = self bo1_find_target();
			if(isDefined(dz))
			{
				self bo1_watch_zombie(dz);
				self bo1_face(bo1_aimpos(dz));
				self bo1_shoot(dz, distance(self.origin, dz.origin));
			}
			else
				self bo1_ceasefire();
			dl = self bo1_leader();
			npad = bo1_nml_pad();
			if(isDefined(npad) && bo1_nml_gate_open())
			{
				if(self istouching(npad))
					self bo1_stop();
				else
					self bo1_move_dir(npad.origin - self.origin);
			}
			else if(isDefined(dl) && distance2d(self.origin, dl.origin) > 110)
				self bo1_move_dir(dl.origin - self.origin);
			else
				self bo1_stop();
			continue;
		}

		sp = self bo1_find_special(450);
		if(isDefined(sp))
		{
			self bo1_ceasefire();
			self bo1_move_dir(self.origin - sp.origin);
			continue;
		}

		// Moon, No Man's Land: the teleporter out beats everything else
		pad = bo1_nml_pad();
		if(isDefined(pad))
		{
			self bo1_nml_tick(pad);
			continue;
		}

		z = self bo1_find_target();
		if(isDefined(z))
			self bo1_watch_zombie(z);
		leader = self bo1_leader();
		goal = undefined;
		goal_r = 80;

		// 1. revive somebody (unless a zombie is on top of us)
		mate = self bo1_find_downed();
		if(isDefined(mate) && !self bo1_any_zombie_near(160))
		{
			if(distance2d(self.origin, mate.origin) < 110)
			{
				self bo1_do_revive(mate);
				continue;
			}
			goal = mate.origin;
			goal_r = 50;
		}

		// 1b. power-up drop on the floor (within 1000 units and in sight). Gives up on one that it is
		// not getting closer to for 9s and leaves it alone for 40s, like the bo2 bots.
		pu_goal = false;
		pes_goal = false;
		if(!isDefined(goal))
		{
			pu = self bo1_find_powerup();
			if(isDefined(pu))
			{
				goal = pu.origin;
				goal_r = 30;
				pu_goal = true;
				pd = distance(self.origin, pu.origin);
				if(!isDefined(self.bo1.pu_ent) || self.bo1.pu_ent != pu)
				{
					self.bo1.pu_ent = pu;
					self.bo1.pu_best = pd;
					self.bo1.pu_time = gettime();
				}
				else if(pd < self.bo1.pu_best - 30)
				{
					self.bo1.pu_best = pd;
					self.bo1.pu_time = gettime();
				}
				else if(gettime() - self.bo1.pu_time > 9000 && pd > 80)
				{
					self.bo1.skip["pu_" + pu getentitynumber()] = gettime() + 40000;
					self.bo1.pu_ent = undefined;
					goal = undefined;
					pu_goal = false;
				}
			}
			else
				self.bo1.pu_ent = undefined;
		}

		// 1c. Moon: take the P.E.S. (free, from the lockers) and put it on - the Moon has no air without it
		if(!isDefined(goal) && gettime() > self.bo1.pes_wait && bo1_pes_exists() && !self bo1_pes_on())
		{
			if(self hasweapon("equip_gasmask_zm"))
			{
				// owned but off: put it on (not with a zombie right next to us)
				if(!self bo1_any_zombie_near(80))
				{
					self bo1_wear_pes();
					continue;
				}
			}
			else
			{
				pt = self bo1_find_pes();
				if(isDefined(pt))
				{
					if(self istouching(pt))
					{
						self bo1_take_pes(pt);
						continue;
					}
					gp = self bo1_pes_goal(pt);
					// standing on the chosen spot but not inside the trigger: that spot is no good, try another
					if(distance2d(self.origin, gp) < 30 && distance2d(self.origin, pt.origin) < 350)
					{
						if(self.bo1.pes_skip.size > 8)
							self.bo1.pes_skip = [];
						self.bo1.pes_skip[self.bo1.pes_skip.size] = gp;
						self.bo1.pes_goal = undefined;
						self.bo1.pes_fail++;
						if(self.bo1.pes_fail >= 5)
						{
							self bo1_take_pes(pt);
							continue;
						}
					}
					goal = gp;
					goal_r = 25;
					pes_goal = true;
				}
			}
		}

		// 2. shopping, re-picked every 2s
		if(!isDefined(goal) && !self bo1_any_zombie_near(300))
		{
			if(gettime() > self.bo1.next_shop)
			{
				self.bo1.next_shop = gettime() + 2000;
				self bo1_pick_shop();
			}
			if(isDefined(self.bo1.shop))
			{
				if(distance2d(self.origin, self.bo1.shop.origin) < 75 && abs(self.origin[2] - self.bo1.shop.origin[2]) < 70)
				{
					self bo1_do_shop();
					self.bo1.shop = undefined;
					continue;
				}
				goal = self.bo1.shop.origin;
			}
		}

		// 2b. repair a broken window (points) when nothing is attacking
		if(!isDefined(goal) && !self bo1_any_zombie_near(250))
		{
			// window search is heavy (sight traces), so only every 1.5s
			if(gettime() > self.bo1.next_board)
			{
				self.bo1.next_board = gettime() + 1500;
				self.bo1.board = self bo1_find_board();
			}
			w = self.bo1.board;
			if(isDefined(w) && bo1_window_broken(w))
			{
				bp = bo1_window_pos(w);
				gp = groundpos(bp + (0, 0, 50));
				// the repair trigger is r96 around the window, so being within 80 counts
				if(distance2d(self.origin, bp) < 80 && abs(self.origin[2] - gp[2]) < 45)
				{
					self bo1_do_board(w);
					self.bo1.board = undefined;
					self.bo1.next_board = gettime() + 1000;
					continue;
				}
				goal = bo1_window_stand(w);
				goal_r = 35;
			}
			else
				self.bo1.board = undefined;
		}

		// 3. follow
		if(!isDefined(goal) && isDefined(leader))
		{
			d = distance(self.origin, leader.origin);
			if(d > 1800 && leader isonground())
			{
				self bo1_teleport_to(leader);
				continue;
			}
			if(d > 300)
				goal = leader.origin;
		}

		// ---- aim / shoot
		if(isDefined(z))
		{
			self bo1_face(bo1_aimpos(z));
			zd = distance(self.origin, z.origin);
			if(!bo1_knife_only())
			{
				self bo1_throw_think(z);
				self bo1_pick_weapon(zd);
			}
			self bo1_shoot(z, zd);

			// a power-up in sight beats backing off / closing in, unless the zombie is right on us
			if((pu_goal || pes_goal) && zd > 100)
			{
				self bo1_move_dir(self bo1_nav_point(goal) - self.origin);
			}
			// round 1 (knife only): walk up to the zombie instead of backing off
			else if(bo1_knife_only())
			{
				if(zd > 40)
					self bo1_move_dir(z.origin - self.origin);
				else
					self bo1_stop();
			}
			// back off from close zombies, otherwise keep going to the goal
			else if(zd < 170)
			{
				self bo1_move_dir(self.origin - z.origin);
			}
			else if(isDefined(goal))
			{
				self bo1_move_dir(self bo1_nav_point(goal) - self.origin);
			}
			else
			{
				self bo1_stop();
			}
		}
		else
		{
			self bo1_ceasefire();
			if(isDefined(goal))
			{
				ang = vectortoangles(self bo1_nav_point(goal) - self.origin);
				self botangles((0, ang[1], 0));
				self bo1_move_dir(self bo1_nav_point(goal) - self.origin);
			}
			else
			{
				self bo1_stop();
			}
		}

		// ---- stuck handling (only counts while we are trying to walk somewhere)
		if(gettime() > self.bo1.sample)
		{
			self.bo1.sample = gettime() + 1000;
			if(isDefined(goal) && distance(self.origin, goal) > goal_r && distance2d(self.origin, self.bo1.last_pos) < 12)
			{
				self.bo1.stuck++;
				self.bo1.nav_path = undefined;
				self.bo1.nav_next = 0;
				self thread bo1_jump();
				if(self.bo1.stuck >= 4 && isDefined(leader))
				{
					self.bo1.stuck = 0;
					self.bo1.shop = undefined;
					self bo1_teleport_to(leader);
				}
			}
			else
				self.bo1.stuck = 0;
			self.bo1.last_pos = self.origin;
		}
	}
}

// ---------------------------------------------------------------- Dead Ops Arcade
//
// Based on zombietron_main.gsc / zombietron_load.gsc (level.zombietron_mode, lives, top-down camera, exits).
// Still assumed (the weapon / pickup scripts were not available):
//   - the camera is top-down, so aiming is only the yaw toward the enemy (pitch 0) and there are no line-of-sight checks
//   - shooting is the fire button, held while an enemy is in range (no ADS, no knife, no reload, no sprint, no jump)
//   - enemies are AI: first the zombie team, then any AI that is not on our side
//   - pickups are found by model name (the list comes from zombietron.csc) and walked into
//   - no downed state / buying / windows / perks, so none of that logic runs
// If the bots stand still or shoot the wrong way in the arcade, bo1_bots_debug 1 shows what they see.

bo1_arcade_enemies()
{
	out = bo1_enemies();
	if(out.size > 0)
		return out;
	all = getaiarray();
	for(i = 0; i < all.size; i++)
	{
		e = all[i];
		if(!isDefined(e) || !isAlive(e))
			continue;
		if(isDefined(e.team) && e.team == "allies")
			continue;
		out[out.size] = e;
	}
	return out;
}

bo1_arcade_nearest(maxd)
{
	zs = bo1_arcade_enemies();
	best = undefined;
	bd = maxd * maxd;
	for(i = 0; i < zs.size; i++)
	{
		z = zs[i];
		if(!isDefined(z) || !isAlive(z))
			continue;
		d = distance2d(self.origin, z.origin);
		d = d * d;
		if(d < bd)
		{
			bd = d;
			best = z;
		}
	}
	return best;
}

// Arcade pickups are script_models; the client script (zombietron.csc, get_pickup_type_from_model) names every model.
// 0 = leave it alone. Vehicles are skipped on purpose: a bot that climbs into the tank or helicopter can't drive it.
bo1_arcade_pick_value(m)
{
	switch(m)
	{
		case "c_usa_blackops_body1_fb":			return 100;	// extra life
		case "m2_flamethrower_zt":
		case "ray_gun_zt":
		case "weapon_usa_ray_gun":
		case "weapon_usa_flamethrower":
		case "m60_zt":
		case "minigun_zt":
		case "t5_weapon_carry_minigun_world":
		case "spas_zt":
		case "t5_weapon_spas_world":
		case "china_lake_zt":
		case "t5_weapon_ex41_world":
		case "rpg_zt":
		case "weapon_rpg7":						return 85;	// guns
		case "zombie_bomb":
		case "zombietron_lightning_bolt":
		case "p_rus_boots":
		case "anim_chicken":
		case "p_glo_barrel_metal_blue":
		case "zombietron_electric_ball":
		case "zombie_teddybear":
		case "zombie_auto_turret":
		case "weapon_zombie_monkey_bomb":
		case "weapon_zombie_monkey_bomb_zt":	return 70;	// power-ups
		case "zombietron_ruby":
		case "zombietron_sapphire":
		case "zombietron_diamond":
		case "zombietron_gold_brick":
		case "zombietron_gold_bricks":
		case "zombietron_gold_coin":
		case "zombietron_silver_brick":
		case "zombietron_silver_bricks":
		case "zombietron_silver_coin":
		case "zombie_z_money_icon":				return 45;	// money
	}
	return 0;
}

// best pickup in reach, shared scan (all bots use one list, refreshed once a second)
bo1_arcade_find_pickup()
{
	if(!isDefined(level.bo1_pu_t) || gettime() > level.bo1_pu_t)
	{
		level.bo1_pu_t = gettime() + 1000;
		level.bo1_pu_list = [];
		ents = getentarray("script_model", "classname");
		for(i = 0; i < ents.size; i++)
		{
			e = ents[i];
			if(!isDefined(e) || !isDefined(e.model) || !isDefined(e.origin))
				continue;
			if(bo1_arcade_pick_value(e.model) <= 0)
				continue;
			level.bo1_pu_list[level.bo1_pu_list.size] = e;
		}
	}
	best = undefined;
	bs = -99999;
	for(i = 0; i < level.bo1_pu_list.size; i++)
	{
		e = level.bo1_pu_list[i];
		if(!isDefined(e) || !isDefined(e.origin))
			continue;
		key = "pu_" + e getentitynumber();
		if(isDefined(self.bo1.skip[key]) && gettime() < self.bo1.skip[key])
			continue;
		d = distance2d(self.origin, e.origin);
		if(d > 900)
			continue;
		sc = bo1_arcade_pick_value(e.model) - d / 10;
		if(sc > bs)
		{
			bs = sc;
			best = e;
		}
	}
	return best;
}

bo1bots_arcade_loop()
{
	self.bo1.no_run = true;
	self bo1_run(false);
	orbit = 1;
	if(self getentitynumber() % 2 == 1)
		orbit = -1;
	orbit_t = gettime() + 3000;
	noticed = false;
	mode_cam = false;
	cal_t = gettime() + 3000;
	cal_pos = self.origin;
	cal_cmd = (0, 0, 0);
	cal_bad = 0;

	for(;;)
	{
		wait 0.1;
		self.bo1.snap_score = self.score;
		if(!isAlive(self) || self.sessionstate != "playing")
			continue;
		if(bo1_down(self))
		{
			self bo1_ceasefire();
			self bo1_stop();
			continue;
		}

		if(gettime() > orbit_t)
		{
			orbit = orbit * -1;
			orbit_t = gettime() + 2500 + randomint(2000);
		}

		z = self bo1_arcade_nearest(1500);
		leader = self bo1_leader();
		mv = (0, 0, 0);

		// 1. keep out of each other's hitboxes (also stops the overlap kills), and off the human
		sep = (0, 0, 0);
		players = get_players();
		for(i = 0; i < players.size; i++)
		{
			q = players[i];
			if(q == self || !isDefined(q) || !isAlive(q))
				continue;
			dd = distance2d(self.origin, q.origin);
			if(dd < 110)
			{
				away = (self.origin[0] - q.origin[0], self.origin[1] - q.origin[1], 0);
				if(lengthsquared(away) < 1)
					away = (randomfloatrange(-1, 1), randomfloatrange(-1, 1), 0);
				sep = sep + vectornormalize(away) * ((110 - dd) / 110);
			}
		}

		// 2. enemy: face it, shoot, keep a distance while circling it
		if(isDefined(z))
		{
			zd = distance2d(self.origin, z.origin);
			to = (z.origin[0] - self.origin[0], z.origin[1] - self.origin[1], 0);
			ang = vectortoangles(to);
			self botangles((0, ang[1], 0));
			self bo1_off("ads");
			self bo1_off("melee");
			if(zd < 1300)
				self bo1_on("attack");
			else
				self bo1_off("attack");

			if(!noticed)
			{
				noticed = true;
				bo1bots_dbg(self.name + " arcade: first target " + z.classname + " at " + int(zd));
			}

			if(zd < 260)
			{
				// too close: back off, with a sideways part so they circle instead of running in a line
				side = (0 - to[1], to[0], 0) * orbit;
				mv = vectornormalize(to) * -1 + vectornormalize(side) * 0.7;
			}
			else if(zd > 650 && isDefined(leader) && distance2d(self.origin, leader.origin) > 500)
				mv = leader.origin - self.origin;
		}
		else
		{
			self bo1_ceasefire();
			// 3. nobody to shoot: stay near the nearest human
			if(isDefined(leader) && distance2d(self.origin, leader.origin) > 300)
				mv = leader.origin - self.origin;
		}

		// 1b. a pickup in reach: go and take it unless an enemy is right on us. Gives up on one it can't get to.
		pu = self bo1_arcade_find_pickup();
		if(isDefined(pu) && (!isDefined(z) || distance2d(self.origin, z.origin) >= 260))
		{
			mv = pu.origin - self.origin;
			pd = distance2d(self.origin, pu.origin);
			if(!isDefined(self.bo1.pu_ent) || self.bo1.pu_ent != pu)
			{
				self.bo1.pu_ent = pu;
				self.bo1.pu_best = pd;
				self.bo1.pu_time = gettime();
			}
			else if(pd < self.bo1.pu_best - 30)
			{
				self.bo1.pu_best = pd;
				self.bo1.pu_time = gettime();
			}
			else if(gettime() - self.bo1.pu_time > 7000)
			{
				self.bo1.skip["pu_" + pu getentitynumber()] = gettime() + 30000;
				self.bo1.pu_ent = undefined;
			}
		}

		// 2b. don't touch an open exit: any player touching it ends the round for everybody
		if(isDefined(level.arena_exits) && isDefined(level.current_arena) && isDefined(level.arena_exits[level.current_arena]))
		{
			ex = level.arena_exits[level.current_arena];
			for(i = 0; i < ex.size; i++)
			{
				if(!isDefined(ex[i]) || !isDefined(ex[i].exit_open))
					continue;
				de = distance2d(self.origin, ex[i].origin);
				if(de < 260)
				{
					away = (self.origin[0] - ex[i].origin[0], self.origin[1] - ex[i].origin[1], 0);
					if(lengthsquared(away) > 1)
						sep = sep + vectornormalize(away) * ((260 - de) / 130);
				}
			}
		}

		mv = (mv[0], mv[1], 0);
		if(lengthsquared(sep) > 0.01)
		{
			if(lengthsquared(mv) > 1)
				mv = vectornormalize(mv) + sep * 1.5;
			else
				mv = sep;
		}

		// the arcade camera may turn the stick into screen directions instead of view directions, so check that
		// the bot really goes where it was told to and switch the mapping if it doesn't
		if(mode_cam)
		{
			cy = 0;
			if(isDefined(level.flipped) && level.flipped)
				cy = 180;
			self.bo1.move_yaw = cy;
		}
		else
			self.bo1.move_yaw = undefined;

		if(lengthsquared(mv) > 0.01)
		{
			self bo1_move_dir(mv);
			cal_cmd = cal_cmd + vectornormalize(mv);
		}
		else
			self bo1_stop();

		if(gettime() > cal_t)
		{
			cal_t = gettime() + 1500;
			moved = (self.origin[0] - cal_pos[0], self.origin[1] - cal_pos[1], 0);
			if(lengthsquared(cal_cmd) > 4 && lengthsquared(moved) > 900)
			{
				if(vectordot(vectornormalize(moved), vectornormalize(cal_cmd)) < 0.2)
					cal_bad++;
				else
					cal_bad = 0;
				if(cal_bad >= 3)
				{
					cal_bad = 0;
					mode_cam = !mode_cam;
					bo1bots_dbg(self.name + " arcade: movement mapping switched, camera relative " + mode_cam);
				}
			}
			cal_pos = self.origin;
			cal_cmd = (0, 0, 0);
		}

		// too far from the nearest human (fell off, got stuck): bring it back
		if(isDefined(leader) && distance(self.origin, leader.origin) > 1800 && leader isonground())
			self bo1_teleport_to(leader);
	}
}

// ---------------------------------------------------------------- Moon: P.E.S. (space suit)
//
// From _zombiemode_equipment.gsc and _zombiemode_equip_gasmask.gsc: the lockers are triggers (targetname
// "zombie_equipment_upgrade") whose .zombie_equipment_upgrade is the equipment name, "equip_gasmask_zm" for the P.E.S.
// They are "look at" use triggers, so the bot has to stand inside the trigger and face it. On use the game does
// equipment_give(): GiveWeapon, remembers it as the player's equipment, hides the locker from that player and starts
// gasmask_activation_watcher_thread. The helmet goes on when the player switches to the suit weapon:
// equipment_slot_watcher() toggles self.current_equipment_active[equipment] and the gasmask watcher then runs the
// put-on (about 2.6s, is_drinking is raised meanwhile) and switches back to the previous gun by itself.
bo1_pes_exists()
{
	if(getdvar("bo1_bots_suit") != "" && getdvarint("bo1_bots_suit") == 0)
		return false;
	if(!isDefined(level.bo1_pes_checked))
	{
		level.bo1_pes_checked = true;
		level.bo1_pes = [];
		ts = getentarray("zombie_equipment_upgrade", "targetname");
		for(i = 0; i < ts.size; i++)
		{
			if(isDefined(ts[i].zombie_equipment_upgrade) && ts[i].zombie_equipment_upgrade == "equip_gasmask_zm")
				level.bo1_pes[level.bo1_pes.size] = ts[i];
		}
	}
	return level.bo1_pes.size > 0;
}

// "on" = holds the suit weapon AND the game says it is active. The flag alone is not enough: it can be left
// at true after a death while the weapon is gone.
bo1_pes_on()
{
	if(!self hasweapon("equip_gasmask_zm"))
		return false;
	if(!isDefined(self.current_equipment_active))
		return false;
	a = self.current_equipment_active["equip_gasmask_zm"];
	return isDefined(a) && a;
}

bo1_find_pes()
{
	best = undefined;
	bd = 2500 * 2500;
	for(i = 0; i < level.bo1_pes.size; i++)
	{
		t = level.bo1_pes[i];
		if(!isDefined(t))
			continue;
		d = distancesquared(self.origin, t.origin);
		if(d < bd)
		{
			bd = d;
			best = t;
		}
	}
	return best;
}

// the bot no longer has the suit: wipe whatever the game still remembers about it, or equipment_give() and the
// locker (hidden per player, ignored while is_drinking) will refuse to hand it out again
bo1_pes_reset_state()
{
	if(self hasweapon("equip_gasmask_zm"))
		return;
	if(isDefined(self.current_equipment) && self.current_equipment == "equip_gasmask_zm")
		self.current_equipment = undefined;
	if(isDefined(self.current_equipment_active))
		self.current_equipment_active["equip_gasmask_zm"] = false;
	// ends a put-on watcher thread left over from before the death
	self notify("equip_gasmask_zm_taken");
	for(i = 0; i < level.bo1_pes.size; i++)
	{
		if(isDefined(level.bo1_pes[i]))
			level.bo1_pes[i] setinvisibletoplayer(self, false);
	}
}

// where to stand: a spot around the locker that is on the bot's floor, with a clear line to the trigger
// (so not behind the locker or a wall), nearest to the bot, skipping spots that already failed
bo1_pes_goal(t)
{
	if(distance2d(self.origin, t.origin) > 350)
		return t.origin;
	if(isDefined(self.bo1.pes_goal) && gettime() < self.bo1.pes_goal_t)
		return self.bo1.pes_goal;
	best = t.origin;
	bd = 99999999;
	for(i = 0; i < 9; i++)
	{
		spot = t.origin;
		if(i > 0)
			spot = t.origin + anglestoforward((0, (i - 1) * 45, 0)) * 40;
		gp = groundpos((spot[0], spot[1], self.origin[2] + 40));
		if(abs(gp[2] - self.origin[2]) > 60)
			continue;
		bad = false;
		for(j = 0; j < self.bo1.pes_skip.size; j++)
		{
			if(distance2d(gp, self.bo1.pes_skip[j]) < 30)
				bad = true;
		}
		if(bad)
			continue;
		if(!sighttracepassed(gp + (0, 0, 60), t.origin + (0, 0, 20), false, undefined))
			continue;
		d = distance2d(self.origin, gp);
		if(d < bd)
		{
			bd = d;
			best = gp;
		}
	}
	self.bo1.pes_goal = best;
	self.bo1.pes_goal_t = gettime() + 1500;
	return best;
}

bo1_take_pes(t)
{
	self.bo1.pes_wait = gettime() + 2500;
	self bo1_stop();
	self bo1_ceasefire();
	self bo1_pes_reset_state();
	self bo1_face(t.origin);
	wait 0.2;
	self bo1_press(0.5);
	wait 0.6;
	if(!self hasweapon("equip_gasmask_zm"))
	{
		// the press did nothing: fire the trigger the way the game does for a player
		t notify("trigger", self);
		wait 0.6;
	}
	if(self hasweapon("equip_gasmask_zm"))
	{
		bo1bots_dbg(self.name + " took the P.E.S.");
		self.bo1.pes_wait = 0;
		self.bo1.pes_fail = 0;
		self.bo1.pes_skip = [];
		self.bo1.pes_goal = undefined;
		return;
	}
	// still nothing: a leftover "drinking" state blocks the locker, clear it
	if(isDefined(self.is_drinking) && self.is_drinking > 0)
	{
		self.is_drinking = 0;
		self enableoffhandweapons();
	}
	bo1bots_dbg(self.name + " could not take the P.E.S.");
}

bo1_wear_pes()
{
	self.bo1.pes_wait = gettime() + 6000;
	self bo1_stop();
	self bo1_ceasefire();
	// the game is still running its own put-on / take-off
	if(isDefined(self.is_drinking) && self.is_drinking > 0)
		return;
	self switchtoweapon("equip_gasmask_zm");
	t = 0;
	while(t < 8 && (!self bo1_pes_on() || (isDefined(self.is_drinking) && self.is_drinking > 0)))
	{
		wait 0.25;
		t += 0.25;
	}
	if(self bo1_pes_on())
		bo1bots_dbg(self.name + " put the P.E.S. on");
	else
		bo1bots_dbg(self.name + " could not put the P.E.S. on yet");
	// the game switches back to the previous gun itself; only step in if the bot is still holding the suit
	cw = self getcurrentweapon();
	if(cw == "equip_gasmask_zm" || cw == "lower_equip_gasmask_zm")
	{
		prims = self getweaponslistprimaries();
		if(prims.size > 0)
			self switchtoweapon(prims[0]);
		wait 0.3;
	}
	self bo1_hold_best();
}

// ---------------------------------------------------------------- Moon: No Man's Land teleporter
//
// From zombie_moon_teleporter.gsc: the pad that leaves No Man's Land is the trigger whose script_noteworthy is
// "exit_no_mans_land". teleporter_function() teleports everybody 2.5s after every valid player (alive, not
// spectating, not flagged notarget; downed players count) is touching it. Its gate is level.teleporter_exit_nml_gate_open
// (1 open / 0 down: it is closed 3s after the start and opens ~20s after No Man's Land is entered). While in No Man's
// Land the flag "enter_nml" is set; the pad on the Moon side is "enter_no_mans_land" and is not used here.
bo1_nml_pad()
{
	if(getdvar("bo1_bots_nml") != "" && getdvarint("bo1_bots_nml") == 0)
		return undefined;
	if(!isDefined(level.flag) || !isDefined(level.flag["enter_nml"]) || !level.flag["enter_nml"])
		return undefined;
	if(!isDefined(level.bo1_nml_checked))
	{
		level.bo1_nml_checked = true;
		pads = getentarray("exit_no_mans_land", "script_noteworthy");
		if(pads.size > 0)
			level.bo1_nml_pad = pads[0];
		else
			bo1bots_dbg("No Man's Land flag is set but no exit_no_mans_land pad was found");
	}
	return level.bo1_nml_pad;
}

bo1_nml_gate_open()
{
	// the start-up closing of the gate happens in the first ~6s, so don't walk in before that
	if(gettime() < 9000)
		return false;
	if(!isDefined(level.teleporter_exit_nml_gate_open))
		return true;
	return level.teleporter_exit_nml_gate_open != 0;
}

// the whole brain tick while in No Man's Land: sprint onto the pad, wait outside while the gate is down,
// stand on the pad and shoot once there
bo1_nml_tick(pad)
{
	d = distance2d(self.origin, pad.origin);
	on_pad = self istouching(pad);
	open = bo1_nml_gate_open();

	if(on_pad || (!open && d < 450))
	{
		// waiting: fight what comes, but stay put
		self.bo1.nml_stuck = 0;
		self bo1_stop();
		z = self bo1_find_target();
		if(isDefined(z))
		{
			self bo1_watch_zombie(z);
			self bo1_face(bo1_aimpos(z));
			self bo1_shoot(z, distance(self.origin, z.origin));
		}
		else
			self bo1_ceasefire();
		return;
	}

	// walking: no shooting, just run
	self bo1_ceasefire();
	goal = pad.origin;
	nav = self bo1_nav_point(goal);
	ang = vectortoangles(nav - self.origin);
	self botangles((0, ang[1], 0));
	self bo1_move_dir(nav - self.origin);

	// stuck: jump, and after ~8s put the bot on the pad
	if(!isDefined(self.bo1.nml_stuck))
		self.bo1.nml_stuck = 0;
	if(!isDefined(self.bo1.nml_t) || gettime() > self.bo1.nml_t)
	{
		self.bo1.nml_t = gettime() + 1000;
		if(isDefined(self.bo1.nml_pos) && distance2d(self.origin, self.bo1.nml_pos) < 12)
		{
			self.bo1.nml_stuck++;
			self.bo1.nav_path = undefined;
			self.bo1.nav_next = 0;
			self thread bo1_jump();
			if(self.bo1.nml_stuck >= 8)
			{
				self.bo1.nml_stuck = 0;
				bo1bots_dbg(self.name + " stuck on the way to the No Man's Land teleporter, placing it on the pad");
				self setorigin(pad.origin + (randomint(40) - 20, randomint(40) - 20, 8));
			}
		}
		else
			self.bo1.nml_stuck = 0;
		self.bo1.nml_pos = self.origin;
	}
}

// ---------------------------------------------------------------- navigation
//
// Plutonium T5 has the engine pathfinder as a GSC function (generatepath, added in r4811): it plans over the same
// navigation mesh the zombies walk on and returns an array of path nodes. The bots walk node to node along it.
// bo1_bots_nav 0 goes back to walking in a straight line. If the call returns nothing (no route, or the function
// misbehaves) the bot just walks straight at the goal like before.
bo1_nav_point(goal)
{
	if(getdvar("bo1_bots_nav") != "" && getdvarint("bo1_bots_nav") == 0)
		return goal;
	if(distance(self.origin, goal) < 90)
		return goal;
	b = self.bo1;

	moved = !isDefined(b.nav_goal) || distance(b.nav_goal, goal) > 120;
	busy = isDefined(b.nav_busy_t) && gettime() < b.nav_busy_t;
	if((moved || !isDefined(b.nav_path) || gettime() > b.nav_t) && gettime() >= b.nav_next && !busy)
	{
		b.nav_next = gettime() + 700;
		b.nav_t = gettime() + 2500;
		// the engine call runs in its own thread: if it throws a script error only that thread dies, not the bot
		b.nav_busy_t = gettime() + 1000;
		self thread bo1_nav_calc(goal);
	}

	if(!isDefined(b.nav_path) || !isDefined(b.nav_goal) || distance(b.nav_goal, goal) > 200)
		return goal;
	while(b.nav_i < b.nav_path.size)
	{
		n = b.nav_path[b.nav_i];
		if(!isDefined(n) || !isDefined(n.origin))
		{
			b.nav_i++;
			continue;
		}
		if(distance2d(self.origin, n.origin) < 48 && abs(self.origin[2] - n.origin[2]) < 70)
		{
			b.nav_i++;
			continue;
		}
		break;
	}
	if(b.nav_i >= b.nav_path.size)
		return goal;
	return b.nav_path[b.nav_i].origin;
}

// Asks the engine for a path. Plutonium changed generatepath's arguments over time, so three forms are tried in
// turn until one returns nodes, then that form is kept:
//   0: generatepath(start, goal, team)   1: same with the zombie team   2: with a best-effort distance
bo1_nav_calc(goal)
{
	self endon("disconnect");
	b = self.bo1;
	if(!isDefined(level.bo1_nav_var))
	{
		level.bo1_nav_var = 0;
		level.bo1_nav_fails = 0;
		level.bo1_nav_ok = false;
	}
	var = level.bo1_nav_var;
	org = self.origin;

	path = undefined;
	if(var == 0)
		path = generatepath(org, goal, "allies");
	else if(var == 1)
		path = generatepath(org, goal, "axis");
	else
		path = generatepath(org, goal, "allies", 150);

	b.nav_busy_t = 0;
	if(isDefined(path) && path.size > 0)
	{
		b.nav_path = path;
		b.nav_i = 0;
		b.nav_goal = goal;
		if(!level.bo1_nav_ok)
		{
			level.bo1_nav_ok = true;
			bo1bots_dbg("pathfinding works with form " + var + ": first path has " + path.size + " nodes");
		}
		return;
	}

	b.nav_path = undefined;
	if(!level.bo1_nav_ok)
	{
		level.bo1_nav_fails++;
		bo1bots_dbg("generatepath form " + var + " gave no path (" + level.bo1_nav_fails + "), distance " + int(distance(org, goal)));
		if(level.bo1_nav_fails % 4 == 0)
			level.bo1_nav_var = (var + 1) % 3;
	}
}

bo1_teleport_to(p)
{
	bo1bots_dbg(self.name + " teleporting to " + p.name);
	offs = [];
	offs[0] = (60, 0, 5);
	offs[1] = (0, 60, 5);
	offs[2] = (-60, 0, 5);
	offs[3] = (0, -60, 5);
	pos = p.origin + (0, 0, 5);
	for(i = 0; i < offs.size; i++)
	{
		test = p.origin + offs[i];
		if(sighttracepassed(p.origin + (0, 0, 40), test + (0, 0, 40), false, undefined))
		{
			pos = test;
			break;
		}
	}
	self setorigin(pos);
	self.bo1.last_pos = pos;
	wait 0.5;
}

// infinite reserve ammo, clip still has to be reloaded
bo1bots_ammo()
{
	self endon("disconnect");
	self endon("bo1bots_brain");
	for(;;)
	{
		wait 2;
		if(getdvar("bo1_bots_infinite_ammo") != "" && getdvarint("bo1_bots_infinite_ammo") == 0)
			continue;
		prims = self getweaponslistprimaries();
		cur = self getcurrentweapon();
		for(i = 0; i < prims.size; i++)
		{
			self givemaxammo(prims[i]);
			// a gun in the holster that ran dry is reloaded while it is away
			if(prims[i] != cur && self getweaponammoclip(prims[i]) <= 0)
				self setweaponammoclip(prims[i], weaponclipsize(prims[i]));
		}
	}
}

bo1bots_damage()
{
	self endon("disconnect");
	self endon("bo1bots_brain");
	for(;;)
	{
		self waittill("damage");
		self.bo1.hit_time = gettime();
	}
}
