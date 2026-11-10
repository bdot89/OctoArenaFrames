# OctoArenaFrames - notes for Claude Code

Arena frames for the OctoWoW 1.12.1 client, with OctoKicks built in. Started 5 Nov 2026. NOT seen in game yet.
Platform rules as OctoBG's CLAUDE.md: Lua 5.0 (no `#`, `%`, `...` expressions, string methods), 1.12 widget API,
write Lua with Write / Edit, never a shell heredoc. Copy a for loop's counter before using it in a closure.

## What the user asked (5 Nov 2026)
"Intergrate what we have" (OctoKicks) with what can be brought from ArenaCore 0.11.6 "without it being overwhelming",
"highly accurate", "must have CDs from this game in there not retail", "needs to be fast cast interupts available
everything".

## ArenaCore
ArenaCore's licence is "All Rights Reserved" (Peralex) and it is retail-only (12.x, C_SpellDiminish, arena1-3). Its
feature list was read; no code, data or art of it is used. Do not copy from it.
Taken as ideas: frame layout, class icon showing crowd control, trinket + racial slots, cast bars, DR, target
highlight, stealth fade, immunity mark, enemy's target, test mode, profiles.
Left out: themes, achievements, queue tools, reminders, absorbs (no API), spec icons (no API: talent tree shown once a
talent spell is seen), nameplate rewrites (pfUI Octo has them), healer-CC alert, party trinkets (possible later).

## Knowing the enemy team before the gates open (5 Nov 2026, Arena.lua; NOT seen in game)
User: "tracks the enemy team as soon as you enter the arena before the arena starts ... Use anything we have".
Layers, best first (each step is logged, see below):
1. WHO: the server's arena scoreboard. Read from patch-4 `Interface\FrameXML\Turtle_ArenaUI\Turtle_ArenaUI.lua` and
   WorldStateFrame.lua: `RequestArenaScoreInfo()` = SendAddonMessage("TW_ARENA", "C2S_SCOREBOARD", "GUILD"); answer =
   CHAT_MSG_ADDON prefix TW_ARENA, `S2C_SCOREBOARD;<arg2>;<count>;Name|team|x:Name|team|x` (delimiters from patch-4
   Globals.lua: ADDON_MSG_FIELD ";", ARRAY ":", SUBFIELD "|"; arg2 is compared with the team to pick the winner). The
   row with your name gives your team, any other team's rows are enemies. The game's own score window colours names
   with this, not with the faction column, because arenas can mix factions. UNVERIFIED: that it answers before the gates.
2. CLASS, RACE: GetBattlefieldScore by name (SetBattlefieldScoreFaction(nil) first). The faction column only stands in
   for the sides with no server list after 3 s and when your whole group is on your side of it.
