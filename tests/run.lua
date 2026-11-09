-- Offline run of OctoArenaFrames on OctoBG's mock 1.12 client (tests\mock.lua there).
--   powershell -ExecutionPolicy Bypass -File tests\run.ps1

dofile("../OctoBG/tests/mock.lua")

local fails, checks = 0, 0
local function ok(cond, what)
  checks = checks + 1
  if not cond then
    fails = fails + 1
    print("FAIL: " .. what)
  end
end
local function near(a, b, what)
  ok(a and math.abs(a - b) < 0.11, what .. " (got " .. tostring(a) .. ", wanted " .. tostring(b) .. ")")
end

-- what the mock lacks and the addon uses
function CooldownFrame_SetTimer(cd, start, dur, enable) cd.timer = { start, dur } end
function HideUIPanel(f) f:Hide() end
function setglobal(k, v) _G[k] = v end
GameMenuFrame = Mock.New("Frame", "GameMenuFrame", UIParent)
Mock.casted = {}
function CastSpellByName(spell, unit) table.insert(Mock.casted, { spell, unit }) end
function UnitIsDeadOrGhost(u)
  local e = Mock.units[u]
  return e and e.hp == 0
end

-- auras and casts, as SuperWoW answers them
local NAMES = {
  [2139] = "Counterspell", [1769] = "Kick", [1766] = "Kick", [6552] = "Pummel", [1672] = "Shield Bash", [19647] = "Spell Lock",
  [10473] = "Frost Shock", [10414] = "Earth Shock", [12472] = "Cold Snap", [10230] = "Frost Nova", [1953] = "Blink",
  [14185] = "Preparation", [2094] = "Blind", [1857] = "Vanish", [23989] = "Readiness", [19263] = "Deterrence", [14311] = "Freezing Trap",
  [10225] = "Fire Ward", [12826] = "Polymorph", [10947] = "Mind Blast", [25235] = "Flash Heal", [52317] = "Insignia", [7744] = "Will of the Forsaken",
  [12051] = "Evocation", [1787] = "Stealth", [12043] = "Presence of Mind",
}
function SpellInfo(id)
  return NAMES[id] or ("Spell" .. tostring(id)), "", "Interface\\Icons\\Spell" .. tostring(id)
end
function UnitDebuff(u, i)
  local e = Mock.units[u]
  local a = e and e.debuffs and e.debuffs[i]
  if a then return a.tex or "Interface\\Icons\\X", 1, nil, a.id end
  return nil
end
function UnitBuff(u, i)
  local e = Mock.units[u]
  local a = e and e.buffs and e.buffs[i]
  if a then return a.tex or "Interface\\Icons\\X", 1, a.id end
  return nil
end

-- like the client: SetText on a FontString with no font yet raises "Font not set"
local realCreateFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
  local f = realCreateFrame(kind, name, parent, template)
  local mt = getmetatable(f)
  f.CreateFontString = function(self, n, layer)
    local fs = mt.__index(self, "CreateFontString")(self, n, layer)
    local setText = mt.__index(fs, "SetText")
    fs.SetText = function(s, t)
      if not s.font then error("SetText(): Font not set", 2) end
      return setText(s, t)
    end
    return fs
  end
  return f
end

Mock.Load(".", "OctoArenaFrames.toc")
local A = OctoArenaFrames
Mock.Fire("VARIABLES_LOADED")
Mock.Fire("PLAYER_ENTERING_WORLD")
ok(A.db and A.db.mode == "auto", "defaults loaded, auto mode")
ok(A.UseSW(), "SuperWoW detected")
ok(not A.events.events["CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE"], "combat log off while SuperWoW is used")
ok(GameMenuFrame.children[1] ~= nil, "Esc menu button")
ok(BINDING_NAME_OCTOARENA_KICK3 == "Interrupt enemy 3", "key binding names")

-- ---------------------------------------------------------------- the game's own numbers
local function S(n) return A.BYNAME[n] end
ok(S("Spell Lock").cd == 30, "Spell Lock 30 s here (OctoKicks said 24)")
ok(S("Concussion Blow").cd == 20, "Concussion Blow 20 s here (OctoKicks said 45)")
ok(S("Counterspell").cd == 30 and S("Counterspell").lock == 10, "Counterspell 30 s, locks 10 s")
ok(S("Kick").lock == 5 and S("Pummel").lock == 4 and S("Shield Bash").lock == 6 and S("Earth Shock").lock == 2, "lockouts from the table")
ok(S("Will of the Forsaken").cd == 150 and S("War Stomp").cd == 150 and S("Escape Artist").cd == 90, "racials are this server's")
ok(S("Insignia").cd == 180 and S("Insignia").i == "INV_Jewelry_TrinketPVP_02", "PvP trinket 3 minutes, its own picture")
ok(A.AURAS[52317] == nil, "the trinket leaves no aura to show")
ok(S("Blind").cd == 300 and S("Blind").min == 210, "Blind 300 s, 210 s with Elusiveness")
ok(S("Pummel").g == 88 and S("Shield Bash").g == 88, "Pummel and Shield Bash share a category")
ok(S("Presence of Mind").wa == 1, "Presence of Mind starts its cooldown when used up")
ok(A.RACIAL["Scourge"] == S("Will of the Forsaken") and A.RACIAL["Orc"] == S("Blood Fury"), "racials by race token")
for i = 1, table.getn(A.SPELLS) do
  local s = A.SPELLS[i]
  ok(s.cd and s.cd > 0, s.n .. " has a cooldown")
  ok(s.i and s.i ~= "", s.n .. " has an icon")
end
for id, name in pairs(A.IDS) do ok(A.BYNAME[name], "id " .. id .. " points at a spell") end
ok(A.AURAS[12826].k == "incap" and A.AURAS[12826].d == 50, "Polymorph: incapacitate, 50 s in the table")
ok(A.AURAS[2094].k == "disorient", "Blind: disorient")
ok(A.AURAS[3355].k == "sleep" and A.AURAS[2637].k == "sleep", "Freezing Trap and Hibernate share a group")
ok(A.AURAS[10308].k == "stun", "Hammer of Justice: stun")
ok(A.AURAS[8643].d == 0, "Kidney Shot has no fixed time")
ok(A.AURAS[11958].k == "immune", "Ice Block: immune")
ok(A.CASTS["Polymorph"] and A.CASTS["Polymorph"].t == 1500 and A.CASTS["Polymorph"].s == 6, "Polymorph cast: 1.5 s Arcane")
ok(A.CASTS["Mind Flay"] and A.CASTS["Mind Flay"].ch == 1, "Mind Flay is a channel")

