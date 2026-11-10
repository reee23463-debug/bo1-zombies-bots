# BO1 Zombies Bots (Plutonium T5)

Adds AI bot teammates to Call of Duty: Black Ops 1 Zombies on Plutonium. Single script, no other files needed.

Bots buy perks (they start with Juggernog), wall weapons, the mystery box and Pack-a-Punch, open doors, repair windows, revive downed players, and fight zombies. Bowie and Sickle wall buys are their top buy priority.

## Requirements

* Plutonium launcher with T5 Zombies set up
* Call of Duty: Black Ops (Steam)

## Install

1. Download `zm_bo1_bots.gsc`.
2. Put it in:
   `%localappdata%\Plutonium\storage\t5\scripts\`
3. Start a Zombies game. Bots join a few seconds after the round starts.

To remove it, delete the file.

## Turn it on or off

Without deleting the file, set this in the console or your config, then restart the map:

```
set bo1_bots_enabled 0    // off
set bo1_bots_enabled 1    // on (default)
```

## Common dvars

Set in the console or config before the map starts.

|Dvar|Default|What it does|
|-|-|-|
|`bo1_bots_enabled`|1|Master switch (0 = mod does nothing)|
|`bo1_bots_count`|3|How many bots to spawn|
|`bo1_bots_default_jug`|1|Bots start with Juggernog (0 = off)|
|`bo1_bots_infinite_ammo`|1|Bots never run out of ammo|
|`bo1_bots_max_players`|4|Player cap used when working out room for bots|
|`bo1_bots_spawn_protect`|10|Seconds of invincibility after a bot spawns (0 = off)|
|`bo1_bots_run`|1|Bots sprint when walking (0 = off)|
|`bo1_bots_names`|built-in list|Comma-separated bot names|
|`bo1_bots_friend_names`|none|Comma-separated names handed out first|
|`bo1_bots_debug`|0|Show debug messages on screen|

More options (fire mode, window repair mode, buy mode, tags, Moon and Dead Ops Arcade behavior) are listed in the comments at the top of the script.

## Notes

* Bot names and clan tags come from Plutonium's `bots.txt`; a script can't set them.
* Report bugs with `bo1_bots_debug 1` on and include what you see in the console.

## Credits

Inspired by the BO2 Zombies bot mods. As far as I know, BO1 had bot mods for multiplayer but none for Zombies, so I wrote this from scratch.