3. WHICH UNIT: ClassicAPI `UnitTokenFromName(name, true)`: docs (brues-code/ClassicAPI docs/API.md, Unit section): party,
   raid, then "all loaded nearby units"; returns a token or the GUID. The answer is checked against the name. Then every
   nampower event with a GUID (Arena.lua SEEN, on only while hunting; layouts from OctoBG's Tracker.lua), UNIT_CASTEVENT,
   nameplates (C_NamePlate.GetNamePlateGUIDs, else WorldFrame children GetName(1)), team targets.
4. No ClassicAPI: `A:TargetSweep`, TargetByName + back, 1 a second, 3 tries each, never in combat, db.huntTarget.
Who is an enemy with no list: UnitCanAttack, else (arena, 2 s in, whole group's GUIDs known) anyone not in your group,
overruled by the list as soon as it comes. UnitCanAttack before the gates is UNVERIFIED, which is why it is not relied on.
Evidence in the user's files: OctoBG's db.reach measured enemies at 79-146 yd in these arenas, with unitDrawDist 300 and
NP_NameplateDistance 200 in Config.wtf, so the other room should be in the client's object list. Not proven before gates.
Names: arena names can carry a realm (e.g. "Duskfang-NZ"), so `A.Key` (lower case, no suffix) is the
lookup key everywhere and auto-filled names are never re-cased.
THE LOG: `OctoArenaGlobal.arenaLog` (last 8 matches, /oaf log, WTF\Account\<acc>\SavedVariables\OctoArenaFrames.lua after
a logout or /reload): seconds after entering + "server" (raw answer), "named", "id" (and from which source), "seen" (first
sight with can attack / enemy), "complete". After the first real match READ THIS: it settles every UNVERIFIED above.

## Facts from this install (checked, not guessed)
- CustomData\Chronicle_Upsilon.txt: 92 arena matches. Zones "Blood Ring", "Lordaeron Arena", "Sunstrider Court".
  ZONE_INFO says instance type `pvp` in them, NEVER `arena`: OctoKicks' zone == "arena" could never fire, and its bgAuto
  switched it to BG / World inside arenas. `A.ZoneKind` goes by zone name + "pvp".
- On the way in: "Orgrimmar ... pvp" for half a second, then the arena name. After a match: arena name + "none". So the
  zone is asked again after 0.6 s and every 1.5 s (3 times), and on ZONE_CHANGED_NEW_AREA.
- The header GUID changes in matches (0x...0512 outside, 0x...F8A412F8 inside): `myGuid` is refreshed on each check,
  enemy GUIDs are never kept between matches.
- Chronicle does not log combat inside arenas, so nothing below could be replayed from an arena; aura lengths are from
  player debuffs anywhere (DEBUFF_ADD / DEBUFF_REM pairs): Polymorph R4 longest 15.0 s of 38 (table 50), Freezing Trap
  R3 16.2 (table 20), Fear R3 12.3 (table 20). Hence `PVP_CAP = 15` in Auras.lua.
- Spell.dbc columns in tools\BuildSpellData.ps1 checked against known spells. patch-O is the server's file; patch-Z
  (the user's ported models) repeats it plus custom rows.
- Differences from classic that the table fixed: Spell Lock 30 s (OctoKicks had 24), Concussion Blow 20 s (had 45), Will
  of the Forsaken and War Stomp 150 s, Escape Artist 90, Shadowmeld 60, Hand of Freedom 24, Preparation 420, Blind 300,
  Frost Nova 25, plus this server's own spells (Deadly Throw, Cyclone, Bloodlust, Aspect of the Turtle, Readiness...).
- Kick, Counterspell, Pummel, Shield Bash, Spell Lock, Deadly Throw are all category 88: within a class they share a
  cooldown. All shocks category 19, traps 411, Recklessness / Retaliation / Shield Wall 132.
- PvP trinket 52317 "Insignia": no cooldown in the spell row (it is on the item); 180 s is what OctoBG's harvested data
  has from nampower. Potions 120 s likewise.
- Attribute 0x02000000 = cooldown starts when the aura ends (Nature's Swiftness has it).
- 1.12 cooldown sweep: a model drawn for a 36 px button; `SetScale(width / 36)` is required (pfUI's cooldown.lua does it).
  OctoKicks never did. pfUI's own realign skips frames with `noCooldownCount`, so `I.FitSweep` does it here.
- TW_CLASS_TOKEN is a client global (WorldStateFrame.lua, patch-4). GetBattlefieldScore returns name, killingBlows,
  honorableKills, deaths, honorGained, faction, rank, race, class.
- Class icons: Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes (interface.MPQ). Interface\WorldStateFrame\
  Icons-Classes does not exist on this client.

## Layout
- Data\SpellData.lua GENERATED by tools\BuildSpellData.ps1 -Dbc <dir> (extract with OctoBG\tools\MpqRead.ps1; see the
  script's head). The curated list in the script says which spells show and how. A.SPELLS (t: 1 always, 2 when used,
  0 off; g / gcd category; lock lockout; wa starts when aura ends; tal, tab, pet, min shortest with talents), A.IDS,
  A.RANKCD, A.AURAS, A.CASTS.
- Core.lua settings, helpers, zone logic, event bus (pcall'd, A.errors, /oaf errors), the one OnUpdate, profiles, slash.
- Roster.lua slots (never swap in a match), Consider(guid), token scan (stops when complete), test.
- Arena.lua the server's team list, scoreboard, name to GUID, hunting events, target sweep, the match log.
- Cooldowns.lua Use, shared categories, resets, learning, BG units, Tick, test script.
- Casts.lua UNIT_CASTEVENT, combat log fallback, Kicked (lockout), RefineCast (ClassicAPI), your interrupts.
- Auras.lua Read (health, states), ScanAuras, DR, PickAuras (big icon, strip), nampower aura events.
- Actions.lua target, focus, kick, cast (Bindings.xml, /oaf target 1, clicks).
- Icons.lua the painter (caches everything). Frames.lua the frames; F.Metrics is shared with the overlap tests.
- Bars.lua BG / World rows + interrupt bar. Options.lua window. Import.lua takes over from OctoKicks.
- Test modes: quick (`A:SetTest(true)`, 60 s) and full (`A:SetTest(true, true)`, sidebar "Full test" button,
  `/oaf test full`): no timer, all A.MAX slots when the format is auto, `A:TestExtra` adds kicks (lockout),
  trinkets, racials. Both stop on any zone change.

## Fixed from in-game reports (9 Nov 2026)
- "Unknown" names: UnitName / cast events say "Unknown" (UNKNOWNOBJECT) for players not loaded yet. `A.RealName`
  refuses it wherever a name comes in (1.0.1).
- Position reset after every arena: StartMoving marks the anchor "user placed" and the client keeps its own copy in
  layout-cache.txt (written at logout), which it put back after loading screens. Place / SavePos call
  SetUserPlaced(false), and PLAYER_ENTERING_WORLD + 0.6 s later re-Place (1.0.2).
- Buffs above the frame (1.0.2): `e.buffList` from ScanAuras (all UnitBuff, kinds immune / defense / offense /
  mobility first with a coloured edge), `F:PaintBuffs`; Metrics `m.top` = row height, inside `m.pitch`. No timers
  (1.12 sends none for other players). Cleared when out of sight.

## 1.0.3 (10 Nov 2026, NOT seen in game)
- Teammates never in enemy frames: RebuildFriends also keeps `friendNames` (party / raid roster names, known
  before a late joiner loads); `A:IsFriend(name, guid)` (GUID, names, server team list, UnitInParty / UnitInRaid
  with the GUID, pcall'd) guards Consider, ConsiderToken and AutoFill; `A:DropFriends` empties auto slots that
  hold a teammate on every roster rebuild (PARTY_MEMBERS_CHANGED, scans). Named slots are left (duel practice).
- Match size: `db.arenaDetect` (default on) makes Format() "auto" in arenas whatever was picked; Max() = server
  list size, else `A.Bracket(group size)` (4 -> 5).
- Mouseover casting (`db.mouseCast` kicks | all | off): frame OnEnter -> A:HoverEnter (SuperWoW SetMouseoverUnit
  with the GUID, f.label / f.id for pfUI's /pfcast); `A:HookMouseCast` at PLAYER_ENTERING_WORLD wraps
  UseAction (spell name from a scanning tooltip, cached by slot + texture; macros skipped), CastSpellByName (no
  unit given) and CastSpell (spell book) -> A:MouseCast -> CastAtEnemy (GUID cast, target kept; plain client:
  target swap and back). Only while MouseIsOver the frame. Binding OCTOARENA_KICKMOUSE, /oaf kick mouse.
  Unverified: SetMouseoverUnit's no-argument clear, UseAction / CastSpell wrapping alongside pfUI's bars.

## Publishing (9 Nov 2026)
Public repo github.com/bdot89/OctoArenaFrames (main). The OctoWoW launcher updates addons whose folder is a git
clone: isomorphic-git reads the first remote, fetches, and compares HEAD with origin/<branch>; uncommitted
changes show as "out of date". Release zip: `git archive --prefix=OctoArenaFrames/` (.gitattributes leaves out
tests/, tools/, CLAUDE.md); bump the toc Version first. Test and sample names must be made up, never real players.

## Speed
One OnUpdate. Cast bars every frame, only for enemies casting. Health 20 Hz, numbers 10 Hz, auras 5 Hz plus at once on
nampower events, enemy's target / range / scan 4 Hz. Layout only when `A.dirty`. Scan stops once the roster is complete.

## Before handing over
`powershell -ExecutionPolicy Bypass -File tests\run.ps1` (OctoBG's mock on DmorphOcto's LuaHost) and
`..\OctoBG\tools\LuaCheck.ps1 -Files @(<full paths>) -Globals`.

## Not verified in game
Everything visual, and: the TW_ARENA answer before the gates; `<guid>target` and `<guid>owner` tokens;
UNIT_CASTEVENT's duration arg in arenas; IsActiveBattlefieldArena; aura ids from UnitBuff / UnitDebuff with
SuperWoW on enemies; DR groups and the 15 s window on this server (groups follow the mechanics, as vMangos does); the 15 s
cap on all crowd control (measured on few spells); ClassicAPI FocusUnit with a GUID; BUFF / DEBUFF_*_OTHER firing for
enemies; SetDesaturated; Middle-click on a Button; trinket 180 s.
Ask for `/oaf probe` and `/oaf errors` first with any report.