-- ---------------------------------------------------------------- layout: nothing overlaps
local F = A.Frames
local function Overlap(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function CheckLayout(label)
  local db = A.db
  local m = F.Metrics(db)
  local parts = {
    { n = "icon", x = 0, y = 0, w = m.icon, h = m.H },
    { n = "bars", x = m.icon + m.gap, y = 0, w = m.barW, h = m.H },
  }
  if m.side > 0 then
    table.insert(parts, { n = "trinket", x = m.icon + m.gap + m.barW + m.gap, y = 0, w = m.side, h = m.side })
    table.insert(parts, { n = "racial", x = m.icon + m.gap + m.barW + m.gap, y = m.side + m.gap, w = m.side, h = m.side })
  end
  if db.cast then table.insert(parts, { n = "cast", x = 0, y = m.castY, w = m.W, h = m.castH }) end
  if db.cdRow then table.insert(parts, { n = "cd", x = 0, y = m.cdY, w = m.cdMax * (db.cdSize + db.cdSpacing) - db.cdSpacing, h = db.cdSize }) end
  for i = 1, table.getn(parts) do
    local p = parts[i]
    ok(p.x >= 0 and p.x + p.w <= m.W + 0.01, label .. ": " .. p.n .. " inside the frame width")
    ok(p.y + p.h <= m.total + 0.01, label .. ": " .. p.n .. " inside the frame height")
    for k = i + 1, table.getn(parts) do
      ok(not Overlap(p, parts[k]), label .. ": " .. p.n .. " clear of " .. parts[k].n)
    end
  end
  ok(m.pitch > m.total, label .. ": enemies do not touch")
  ok(db.drSize * 2 <= m.H + 2, label .. ": aura strip and DR rows fit beside the frame")
end
CheckLayout("defaults")
A.db.cdSize, A.db.cdPerRow = 32, 12
CheckLayout("big icons")
A.db.cdSize, A.db.cdPerRow = 24, 10
A.db.cast = false
CheckLayout("no cast bar")
A.db.cast = true
A.db.trinket, A.db.racial = false, false
CheckLayout("no trinket")
A.db.trinket, A.db.racial = true, true
A.db.frameH = 72
CheckLayout("tall")
A.db.frameH = 48

-- ---------------------------------------------------------------- zones (from the user's logs)
Mock.zone, Mock.instance = "Orgrimmar", nil
ok(A.ZoneKind() == "none", "town")
Mock.instance = "pvp"
ok(A.ZoneKind() == "pvp", "on the way in: still the old zone name, instance says pvp")
Mock.zone = "Lordaeron Arena"
ok(A.ZoneKind() == "arena", "arena by name although the instance says pvp")
Mock.zone = "Blood Ring"
ok(A.ZoneKind() == "arena", "Blood Ring")
Mock.zone = "Sunstrider Court"
ok(A.ZoneKind() == "arena", "Sunstrider Court")
Mock.instance = nil
ok(A.ZoneKind() == "none", "just after the match: arena name, no instance")
Mock.zone, Mock.instance = "Warsong Gulch", "pvp"
ok(A.ZoneKind() == "pvp", "battleground")
Mock.zone, Mock.instance = "Duskwood", nil

-- ---------------------------------------------------------------- into an arena
local MAGE, ROGUE, LOCK, PRIEST, WARRIOR, PET = "0x00000000000000A1", "0x00000000000000A2", "0x00000000000000A3",
  "0x00000000000000A4", "0x00000000000000A5", "0xF140000000000001"
local FRIEND = "0x00000000000000B1"
Mock.Enemy(MAGE, "Frostmage", "MAGE", 5, 5, { raceToken = "Gnome" })
Mock.Enemy(ROGUE, "Sneaky", "ROGUE", 5, 5, { raceToken = "NightElf" })
Mock.Enemy(LOCK, "Felguy", "WARLOCK", 5, 5, { raceToken = "Scourge" })
Mock.Enemy(PET, "Grubzoz", "WARRIOR", 5, 5, { npc = true })
Mock.Enemy(FRIEND, "Teammate", "PRIEST", 5, 5, { faction = "Horde" })

F:Layout(GetTime())
ok(not F.anchor:IsShown(), "no frames in the open world with nothing set")

Mock.zone, Mock.instance = "Orgrimmar", "pvp"
Mock.party = 2
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.zone = "Lordaeron Arena"
Mock.Tick(1)
ok(A.zone == "arena", "arena noticed once the zone name caught up")
ok(not A:IsBG(), "never BG / World in an arena")
ok(A:Max() == 3, "auto: as many frames as your team (3)")
Mock.Tick(0.1)
ok(F.anchor:IsShown(), "frames show in an arena")
ok(F.frames[3]:IsShown() and not F.frames[4]:IsShown(), "three frames")
ok(F.frames[1].name.text == "|cffffd1001|r  not seen yet", "empty slot: its number, not seen yet")

-- found by casting, nameplate and target; slots stay put
local function Cast(guid, target, kind, id, ms) Mock.Fire("UNIT_CASTEVENT", guid, target, kind, id, ms) end
-- a player the client has not loaded yet is "Unknown": never taken as a name (seen in game, 9 Nov)
Mock.units[MAGE].name = "Unknown"
Cast(MAGE, nil, "CAST", 1953)
Mock.Tick(1.1)
ok(not A.enemies[1].name and not A.byName["unknown"], "\"Unknown\" is not a name")
ok(A.RealName("Unknown") == nil and A.RealName("") == nil and A.RealName("Bob") == "Bob", "RealName")
Mock.units[MAGE].name = "Frostmage"
Mock.Tick(0.3)
Cast(MAGE, nil, "CAST", 1953)
ok(A.enemies[1].name == "Frostmage" and A.enemies[1].guid == MAGE, "first cast takes slot 1 once the name is known")
ok(A.enemies[1].class == "MAGE" and A.enemies[1].race == "Gnome", "class and race read")
Cast(FRIEND, nil, "CAST", 1953)
ok(not A.enemies[2].name, "a teammate is not an enemy")
Mock.Plate(ROGUE)
Mock.Tick(1.1)
ok(A.enemies[2].name == "Sneaky", "nameplate takes slot 2")
Mock.target = LOCK
Mock.Tick(0.3)
ok(A.enemies[3].name == "Felguy", "target takes slot 3")
Mock.target = nil
ok(A:RosterFull(), "roster complete")
Mock.Tick(1)
ok(A.enemies[1].guid == MAGE and A.enemies[2].guid == ROGUE and A.enemies[3].guid == LOCK, "slots never swap")
ok(F.frames[1].name.text == "|cffffd1001|r  Frostmage", "frame shows the number, then the name")

-- health, power, states
local mage, rogue, lock = A.enemies[1], A.enemies[2], A.enemies[3]
Mock.units[MAGE].hp = 42
Mock.Tick(0.1)
ok(F.frames[1].hp.value == 42, "health bar")
ok(F.frames[1].hpText.text == "42%", "health text")
Mock.units[MAGE].hp = 0
Mock.Tick(0.1)
ok(mage.dead and F.frames[1].hpText.text == "DEAD", "dead")
Mock.units[MAGE].hp = 80
Mock.Tick(0.1)
ok(not mage.dead, "not dead any more")
Mock.units[MAGE].near = false
Mock.Tick(0.1)
ok(mage.unit == nil and F.frames[1].baseAlpha == 0.55, "out of sight: faded")
Mock.units[MAGE].near = true
Mock.Tick(0.1)
ok(mage.unit == MAGE and F.frames[1].baseAlpha == 1, "back in sight")

-- ---------------------------------------------------------------- cast bars
Cast(MAGE, nil, "START", 12826, 1500)
ok(mage.cast and mage.cast.name == "Polymorph" and mage.cast.dur == 1.5, "cast starts at once, with the real time")
ok(mage.cast.school == 6, "school from the table")
Mock.Tick(0.1)
ok(F.frames[1].castF.shown, "cast bar up")
near(F.frames[1].castF.bar.value, 0.1 / 1.5, "bar fills")
Mock.Tick(0.7)
near(F.frames[1].castF.bar.value, 0.8 / 1.5, "bar keeps filling")
ok(F.frames[1].castF.text.text == "Polymorph", "spell name on the bar")
Cast(MAGE, ROGUE, "CAST", 12826)
ok(mage.cast == nil, "finished")
Mock.Tick(0.3)
ok(not F.frames[1].castF.shown, "bar gone after a moment")

-- interrupted, both orders of the two messages
local TEAM = "0x00000000000000B2"
Mock.Enemy(TEAM, "Kicker", "ROGUE", 1, 1, { faction = "Horde" })
Mock.units[TEAM].hostileNo = true
Cast(MAGE, nil, "START", 12826, 1500)
Cast(TEAM, MAGE, "CAST", 1769)
ok(mage.cast == nil and mage.lockout, "kicked: bar stops, school locked")
near(mage.lockout.stop - GetTime(), 5, "Kick locks 5 s, from the table")
ok(mage.lockout.school == 6, "the school being cast")
ok(mage.castEnd.text == "INTERRUPTED", "says interrupted")
Mock.Tick(0.1)
ok(F.frames[1].castF.text.text == "INTERRUPTED", "bar says so")
Mock.Tick(0.8)
ok(string.find(F.frames[1].castF.text.text, "LOCKED: Arcane", 1, true) ~= nil, "then a lockout bar")
Mock.Tick(4.5)
ok(mage.lockout == nil and not F.frames[1].castF.shown, "lockout ends")
Cast(MAGE, nil, "START", 12826, 1500)
Cast(MAGE, nil, "FAIL", 12826)
ok(mage.cast == nil and mage.castEnd.text == "STOPPED", "stopped casting")
Cast(TEAM, MAGE, "CAST", 2139)
ok(mage.lockout and mage.castEnd.text == "INTERRUPTED", "the kick message second counts too")
near(mage.lockout.stop - GetTime(), 10, "Counterspell locks 10 s")
mage.lockout, mage.castEnd = nil, nil
Mock.Tick(0.5)
Cast(TEAM, MAGE, "CAST", 1769)
ok(mage.lockout == nil, "a kick at someone not casting locks nothing")

-- channel empties; pushback from ClassicAPI
Cast(ROGUE, nil, "CHANNEL", 12051, 8000)
ok(rogue.cast and rogue.cast.channel, "channel")
Mock.Tick(2)
near(F.frames[2].castF.bar.value, 6 / 8, "channel empties")
Cast(ROGUE, nil, "FAIL", 12051)
Mock.Tick(1)
C_Spell = { UnitCastingInfo = function(g)
  if g ~= MAGE then return nil end
  return "Polymorph", "", "X", mage.cast.start * 1000, (mage.cast.start + 2) * 1000, nil, nil, true
end }
Cast(MAGE, nil, "START", 12826, 1500)
Mock.Tick(0.1)
near(mage.cast.dur, 2, "pushback from ClassicAPI")
ok(mage.cast.noint == true, "cannot be interrupted, from ClassicAPI")
Mock.Tick(0.1)
ok(string.find(F.frames[1].castF.text.text, "no kick", 1, true) ~= nil, "bar says no kick")
C_Spell = nil
Cast(MAGE, nil, "FAIL", 12826)
mage.lastCast = nil

-- your interrupt beside the bar
Mock.book = { { "Overpower", 0 }, { "Pummel", 10 } }
A.myKicks = nil
local name, _, left = A:MyKick(GetTime())
ok(name == "Pummel" and left == 0, "your interrupt found in the spell book")
Mock.Tick(1)
Cast(MAGE, nil, "START", 12826, 1500)
Mock.Tick(0.1)
ok(F.frames[1].castF.kick.shown, "your interrupt shows beside the cast bar")
Mock.cdStart = GetTime()
local _, _, left2 = A:MyKick(GetTime())
near(left2, 10, "on cooldown: how long")
Mock.cdStart = nil
Cast(MAGE, nil, "FAIL", 12826)
Mock.Tick(1)

-- ---------------------------------------------------------------- cooldowns
local function CdLeft(e, n) return (A.Remaining(e, n, GetTime())) end
Mock.Enemy(WARRIOR, "Bashface", "WARRIOR", 5, 5, { raceToken = "Orc" })
A:SetFormat("5v5")
Cast(WARRIOR, nil, "CAST", 6552)
local war = A.enemies[4]
ok(war.name == "Bashface", "fourth enemy in 5v5")
near(CdLeft(war, "Pummel"), 10, "Pummel 10 s")
near(CdLeft(war, "Shield Bash"), 10, "Pummel locks Shield Bash for its category time")
Mock.Tick(1)
Cast(WARRIOR, nil, "CAST", 1672)
near(CdLeft(war, "Pummel"), 12, "a Shield Bash pushes Pummel to 12 s")
ok(war.cds["Pummel"].shared == "Shield Bash", "marked as shared")

Mock.Enemy(PRIEST, "Shocky", "SHAMAN", 5, 5, { raceToken = "Tauren" })
Cast(PRIEST, nil, "CAST", 10473)
local sham = A.enemies[5]
near(CdLeft(sham, "Earth Shock"), 6, "Frost Shock locks Earth Shock")
ok(sham.seen["Frost Shock"] and not sham.seen["Earth Shock"], "only the one used counts as seen")

-- resets
Cast(MAGE, nil, "CAST", 10230)
Cast(MAGE, nil, "CAST", 1953)
Mock.Tick(2)
ok(CdLeft(mage, "Frost Nova") > 0 and CdLeft(mage, "Blink") > 0, "on cooldown")
Cast(MAGE, nil, "CAST", 12472)
ok(CdLeft(mage, "Frost Nova") == 0, "Cold Snap resets Frost Nova")
ok(CdLeft(mage, "Blink") > 0, "Cold Snap leaves Blink")
ok(CdLeft(mage, "Cold Snap") > 0, "Cold Snap itself is on cooldown")
Cast(ROGUE, nil, "CAST", 2094)
Cast(ROGUE, nil, "CAST", 1857)
Mock.Tick(2)
Cast(ROGUE, nil, "CAST", 14185)
ok(CdLeft(rogue, "Blind") == 0 and CdLeft(rogue, "Vanish") == 0, "Preparation resets the rogue")

-- learning from early recasts: talents can explain it, or it is not learned
Cast(ROGUE, nil, "CAST", 2094)
Mock.Tick(100)
Cast(ROGUE, nil, "CAST", 2094)
ok(not (A.global.learned["Sneaky"] and A.global.learned["Sneaky"]["Blind"]), "100 s is below what talents allow: a reset we missed")
near(CdLeft(rogue, "Blind"), 300, "and the clock restarts at the full time")
Mock.Tick(215)
Cast(ROGUE, nil, "CAST", 2094)
near(A.global.learned["Sneaky"]["Blind"], 215, "215 s: talents, learned for that player")
near(CdLeft(rogue, "Blind"), 215, "used straight away")
Mock.Tick(216)
Cast(ROGUE, nil, "CAST", 2094)
near(CdLeft(rogue, "Blind"), 215, "and remembered next time")
A.global.learned = {}

-- the same use from two events is one use
Mock.Tick(20)
Cast(MAGE, nil, "CAST", 2139)
local started = mage.cds["Counterspell"].start
Mock.Tick(0.5)
Cast(MAGE, nil, "CAST", 2139)
ok(mage.cds["Counterspell"].start == started, "seen twice within 1.5 s: one use")

-- a pet's interrupt is its owner's
Mock.units[PET .. "owner"] = Mock.units[LOCK]
Mock.Tick(1)
Cast(PET, MAGE, "CAST", 19647)
near(CdLeft(lock, "Spell Lock"), 30, "Spell Lock credited to the warlock, 30 s")
ok(lock.seen["Spell Lock"], "and no longer a question mark")
Mock.units[PET .. "owner"] = nil

-- trinket and racial have their own slots
Cast(LOCK, nil, "CAST", 52317)
near(CdLeft(lock, "Insignia"), 180, "trinket 3 minutes")
Cast(LOCK, nil, "CAST", 7744)
near(CdLeft(lock, "Will of the Forsaken"), 150, "Will of the Forsaken 150 s")
Mock.Tick(0.2)
local fl = F.frames[3]
ok(fl.trinket.shown and fl.trinket.texture == S("Insignia").texture, "trinket icon")
ok(fl.racial.shown and fl.racial.texture == S("Will of the Forsaken").texture, "racial icon by race")
ok(fl.trinket.lastText == "3m" or fl.trinket.lastText == "180" or fl.trinket.lastText == "179", "trinket counting down: " .. tostring(fl.trinket.lastText))

-- what the cooldown row shows
local function RowHas(f, n)
  for k = 1, f.rowN do if f.row[k].n == n then return true end end
  return false
end
A.dirty = true
Mock.Tick(0.1)
ok(RowHas(F.frames[1], "Counterspell"), "mage row: Counterspell always shown")
ok(RowHas(F.frames[1], "Blink"), "mage row: Blink")
ok(not RowHas(F.frames[1], "Fire Ward"), "mage row: Fire Ward not shown")
ok(not RowHas(fl, "Insignia"), "trinket is not in the row as well")
ok(RowHas(fl, "Spell Lock"), "warlock row: Spell Lock")
Cast(MAGE, nil, "CAST", 12042)
Mock.Tick(0.1)
ok(RowHas(F.frames[1], "Arcane Power"), "a when-used spell pops up")
ok(F.frames[1].rowN <= F.m.cdMax, "row never wider than the frame")
A.SetSpell("Arcane Power", "tier", 0)
A.dirty = true
Mock.Tick(0.1)
ok(not RowHas(F.frames[1], "Arcane Power"), "switched off: gone")
A.db.spells = {}
-- a spell comes back: it glows
Cast(MAGE, nil, "CAST", 1953)
Mock.Tick(15.2)
ok(mage.flash["Blink"], "came back: glow")

A:SetFormat("auto")

-- ---------------------------------------------------------------- auras and DR
local function Debuff(guid, id, tex) table.insert(Mock.units[guid].debuffs, { id = id, tex = tex }) end
for _, g in ipairs({ MAGE, ROGUE, LOCK }) do
  Mock.units[g].debuffs = {}
  Mock.units[g].buffs = {}
end
Mock.Tick(0.3)   -- first look after an aura table exists: nothing there, start of watching
Debuff(MAGE, 12826)
Mock.Tick(0.25)
ok(mage.big and mage.big.def.n == "Polymorph", "Polymorph on the big icon")
near(mage.big.dur, 15, "capped for players: 15 s, not the table's 50")
ok(mage.dr.incap and mage.dr.incap.level == 1, "DR: one landing")
Mock.Tick(0.1)
ok(F.frames[1].ic.texture == nil and F.frames[1].ic.tex.texture == A.AURAS[12826].texture, "icon shows the Polymorph")
ok(F.frames[1].drN == 1, "DR icon")
ok(F.frames[1].drIcons[1].lastTag == "50%", "next one lands at 50%")
Mock.units[MAGE].debuffs = {}
Mock.Tick(0.25)
ok(mage.big == nil, "the moment it goes, it goes")
ok(mage.dr.incap.stop - GetTime() <= 15 and mage.dr.incap.stop - GetTime() > 14.7, "DR resets 15 s after it ended")
Debuff(MAGE, 12826)
Mock.Tick(0.25)
near(mage.big.dur, 7.5, "second one: half")
Mock.units[MAGE].debuffs = {}
Mock.Tick(0.25)
Debuff(MAGE, 12826)
Mock.Tick(0.25)
near(mage.big.dur, 3.75, "third one: quarter")
Mock.Tick(0.1)
ok(F.frames[1].drIcons[1].lastTag == "IMM", "next one: immune")
Mock.units[MAGE].debuffs = {}
Mock.Tick(16)
ok(mage.dr.incap.level == 0, "DR reset after 15 s")
Mock.Tick(0.2)
ok(F.frames[1].drN == 0, "DR icon gone")

-- two groups count apart
Debuff(MAGE, 10308)
Debuff(MAGE, 2094)
Mock.Tick(0.25)
ok(mage.dr.stun and mage.dr.disorient and mage.dr.incap.level == 0, "stun and disorient apart")
ok(mage.big.def.k == "stun", "stun outranks disorient")
Mock.Tick(0.1)
ok(F.frames[1].stripN == 1, "the other one in the strip")
Mock.units[MAGE].debuffs = {}
Mock.Tick(16)

-- no timer for what cannot be known
Debuff(ROGUE, 8643)
Mock.Tick(0.25)
ok(rogue.big and rogue.big.stop == nil, "Kidney Shot: combo points, no timer")
Mock.units[ROGUE].debuffs = {}
Mock.Tick(0.25)
Mock.units[ROGUE].near = false
Mock.Tick(0.25)
Debuff(ROGUE, 10308)
Mock.units[ROGUE].near = true
Mock.Tick(0.25)
ok(rogue.big and rogue.big.stop == nil, "already on them when they came into view: no timer")
Mock.units[ROGUE].debuffs = {}
Mock.Tick(16)

-- immune outranks everything, with the gold edge
table.insert(Mock.units[MAGE].buffs, { id = 11958 })
Debuff(MAGE, 10308)
Mock.Tick(0.3)
ok(mage.big.def.n == "Ice Block" and mage.immune, "Ice Block on top")
Mock.Tick(0.1)
ok(F.frames[1].imm.shown, "gold edge")
Mock.units[MAGE].buffs = {}
Mock.units[MAGE].debuffs = {}
Mock.Tick(0.3)
ok(mage.big == nil and not F.frames[1].imm.shown, "gone with it")
Mock.Tick(16)

-- ClassicAPI's end time, only when shorter
C_UnitAuras = { GetUnitAuras = function(u, f)
  if u == MAGE and f == "HARMFUL" then return { { spellId = 12826, expirationTime = GetTime() + 40 } } end
  return {}
end }
Debuff(MAGE, 12826)
Mock.Tick(0.25)
near(mage.big.dur, 15, "its 40 s does not beat the cap")
Mock.units[MAGE].debuffs = {}
Mock.Tick(16)
C_UnitAuras = { GetUnitAuras = function(u, f)
  if u == MAGE and f == "HARMFUL" then return { { spellId = 10308, expirationTime = GetTime() + 2 } } end
  return {}
end }
Debuff(MAGE, 10308)
Mock.Tick(0.25)
ok(mage.big.stop - GetTime() <= 2 and mage.big.stop - GetTime() > 1.5, "its shorter time wins")
Mock.units[MAGE].debuffs = {}
Mock.Tick(16)
C_UnitAuras = nil

-- nampower's event looks at once, between ticks
Mock.Tick(0.21)
Debuff(MAGE, 15487)
Mock.Fire("DEBUFF_ADDED_OTHER", MAGE)
ok(mage.big and mage.big.def.n == "Silence", "seen the moment the event fires")
Mock.units[MAGE].debuffs = {}
Mock.Fire("DEBUFF_REMOVED_OTHER", MAGE)
ok(mage.big == nil, "and gone")
Mock.Tick(16)

-- a cooldown that starts when the aura ends
Mock.units[MAGE].buffs = { { id = 12043 } }
Cast(MAGE, nil, "CAST", 12043)
Mock.Tick(10.3)
near(CdLeft(mage, "Presence of Mind"), 169.7, "running from the cast")
Mock.units[MAGE].buffs = {}
Mock.Tick(0.3)
near(CdLeft(mage, "Presence of Mind"), 179.85, "starts again when it is used up")

-- enemy's target
Mock.units[MAGE .. "target"] = Mock.units[FRIEND]
Mock.Tick(0.3)
ok(mage.targetName == "Teammate", "who they target")
ok(string.find(F.frames[1].tgt.text, "> Teammate", 1, true) ~= nil, "shown on the frame")
Mock.units[MAGE .. "target"] = nil
Mock.Tick(0.3)
ok(mage.targetName == nil and F.frames[1].tgt.text == "", "cleared")

-- marks
Mock.target = MAGE
A.dirty = true
Mock.Tick(0.1)
ok(F.frames[1].hl.shown, "your target is marked")
Mock.target = nil
A.dirty = true
Mock.Tick(0.1)
ok(not F.frames[1].hl.shown, "and unmarked")

-- stealth
Cast(ROGUE, nil, "CAST", 1787)
Mock.units[ROGUE].near = false
Mock.Tick(0.1)
ok(rogue.stealth, "gone into stealth")
ok(F.frames[2].hpText.text == "STEALTH", "says so")
Mock.units[ROGUE].near = true
Mock.Tick(1.2)
ok(not rogue.stealth, "seen again")

-- ---------------------------------------------------------------- acting
A:TargetEnemy(2)
ok(Mock.target == ROGUE, "target enemy 2")
Mock.target = nil
Mock.casted = {}
A:KickEnemy(1)
ok(Mock.casted[1] and Mock.casted[1][1] == "Pummel" and Mock.casted[1][2] == MAGE, "kick enemy 1: your interrupt at their GUID")
Mock.casted = {}
Mock.cdStart = GetTime()
A:KickEnemy(1)
ok(Mock.casted[1] == nil, "kick on cooldown: nothing cast")
Mock.cdStart = nil
SlashCmdList["OCTOARENAFRAMES"]("cast 2 Blind")
ok(Mock.casted[1] and Mock.casted[1][1] == "Blind" and Mock.casted[1][2] == ROGUE, "/oaf cast 2 Blind")
SlashCmdList["OCTOARENAFRAMES"]("target 3")
ok(Mock.target == LOCK, "/oaf target 3")
Mock.target = nil
this, arg1 = F.frames[2], "LeftButton"
F.frames[2].scripts.OnClick()
ok(Mock.target == ROGUE, "click: target")
Mock.target = nil
this, arg1 = nil, nil
-- focus: pfUI's frame when there is no ClassicAPI
pfUI = { uf = { focus = {}, focustarget = {} } }
A:FocusEnemy(1)
ok(pfUI.uf.focus.label == MAGE and pfUI.uf.focustarget.label == MAGE .. "target", "focus through pfUI")
A.dirty = true
Mock.Tick(0.1)
ok(F.frames[1].hl.shown, "your focus is marked")
pfUI = nil
A.dirty = true
Mock.Tick(0.1)

-- ---------------------------------------------------------------- a new match
Mock.zone = "Stranglethorn Vale"
Mock.instance = nil
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Tick(0.1)
ok(A.zone == "none", "out of the arena")
ok(not A.enemies[1].name, "auto-filled enemies forgotten")
ok(not F.anchor:IsShown(), "frames gone")
ok(A.db.slots[1].name == nil, "and not saved")
WorldFrame.children = {}   -- the last match's nameplates
Mock.zone, Mock.instance = "Blood Ring", "pvp"
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Tick(0.1)
ok(A.zone == "arena" and F.anchor:IsShown(), "next arena")
Mock.Enemy("0x00000000000000C1", "Newguy", "DRUID", 5, 5, { raceToken = "Tauren" })
Cast("0x00000000000000C1", nil, "CAST", 16979)
ok(A.enemies[1].name == "Newguy", "new enemies from slot 1 again")
near(CdLeft(A.enemies[1], "Feral Charge"), 15, "Feral Charge")

-- ---------------------------------------------------------------- before the gates open
-- A fresh arena: the other team is in the far room, not attackable yet, nobody has done a thing.
local function Leave()
  Mock.zone, Mock.instance = "Duskwood", nil
  Mock.Fire("PLAYER_ENTERING_WORLD")
  WorldFrame.children = {}
  Mock.target = nil
  Mock.Tick(0.1)
end
local function Enter(zone)
  Mock.zone, Mock.instance = zone or "Lordaeron Arena", "pvp"
  Mock.Fire("PLAYER_ENTERING_WORLD")
end
local function Server(msg) Mock.Fire("CHAT_MSG_ADDON", "TW_ARENA", msg, "GUILD", "Server") end

local G1, G2, G3, MATE1, MATE2 = "0x00000000F8CE15B1", "0x00000000F8CE15B2", "0x00000000F8CE15B3", "0x00000000F8CE15C1", "0x00000000F8CE15C2"
local function Room()
  Mock.Enemy(G1, "Duskfang-NZ", "WARLOCK", 80, 0, { raceToken = "Scourge", locked = true })
  Mock.Enemy(G2, "Arrowmoss", "HUNTER", 80, 5, { raceToken = "NightElf", locked = true })
  Mock.Enemy(G3, "Healbot", "PRIEST", 80, 10, { raceToken = "Dwarf", locked = true })
  Mock.Enemy(MATE1, "Mate", "PRIEST", 1, 1, { raceToken = "Tauren", faction = "Alliance", locked = true })
  Mock.Enemy(MATE2, "Pal", "PALADIN", 1, 2, { raceToken = "Human", faction = "Alliance", locked = true })
end
Room()
-- behind the gates nobody can be attacked, teammates of the other faction included
local realCanAttack = UnitCanAttack
function UnitCanAttack(a, u)
  local e = Mock.units[u]
  if e and e.locked then return false end
  return realCanAttack(a, u)
end
local asked = 0
function RequestArenaScoreInfo() asked = asked + 1 end
local ROSTER = "S2C_SCOREBOARD;0;6;Tester|1|0:Mate|1|0:Pal|1|0:Duskfang-NZ|2|0:Arrowmoss|2|0:Healbot|2|0"

Leave()
Mock.party = 2
asked = 0
Mock.zone, Mock.instance = "Orgrimmar", "pvp"
Mock.Fire("PLAYER_ENTERING_WORLD")
Server(ROSTER)                        -- the answer can beat the zone name
Mock.zone = "Lordaeron Arena"
Mock.Tick(0.7)
ok(A.zone == "arena", "in the arena")
ok(A.enemies[1].name == "Duskfang-NZ" and A.enemies[2].name == "Arrowmoss" and A.enemies[3].name == "Healbot",
  "the server's list named the whole team at once, in its order, realm suffix kept")
ok(not A.byName["mate"] and not A.byName["pal"] and not A.byName["tester"], "your own team left out")
ok(A:Max() == 3, "three frames, from the server's count")
ok(F.frames[1].name.text == "|cffffd1001|r  Duskfang-NZ", "name on the frame before anyone has been seen")

Leave()
asked = 0
Enter()
Mock.Tick(1.1)
ok(asked >= 1, "asks the server as soon as it is in the arena (asked " .. asked .. ")")
ok(not A.enemies[1].name, "no answer yet, nobody invented")
local before = asked
Mock.Tick(2)
ok(asked > before, "keeps asking every second until it has the team")
Server("S2C_SCOREBOARD;0;2;Tester|1|0:Mate|1|0")
ok(A.teamEnemy == nil, "one team so far: cannot tell the sides, nobody invented")
Server("S2C_SCOREBOARD;0;4;Tester|1|0:Mate|1|0:Pal|1|0:Duskfang-NZ|2|0")
ok(A.enemies[1].name == "Duskfang-NZ" and not A.teamComplete, "the first enemy to arrive; the team is not complete")
Server(ROSTER)
ok(A.enemies[3].name == "Healbot" and A.teamComplete, "the rest as they arrive")
ok(A.enemies[1].name == "Duskfang-NZ", "earlier slots do not move")
before = asked
Mock.Tick(4)
ok(asked <= before + 1, "complete: stops asking so often")

-- class and race from the scoreboard, still before anyone has been seen
Mock.scores = { { "Tester", 1, "Warrior" }, { "Mate", 1, "Priest" }, { "Pal", 0, "Paladin" },
                { "Duskfang-NZ", 0, "Warlock", "Undead" }, { "Arrowmoss", 1, "Hunter", "Night Elf" }, { "Healbot", 1, "Priest", "Dwarf" } }
local realScore = GetBattlefieldScore
function GetBattlefieldScore(i)
  local s = Mock.scores[i]
  return s[1], 0, 0, 0, 0, s[2], 0, s[4], s[3]
end
Leave()
Enter()
Mock.units[G1].near, Mock.units[G2].near, Mock.units[G3].near = false, false, false
Server(ROSTER)
Mock.Fire("UPDATE_BATTLEFIELD_SCORE")
ok(A.enemies[1].class == "WARLOCK" and A.enemies[1].race == "Scourge", "class and race from the scoreboard, by name")
ok(A.enemies[2].class == "HUNTER" and A.enemies[2].race == "NightElf", "race name turned into the race token")
ok(A.enemies[3].class == "PRIEST", "the third")
A.dirty = true
Mock.Tick(0.1)
ok(F.frames[1].trinket.shown and F.frames[1].racial.texture == S("Will of the Forsaken").texture, "trinket and racial up before the gates")
ok(F.frames[2].ic.tex.texture == A.CLASS_ART, "class icon up")
local function RowNames(f) local t = {} for k = 1, f.rowN do t[f.row[k].n] = true end return t end
ok(RowNames(F.frames[1])["Death Coil"], "their cooldowns up")
ok(A.enemies[1].unit == nil, "not read yet: not in sight")
Mock.scores = {}
Mock.units[G1].near, Mock.units[G2].near, Mock.units[G3].near = true, true, true

-- the faction column must not decide when it could be wrong
Leave()
Enter()
Mock.scores = { { "Tester", 1, "Warrior" }, { "Mate", 0, "Priest" }, { "Pal", 0, "Paladin" }, { "Healbot", 1, "Priest" } }
Mock.Tick(3.5)
Mock.Fire("UPDATE_BATTLEFIELD_SCORE")
ok(not A.enemies[1].name, "factions mixed across the teams: not used")
Mock.scores = { { "Tester", 1, "Warrior" }, { "Mate", 1, "Priest" }, { "Pal", 1, "Paladin" },
                { "Duskfang-NZ", 0, "Warlock" }, { "Arrowmoss", 0, "Hunter" }, { "Healbot", 0, "Priest" } }
Mock.Fire("UPDATE_BATTLEFIELD_SCORE")
ok(A:SlotCount(5) == 3 and A.byName["duskfang"], "no list from the server and your whole team on one side: it stands in")
Mock.scores = {}
GetBattlefieldScore = realScore

-- which unit: ClassicAPI's lookup, no target swap, nothing else needed
Leave()
local lookups = {}
local function Lookup(name, exact)
  table.insert(lookups, name)
  if not exact then return nil end
  if name == "Duskfang-NZ" then return G1 end
  if name == "Arrowmoss" then return G2 end
  if name == "Healbot" then return "target" end    -- a token when one fits
  return nil
end
UnitTokenFromName = Lookup
Mock.target = G3
Enter()
Server(ROSTER)
ok(A.enemies[1].guid == G1 and A.enemies[2].guid == G2, "by name to GUID the moment the list arrives")
ok(A.enemies[3].guid == G3, "a token is turned into the GUID")
ok(A:RosterFull(), "the whole team found")
Mock.Tick(0.1)
ok(not A.hunting, "and the hunt stops")
Mock.Tick(0.1)
ok(F.frames[1].hp.value == 80 and F.frames[1].baseAlpha ~= 0.55, "health read before the gates open (seen, not greyed as unseen)")
ok(A.foundAt ~= nil, "time to find them noted")
Mock.target = nil
Leave()
-- a name that resolves to the wrong person does not count
UnitTokenFromName = function(name) return G2 end
Enter()
Server(ROSTER)
ok(A.enemies[1].guid == nil and A.enemies[2].guid == G2, "the lookup's answer is checked against the name")
UnitTokenFromName = nil
Leave()

-- no lookup: any event with a GUID does it; nameplates; the server's list decides who is who
Enter()
Server(ROSTER)
Mock.Tick(0.3)
ok(A.hunting, "hunting: listening to every event with a GUID")
ok(A.events.events["UNIT_MANA_GUID"] and A.events.events["AURA_CAST_ON_OTHER"], "those events are on while hunting")
Mock.Fire("BUFF_ADDED_OTHER", G1, 3, 10938)
ok(A.enemies[1].guid == G1, "a buff in the prep room binds the GUID, though they cannot be attacked yet")
Mock.Fire("UNIT_MANA_GUID", G2, 1)
ok(A.enemies[2].guid == G2, "a mana update does")
Mock.Fire("AURA_CAST_ON_OTHER", 10938, MATE1, MATE1)
ok(not A.byGuid[MATE1], "a teammate's buff names nobody")
Mock.Plate(G3)
Mock.Tick(1.1)
ok(A.enemies[3].guid == G3, "a nameplate does")
ok(not A.hunting, "all found: stops")
ok(not A.events.events["UNIT_MANA_GUID"], "those events are off again")
ok(A.events.events["BUFF_ADDED_OTHER"], "the ones the aura code needs stay on")
Leave()
ok(not A.teamEnemy and not A.match, "forgotten on leaving")

-- no list at all: "can attack", else anyone not on your team once the group is known
Mock.Tick(1)
Enter()
Mock.Tick(0.3)
Mock.Fire("BUFF_ADDED_OTHER", G1, 3, 10938)
ok(not A.enemies[1].name, "in the first moments nobody is taken on a guess")
Mock.Fire("BUFF_ADDED_OTHER", MATE1, 3, 10938)
ok(not A.enemies[1].name, "nor a teammate")
local realExists = UnitExists
function UnitExists(u)
  if u == "player" then return 1, "0x0000000000000001" end
  if u == "party1" then return 1, MATE1 end
  if u == "party2" then return 1, MATE2 end
  if u == "target" then local e = Mock.units[Mock.target or ""] if e and e.near then return 1, e.guid end return nil end
  if u == "mouseover" then return nil end
  local e = Mock.units[u]
  if e and e.near then return 1, e.guid end
  return nil
end
local realGuid = GetUnitGUID
function GetUnitGUID(u)
  local _, g = UnitExists(u)
  return g
end
Mock.Tick(2.5)
ok(A:GroupSettled(), "your whole group known")
Mock.Fire("BUFF_ADDED_OTHER", MATE1, 3, 10938)
ok(not A.byGuid[MATE1], "a teammate is never taken")
Mock.Fire("BUFF_ADDED_OTHER", G1, 3, 10938)
ok(A.enemies[1].name == "Duskfang-NZ" and A.enemies[1].guid == G1, "anyone else in the arena is the other team")
Mock.Enemy("0x00000000F8CE15D1", "Wrongun", "ROGUE", 5, 5, { locked = true })
Mock.Fire("BUFF_ADDED_OTHER", "0x00000000F8CE15D1", 3, 10938)
ok(A.byName["wrongun"], "a guess")
Server(ROSTER)
ok(not A.byName["wrongun"], "the server's list overrules a guess")
ok(A.enemies[1].name == "Duskfang-NZ", "and leaves the right ones where they are")
ok(A:SlotCount(5) == 3, "three enemies, as the list says")
Mock.Fire("BUFF_ADDED_OTHER", "0x00000000F8CE15D1", 3, 10938)
ok(not A.byName["wrongun"], "not on the list: stays out")
GetUnitGUID = realGuid
UnitExists = realExists

-- no ClassicAPI: a target swap finds them, one a second, your target put straight back
Leave()
local realTBN, realTLT = TargetByName, TargetLastTarget
local before2, swaps = nil, 0
function TargetByName(n)
  swaps = swaps + 1
  before2 = Mock.target
  for g, u in pairs(Mock.units) do
    if u.name == n and u.near then Mock.target = g end
  end
end
function TargetLastTarget() Mock.target = before2 end
local BY = "0x00000000F8CE15E1"
Mock.Enemy(BY, "Bystander", "MAGE", 1, 1, { faction = "Horde" })
Mock.target = BY
Enter()
Server(ROSTER)
Mock.Tick(0.3)
ok(swaps == 1 and A.enemies[1].guid == G1, "one target swap found the first")
ok(A.enemies[1].class == "WARLOCK" and A.enemies[1].race == "Scourge", "with class and race")
ok(Mock.target == BY, "your target is put straight back")
Mock.Tick(3)
ok(A.enemies[2].guid == G2 and A.enemies[3].guid == G3, "the others a second apart")
ok(Mock.target == BY, "your target still yours")
ok(not A.hunting, "all found: stops")
local swapsThen = swaps
Mock.Tick(3)
ok(swaps == swapsThen, "no more swaps")
Leave()
swaps = 0
Mock.target = nil
Mock.units["player"] = { combat = true }
Enter()
Server(ROSTER)
Mock.Tick(2)
ok(swaps == 0, "never in combat")
Mock.units["player"] = nil
Leave()
swaps = 0
Mock.units[BY] = nil
A.db.huntTarget = false
Enter()
Server(ROSTER)
Mock.Tick(2)
ok(swaps == 0, "switched off: no swaps")
A.db.huntTarget = true
Leave()
swaps = 0
UnitTokenFromName = function() return nil end
Enter()
Server(ROSTER)
Mock.Tick(2)
ok(swaps == 0, "with ClassicAPI: never, it needs no swap")
UnitTokenFromName = nil
TargetByName, TargetLastTarget = realTBN, realTLT
Leave()

-- /reload inside an arena: starts looking again by itself
Enter()
Server(ROSTER)
A.match = nil
A.teamEnemy, A.teamAlly, A.lastRoster, A.askNext = nil, nil, nil, nil
asked = 0
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Tick(0.3)
ok(A.match and asked >= 1, "a reload in an arena asks again")
Server(ROSTER)
ok(A:SlotCount(5) == 3, "and has them again")
ok(string.find(A:RosterText(), "3 enemies named", 1, true) ~= nil, "status line")
Leave()

-- the log: one match shows what really happened
local lg = A.global.arenaLog
ok(lg and lg[1] and lg[1].zone == "Lordaeron Arena" and table.getn(lg[1].log) > 0, "every match is logged")
ok(table.getn(lg) <= 8, "the last 8 matches")
local logged = ""
for i = 1, table.getn(lg[1].log) do logged = logged .. lg[1].log[i] .. "\n" end
ok(string.find(logged, "S2C_SCOREBOARD", 1, true) ~= nil, "with the server's own words")
SlashCmdList["OCTOARENAFRAMES"]("log")

-- names: a realm suffix is kept, typed names are tidied
ok(A.Key("Duskfang-NZ") == "duskfang" and A.Key("Bob") == "bob" and A.Key(nil) == nil, "lookup key")
ok(A.CleanName("duskfang-nz") == "Duskfang-NZ" and A.CleanName(" bOB ") == "Bob" and A.CleanName("") == nil, "typed names")
UnitCanAttack = realCanAttack
for _, g in ipairs({ G1, G2, G3, MATE1, MATE2 }) do Mock.units[g] = nil end
Mock.units["0x00000000F8CE15D1"] = nil


-- ---------------------------------------------------------------- strict
Mock.zone, Mock.instance = "Duskwood", nil
Mock.Fire("PLAYER_ENTERING_WORLD")
A.db.mode = "strict"
A:SetFormat("2v2")
A:SetSlot(1, "frostmage", "MAGE")
ok(A.enemies[1].name == "Frostmage", "name tidied")
A.dirty = true
Mock.Tick(0.1)
ok(F.anchor:IsShown(), "named enemies show outside arenas")
local ign = A.ignored
Cast(ROGUE, nil, "CAST", 1769)
ok(A.ignored == ign + 1, "someone else's cast is ignored")
ok(not A.enemies[2].name, "no slot for them")
Cast(MAGE, nil, "CAST", 2139)
ok(CdLeft(A.enemies[1], "Counterspell") > 0, "the named one is tracked")
ok(A.enemies[1].guid == MAGE, "GUID bound by name")
A.db.showWhen = "arena"
A.dirty = true
Mock.Tick(0.1)
ok(not F.anchor:IsShown(), "only in arenas: hidden")
A.db.showWhen = "set"
Mock.target = FRIEND
A:SetFromTarget(2)
ok(A.enemies[2].name == "Teammate" and A.enemies[2].class == "PRIEST", "from target, a friend for practice")
Cast(FRIEND, nil, "CAST", 15487)
ok(CdLeft(A.enemies[2], "Silence") > 0, "a named friend counts")
Mock.target = nil
A:ClearSlots()
ok(A:SlotCount(5) == 0, "cleared")
A.db.mode = "auto"
A:SetFormat("auto")

-- ---------------------------------------------------------------- BG / World
Mock.zone, Mock.instance = "Warsong Gulch", "pvp"
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Tick(0.1)
ok(A:IsBG(), "battleground: BG / World by itself")
ok(not F.anchor:IsShown(), "no frames")
Cast(MAGE, nil, "CAST", 2139)
ok(A.bg[MAGE] and A.bg[MAGE].cds["Counterspell"], "a row for the mage")
Cast(FRIEND, nil, "CAST", 2139)
ok(not A.bg[FRIEND], "friends get none")
Cast("0xF130000000000099", nil, "CAST", 1769)
Mock.Tick(0.2)
ok(A.Bars.bg:IsShown(), "rows shown")
ok(A.Bars.icons[1].shown and A.Bars.icons[1].texture == S("Counterspell").texture, "icon up")
Mock.Tick(31)
ok(A.bg[MAGE] == nil, "ready: the row goes")
Mock.zone, Mock.instance = "Duskwood", nil
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Tick(0.2)
ok(not A.Bars.bg:IsShown(), "gone outside")

-- ---------------------------------------------------------------- interrupt bar
Mock.zone, Mock.instance = "Lordaeron Arena", "pvp"
Mock.Fire("PLAYER_ENTERING_WORLD")
A.db.intBar = true
Cast(MAGE, nil, "CAST", 2139)
Mock.Tick(0.2)
ok(A.Bars.int:IsShown(), "interrupt bar up")
ok(A.Bars.barIcons[1].shown and A.Bars.barIcons[1].texture == S("Counterspell").texture, "with their interrupt")
A.db.intBar = false
Mock.Tick(0.2)
ok(not A.Bars.int:IsShown(), "off")
Mock.zone, Mock.instance = "Duskwood", nil
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Tick(0.1)

-- ---------------------------------------------------------------- no SuperWoW
A.db.detection = "log"
A:RegisterLog()
ok(not A.UseSW(), "log mode")
ok(A.events.events["CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE"], "combat log on")
Mock.zone, Mock.instance = "Sunstrider Court", "pvp"
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Tick(0.1)
local function Log(ev, msg) Mock.Fire(ev, msg) end
Log("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "Sneaky's Kick hits you for 25.")
local r = A.enemies[1]
ok(r.name == "Sneaky" and r.class == "ROGUE", "found by name from the log, class from the spell")
near(CdLeft(r, "Kick"), 10, "Kick from the log")
Log("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "Sneaky begins to perform Slice and Dice.")
Log("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF", "Sneaky gains Evasion.")
near(CdLeft(r, "Evasion"), 240, "Evasion from gains")
Log("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "Frostmage begins to cast Polymorph.")
local m2 = A.byName["frostmage"]
ok(not m2, "a cast with no tracked spell does not take a slot")
Log("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF", "Frostmage casts Blink.")
m2 = A.byName["frostmage"]
ok(m2 and m2.class == "MAGE", "Blink finds the mage")
Log("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "Frostmage begins to cast Polymorph.")
ok(m2.cast and m2.cast.name == "Polymorph" and m2.cast.dur == 1.5, "cast bar from the log, time from the table")
Log("CHAT_MSG_SPELL_SELF_DAMAGE", "You interrupt Frostmage's Polymorph.")
ok(m2.cast == nil and m2.castEnd.text == "INTERRUPTED", "your kick from the log")
Log("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "Sneaky interrupts your Frostbolt.")
ok(r.cds["Kick"] ~= nil, "they kicked you")
-- health only through a token
Mock.Tick(0.1)
ok(m2.unit == nil, "not your target: no unit")
Mock.target = MAGE
Mock.units[MAGE].hp = 33
Mock.units[MAGE].near = true
Mock.Tick(0.1)
ok(m2.unit == "target" and m2.hp == 33, "your target: read through the token")
Mock.target = nil
Log("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "You are afflicted by Blind.")
near(CdLeft(r, "Blind"), 300, "a debuff on you: the one rogue gets the cooldown")
A.db.detection = "auto"
A:RegisterLog()
Mock.zone, Mock.instance = "Duskwood", nil
Mock.Fire("PLAYER_ENTERING_WORLD")

-- ---------------------------------------------------------------- test mode
Mock.chat = {}
Mock.sounds = {}
A.db.announce, A.db.soundUse = true, true
A:SetTest(true)
ok(A.test and A:Max() == 3, "test: three samples")
Mock.Tick(0.1)
ok(F.anchor:IsShown(), "frames show in test mode")
ok(F.handle.shown, "with the handle")
Mock.Tick(30)
local any = false
for i = 1, 3 do if next(A.testEnemies[i].cds) then any = true end end
ok(any, "samples used spells")
ok(table.getn(Mock.chat) == 0 and table.getn(Mock.sounds) == 0, "test mode never announces or plays sounds")
A:SetFormat("5v5")
ok(A:Max() == 5, "test follows the format")
A:SetFormat("bg")
Mock.Tick(10)
ok(A.Bars.bg:IsShown() and not F.anchor:IsShown(), "test BG / World rows")
A:SetFormat("auto")
Mock.Tick(25)
ok(not A.test, "test mode ends by itself")
A.db.announce, A.db.soundUse = false, false
Mock.Tick(0.1)
ok(not F.anchor:IsShown(), "and the frames go")

-- full test: every slot, runs until stopped, kicks + trinkets + racials
Mock.chat, Mock.sounds = {}, {}
A.db.announce, A.db.soundUse, A.db.soundTrinket, A.db.announceKicks = true, true, true, true
A.db.lockout = true
A:SetTest(true, true)
ok(A.test and A.testFull and A:Max() == A.MAX, "full test: every slot with the format on auto")
local kicked, trink, racial = false, false, false
for step = 1, 600 do
  Mock.Tick(0.5)
  for i = 1, A.MAX do
    local e = A.testEnemies[i]
    if e.lockout or (e.castEnd and e.castEnd.text == "INTERRUPTED") then kicked = true end
    if A.TRINKET and e.cds[A.TRINKET.n] then trink = true end
    local r = A.RACIAL[e.race or ""]
    if r and e.cds[r.n] then racial = true end
  end
end
ok(A.test and A.testFull, "full test is still running after 5 minutes")
ok(kicked and trink and racial, "full test plays kicks, trinkets and racials")
ok(table.getn(Mock.chat) == 0 and table.getn(Mock.sounds) == 0, "full test never announces or plays sounds")
A:SetFormat("2v2")
ok(A:Max() == 2, "full test follows a fixed format")
A:SetFormat("auto")
A:SetTest(true)
ok(A.test and not A.testFull and A.testEnds, "the quick test from a full one gets its timer back")
A:SetTest(true, true)
A:SetTest(false)
ok(not A.test and not A.testFull, "full test stops")
SlashCmdList.OCTOARENAFRAMES("test full")
ok(A.testFull, "/oaf test full starts it")
SlashCmdList.OCTOARENAFRAMES("test full")
ok(not A.test, "and stops it")
A.db.announce, A.db.soundUse, A.db.soundTrinket, A.db.announceKicks = false, false, false, false
Mock.Tick(0.1)

-- ---------------------------------------------------------------- announcing
Mock.zone, Mock.instance = "Lordaeron Arena", "pvp"
Mock.Fire("PLAYER_ENTERING_WORLD")
A.db.announce, A.db.soundTrinket, A.db.announceKicks = true, true, true
Mock.chat, Mock.sounds = {}, {}
Cast(MAGE, nil, "CAST", 2139)
ok(Mock.chat[1] and string.find(Mock.chat[1][1], "Frostmage used Counterspell (30s)", 1, true), "announced")
Cast(ROGUE, nil, "CAST", 52317)
ok(table.getn(Mock.sounds) == 1, "trinket sound")
Mock.chat = {}
Cast(LOCK, nil, "START", 12826, 1500)
Cast(TEAM, LOCK, "CAST", 1769)
ok(Mock.chat[1] and string.find(Mock.chat[1][1], "Arcane locked", 1, true), "kick announced with the school")
A.db.announce, A.db.soundTrinket, A.db.announceKicks = false, false, false

-- ---------------------------------------------------------------- mirrored
A.db.mirror = true
A.dirty = true
Mock.Tick(0.1)
ok(F.frames[1].ic.point[4] == F.m.W - F.m.icon, "mirrored: icon on the right")
A.db.mirror = false
A.dirty = true
Mock.Tick(0.1)
ok(F.frames[1].ic.point[4] == 0, "back on the left")

-- ---------------------------------------------------------------- moving
A.db.locked = false
A.dirty = true
Mock.Tick(0.1)
ok(F.handle.shown, "unlocked: a handle to drag")
F:SavePos()
ok(A.db.pos and A.db.pos.left == 100 and A.db.pos.top == 700, "position saved")
A.db.locked = true
A.dirty = true
Mock.Tick(0.1)
ok(not F.handle.shown, "locked: no handle")

-- ---------------------------------------------------------------- options
SlashCmdList["OCTOARENAFRAMES"]("")
local O = A.Options
ok(O.win and O.win:IsShown(), "options open")
for i = 1, table.getn(O.pages) do
  O:ShowPage(i)
  ok(O.pages[i]:IsShown(), "page " .. i)
end
O.spellClass = "OTHER"
O:Refresh()
O.spellClass = "SHAMAN"
O:Refresh()
ok(table.getn(O:SpellList()) <= 34, "every class fits the Spells page")
for _, c in ipairs(A.CLASSES) do
  O.spellClass = c
  ok(table.getn(O:SpellList()) <= 34, c .. " fits the Spells page")
end
O.spellClass = "OTHER"
ok(table.getn(O:SpellList()) <= 34, "racials and items fit")
-- profiles
A.db.barW = 222
ok(A:SaveProfile("arena"), "profile saved")
A.db.barW = 150
ok(A:LoadProfile("arena") and A.db.barW == 222, "profile loaded")
A:ResetLayout()
ok(A.db.barW == 170, "layout reset")
ok(A.global.profiles["arena"] ~= nil, "profiles survive a layout reset")
O.win:Hide()

-- ---------------------------------------------------------------- from OctoKicks
OctoKicksDB = {
  format = "3v3", mode = "strict", numSize = 61, sweep = "fill", bgRows = 4,
  slots = { { name = "Tourney", class = "MAGE" }, { name = "Autofilled", class = "ROGUE", auto = true }, {}, {}, {} },
  spells = { ["Kick"] = { on = false }, ["Blink"] = { cd = 12 }, ["No Such Spell"] = { cd = 1 } },
}
Mock.loaded = { OctoKicks = true }
A.db.kicksImported = nil
A:ClearSlots()      -- at login the slots are empty
A:ImportOctoKicks()
ok(A.db.numSize == 61 and A.db.sweep == "fill" and A.db.bgRows == 4, "settings copied")
ok(A.enemies[1].name == "Tourney" and A.db.slots[1].name == "Tourney", "named enemy copied")
ok(not A.db.slots[2].name, "auto-filled one left out")
ok(A.db.mode == "strict" and A.db.format == "3v3", "tournament setup copied whole")
ok(A.SpellTier(S("Kick")) == 0 and A.SpellCD(S("Blink")) == 12, "spell choices copied")
ok(A.db.spells["No Such Spell"] == nil, "unknown spells left out")
Mock.popup = nil
Mock.Fire("PLAYER_ENTERING_WORLD")
ok(Mock.popup == "OCTOARENA_KICKS", "offers to switch OctoKicks off")
A:ClearSlots()
A.db.mode, A.db.format, A.db.spells = "auto", "auto", {}
OctoKicksDB = { format = "3v3", mode = "strict", slots = { {}, {}, {}, {}, {} } }
A.db.kicksImported = nil
A:ImportOctoKicks()
ok(A.db.mode == "auto" and A.db.format == "auto", "an empty strict setup is not copied: arenas must fill by themselves")
Mock.loaded = nil
OctoKicksDB = nil

-- ---------------------------------------------------------------- the end
if table.getn(A.errors) > 0 then
  for i = 1, table.getn(A.errors) do print("EVENT ERROR: " .. A.errors[i]) end
end
ok(table.getn(A.errors) == 0, "no errors caught in event handlers")

print(checks .. " checks, " .. fails .. " failed")
if fails > 0 then os.exit(1) end
