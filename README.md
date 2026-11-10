# OctoArenaFrames

Arena frames for OctoWoW (1.12.1 client) with SuperWoW, nampower and ClassicAPI: fast cast bars,
interrupts, cooldowns taken from this game's own spell data (not retail), trinkets, racials, crowd
control, diminishing returns. The OctoKicks interrupt tracker is built in.

> Early version: tested offline, not yet seen in a real match. Bug reports welcome, with the output
> of `/oaf probe` and `/oaf errors`.

## Install

**With the OctoWoW launcher (keeps it updated):** add it from its git link,
`https://github.com/bdot89/OctoArenaFrames.git`. The launcher then shows when an update is out.

**By hand:**

1. Download **OctoArenaFrames-<version>.zip** (under Assets) from the
   [latest release](https://github.com/bdot89/OctoArenaFrames/releases/latest) and unzip it into
   `Interface\AddOns`, so you end up with `Interface\AddOns\OctoArenaFrames\OctoArenaFrames.toc`.
   (Not the green "Code" button: that zip unpacks as `OctoArenaFrames-main`, which the game ignores.)
2. Restart the game fully (a new addon folder is not picked up by `/reload`).
3. If you used OctoKicks, its settings are copied over on first login and a popup offers to switch
   it off.

## Commands

| Command | What it does |
| --- | --- |
| `/oaf` | Options window |
| `/oaf test` | Quick test: sample enemies for 60 seconds, to see and move the frames |
| `/oaf test full` | Full test until you stop it: every frame, casts, kicks with lockouts, CC + DR, cooldowns, trinkets, racials, interrupt bar (also a button in the options) |
| `/oaf lock` | Lock / unlock the frames |
| `/oaf 2v2`, `3v3`, `5v5`, `bg` | Pick a layout (`/oaf auto` to go by the zone) |
| Mouse over a frame + your interrupt | Kicks that enemy, your target stays (also `/oaf kick mouse` and a key binding; Options > Frames > Mouseover casting) |
| `/oaf target 1`, `focus 1`, `kick 1` | Act on enemy 1 (also in Key Bindings). The gold number in front of each name is that number: call it on voice ("kill 2") |
| `/oaf log` | What was learned about the enemy team in recent matches |
| `/oaf probe`, `/oaf errors` | Diagnostics for bug reports |
| `/oaf reset` | Reset settings |

## Notes

- Cooldowns come from `Data\SpellData.lua`, generated from the client's Spell.dbc by
  `tools\BuildSpellData.ps1`.
- Offline tests: `powershell -ExecutionPolicy Bypass -File tests\run.ps1` (needs the OctoBG and
  DmorphOcto test tools next to it).
- Fonts in `media\fonts` are open-licence fonts (Fira Sans, PT Sans, Roboto, Share).
