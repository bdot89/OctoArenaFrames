-- OctoArenaFrames :: core
-- Arena frames for this 1.12 client, with OctoKicks built in. 1.12 has no arena
-- units, so enemies are found by GUID (SuperWoW) or by name (combat log, target,
-- mouseover) and kept in numbered slots that never swap during a match.
--
-- What every number is based on, so the frames never show something invented:
--   cooldowns, durations, icons: this client's own Spell.dbc (Data\SpellData.lua)
--   what is on cooldown:         that enemy's casts, seen as they happen
--   what is on them now:         their real auras, read 5 times a second
-- Arena facts from the user's 92 logged matches: zones are Blood Ring, Lordaeron
-- Arena and Sunstrider Court, and IsInInstance says "pvp" there (never "arena");
-- for half a second on the way in the zone name is still the old one; the player's
-- GUID changes inside. How the enemy team is known before the gates open: Arena.lua.
-- See CLAUDE.md.

local A = OctoArenaFrames
A.VERSION = "1.0.1"
A.MAX = 5              -- the most enemies (5v5)

A.FORMATS = {
  { "auto", "Auto", 0 }, { "2v2", "2v2", 2 }, { "3v3", "3v3", 3 }, { "5v5", "5v5", 5 }, { "bg", "BG / World", 0 },
}

A.ARENAS = { ["Blood Ring"] = true, ["Lordaeron Arena"] = true, ["Sunstrider Court"] = true }

A.SOUNDS = {
  { key = "RaidWarning", label = "Raid warning", file = "Sound\\Interface\\RaidWarning.wav" },
  { key = "Whisper",     label = "Whisper ping", file = "Sound\\Interface\\iTellMessage.wav" },
  { key = "Bell",        label = "Bell",         file = "Sound\\Doodad\\BellTollHorde.wav" },
  { key = "Gong",        label = "Gong",         file = "Sound\\Doodad\\G_GongTroll01.wav" },
  { key = "Ping",        label = "Map ping",     file = "Sound\\Interface\\MapPing.wav" },
}

local MEDIA = "Interface\\AddOns\\OctoArenaFrames\\media\\"
A.MEDIA = MEDIA
A.FONTS = {
  { key = "pt",     label = "PT Sans Narrow", file = MEDIA .. "fonts\\PT-Sans-Narrow-Bold.ttf" },
  { key = "roboto", label = "Roboto",         file = MEDIA .. "fonts\\Roboto.ttf" },
  { key = "fira",   label = "Fira Sans",      file = MEDIA .. "fonts\\FiraSansCondensed-SemiBold.ttf" },
  { key = "share",  label = "Share",          file = MEDIA .. "fonts\\ShareBold.ttf" },
  { key = "friz",   label = "Friz Quadrata",  file = "Fonts\\FRIZQT__.TTF" },
  { key = "arialn", label = "Arial Narrow",   file = "Fonts\\ARIALN.TTF" },
}
A.UI_FONT = MEDIA .. "fonts\\Roboto.ttf"

A.BARS = {
  { key = "smooth", label = "Smooth", file = MEDIA .. "bar-smooth" },
  { key = "gloss",  label = "Gloss",  file = MEDIA .. "bar-gloss" },
  { key = "flat",   label = "Flat",   file = "Interface\\Buttons\\WHITE8X8" },
  { key = "game",   label = "Game",   file = "Interface\\TargetingFrame\\UI-StatusBar" },
}

A.COLORS = {
  { key = "white",  label = "White",      rgb = { 1, 1, 1 } },
  { key = "gold",   label = "Gold",       rgb = { 1, 0.82, 0 } },
  { key = "blue",   label = "Light blue", rgb = { 0.55, 0.82, 1 } },
  { key = "yellow", label = "Yellow",     rgb = { 1, 0.92, 0.25 } },
  { key = "orange", label = "Orange",     rgb = { 1, 0.55, 0.1 } },
  { key = "red",    label = "Red",        rgb = { 1, 0.25, 0.2 } },
}

A.CLASSES = { "WARRIOR", "ROGUE", "MAGE", "PRIEST", "WARLOCK", "SHAMAN", "DRUID", "PALADIN", "HUNTER" }
A.CLASS_COLOR = {
  WARRIOR = { 0.78, 0.61, 0.43 }, ROGUE = { 1, 0.96, 0.41 }, MAGE = { 0.41, 0.8, 0.94 },
  PRIEST = { 1, 1, 1 }, WARLOCK = { 0.58, 0.51, 0.79 }, SHAMAN = { 0, 0.44, 0.87 },
  DRUID = { 1, 0.49, 0.04 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
}
A.CLASS_LABEL = {
  WARRIOR = "Warrior", ROGUE = "Rogue", MAGE = "Mage", PRIEST = "Priest", WARLOCK = "Warlock",
  SHAMAN = "Shaman", DRUID = "Druid", PALADIN = "Paladin", HUNTER = "Hunter",
}
A.CLASS_TCOORDS = {
  WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
  DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
  PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}
A.CLASS_ART = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

-- border colour of a cooldown icon, and the order icons sit in along the row
A.KIND_COLOR = {
  interrupt = { 0.25, 0.6, 1 }, silence = { 0.7, 0.35, 1 }, stun = { 1, 0.55, 0.1 }, cc = { 1, 0.35, 0.6 },
  root = { 0.3, 0.85, 0.85 }, defense = { 0.3, 0.85, 0.35 }, immune = { 1, 0.85, 0.2 }, offense = { 1, 0.25, 0.2 },
  mobility = { 0.85, 0.85, 0.5 }, heal = { 0.5, 1, 0.6 }, utility = { 0.6, 0.6, 0.65 },
  dr1 = { 0.3, 1, 0.3 }, dr2 = { 1, 0.8, 0.15 }, dr3 = { 1, 0.2, 0.15 },
}
A.KIND_LABEL = {
  interrupt = "interrupt", silence = "silence", stun = "stun", cc = "crowd control", root = "root",
  defense = "defensive", immune = "immunity", offense = "offensive", mobility = "movement", heal = "heal", utility = "utility",
}
local KIND_ORDER = { interrupt = 1, silence = 2, stun = 3, cc = 4, root = 5, immune = 6, defense = 7, offense = 8, mobility = 9, heal = 10, utility = 11 }

A.SCHOOL_COLOR = {
  [0] = { 0.8, 0.8, 0.8 }, [1] = { 1, 0.9, 0.5 }, [2] = { 1, 0.45, 0.1 }, [3] = { 0.3, 0.9, 0.3 },
  [4] = { 0.45, 0.8, 1 }, [5] = { 0.6, 0.4, 0.9 }, [6] = { 0.9, 0.55, 1 },
}
A.SCHOOL_LABEL = { [0] = "Physical", [1] = "Holy", [2] = "Fire", [3] = "Nature", [4] = "Frost", [5] = "Shadow", [6] = "Arcane" }

A.DEFAULTS = {
  -- who
  format = "auto",               -- auto / 2v2 / 3v3 / 5v5 / bg
  bgAuto = true,                 -- battlegrounds switch to BG / World by themselves
  mode = "auto",                 -- auto: arenas fill by themselves / strict: only the named players
  worldFill = false,             -- auto mode outside arenas too
  huntTarget = true,             -- no ClassicAPI: find named enemies with a quick target swap before combat
  slots = { {}, {}, {}, {}, {} },-- { name, class, auto }
  detection = "auto",            -- auto (SuperWoW if found) / log
  resetOnZone = true,            -- clear cooldowns on loading screens (new match)
  showWhen = "set",              -- arena / set (arenas + named enemies) / always
  -- frames
  locked = true, pos = nil, scale = 1, alpha = 1, grow = "DOWN", mirror = false, spacing = 12,
  frameH = 48, barW = 170, powerH = 10, barTex = "smooth", classBars = true,
  showName = true, showSpec = true, showNumber = true, hpText = "percent", showEnemyTarget = true,
  nameFont = "pt", fontSize = 13, dimFar = true, trinket = true, racial = true,
  -- cast bar
  cast = true, castH = 16, castIcon = true, castTime = true, castSchool = true, kickMark = true, lockout = true,
  -- auras
  big = true, immuneGlow = true, strip = true, stripMax = 3, dr = true, drSize = 23,
  -- cooldown row
  cdRow = true, cdSize = 24, cdSpacing = 2, cdPerRow = 10, showReady = true, showTalents = true,
  -- interrupt bar (OctoKicks' bar: every enemy's interrupts in one strip)
  intBar = false, intSize = 32, intPerRow = 8, intNames = true, intAll = false, intPos = nil,
  -- BG / World
  bgIconSize = 30, bgRows = 8, bgNames = false, bgDim = true, bgPos = nil,
  -- icon look
  border = "kind", borderPx = 1, shadow = true, sweep = "clock", desat = true, pop = true, unusedAlpha = 0.45,
  -- cooldown numbers
  showText = true, numFont = "pt", numSize = 50, numOutline = "OUTLINE", numPos = "CENTER",
  numFormat = "sec", numDecimals = 3, numColor = "white", soonColor = "yellow", soonAt = 3,
  -- spells: name -> { tier, cd, prio } (only what differs from the game's numbers)
  spells = {},
  learn = true,
  -- alerts
  soundUse = false, soundUseFile = "Whisper", soundReady = false, soundReadyFile = "Ping",
  soundTrinket = false, soundTrinketFile = "RaidWarning", flashReady = true,
  announce = false, announceKicks = false, printChat = false,
}

-- ---------------------------------------------------------------- helpers

local function Copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = Copy(v) end
  return c
end
A.Copy = Copy

local function Merge(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then dst[k] = Copy(v)
    elseif type(v) == "table" and type(dst[k]) == "table" and k ~= "spells" then Merge(dst[k], v) end
  end
end
A.Merge = Merge

function A:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33bbffOctoArenaFrames|r: " .. msg)
end

-- What a player is looked up by. Names in arenas can carry a realm ("Duskfang-NZ")
-- and one source may give it where another does not.
function A.Key(name)
  if not name then return nil end
  local low = string.lower(name)
  local _, _, base = string.find(low, "^(.-)%-%a+$")
  if base and base ~= "" then return base end
  return low
end

-- A name the game really knows, or nil. A player the client has not loaded yet is
-- called "Unknown" (UNKNOWNOBJECT) by UnitName and the cast events: that is not a name.
function A.RealName(name)
  if not name or name == "" then return nil end
  if name == (UNKNOWNOBJECT or "Unknown") or name == "Unknown" or name == UNKNOWNBEING then return nil end
  return name
end

local function Proper(s)
  return string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2))
end

-- "bOB" -> "Bob", "duskfang-nz" -> "Duskfang-NZ" (names typed in the options)
function A.CleanName(s)
  if not s then return nil end
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  if s == "" then return nil end
  local _, _, base, realm = string.find(s, "^(.-)%-(%a+)$")
  if base and base ~= "" then return Proper(base) .. "-" .. string.upper(realm) end
  return Proper(s)
end

local function Pick(list, key)
  for i = 1, table.getn(list) do
    if list[i].key == key then return list[i] end
  end
  return list[1]
end
function A.SoundFile(key) return Pick(A.SOUNDS, key).file end
function A.FontFile(key) return Pick(A.FONTS, key).file end
function A.BarFile(key) return Pick(A.BARS, key).file end
function A.Color(key) return Pick(A.COLORS, key).rgb end

-- Seconds as the Numbers settings say: 75 / 1:15 / 2m, tenths near the end.
function A.FormatTime(left)
  local db = A.db
  if db.numDecimals > 0 and left < db.numDecimals then return string.format("%.1f", left) end
  local s = math.ceil(left)
  if s >= 60 then
    if db.numFormat == "clock" then return string.format("%d:%02d", math.floor(s / 60), math.mod(s, 60)) end
    if db.numFormat == "short" then return math.ceil(s / 60) .. "m" end
  end
  return tostring(s)
end

function A.IsGuid(s)
  return type(s) == "string" and string.sub(s, 1, 2) == "0x"
end

function A.HasSuperWoW()
  return (SUPERWOW_VERSION or (SpellInfo and SetAutoloot)) and true or false
end

function A.UseSW()
  return A.db.detection ~= "log" and A.HasSuperWoW() and SpellInfo ~= nil
end

-- Can a GUID be used as a unit? SuperWoW and ClassicAPI both allow it.
function A.GuidUnits()
  return A.db.detection ~= "log" and (A.HasSuperWoW() or (C_UnitAuras ~= nil and UnitGUID ~= nil))
end

-- The GUID of a token: SuperWoW, nampower or ClassicAPI; nil without any.
function A.GuidOf(unit)
  if not unit then return nil end
  local has, g = UnitExists(unit)
  if not has then return nil end
  if A.IsGuid(g) then return g end
  if GetUnitGUID then
    local ok, g2 = pcall(GetUnitGUID, unit)
    if ok and A.IsGuid(g2) then return g2 end
  end
  if UnitGUID then
    local ok, g3 = pcall(UnitGUID, unit)
    if ok and A.IsGuid(g3) then return g3 end
  end
  return nil
end

-- "arena", "pvp" (battleground), "party", "raid" or "none".
-- IsInInstance says "pvp" in this server's arenas, so the zone name decides; ClassicAPI's
-- IsActiveBattlefieldArena may know before the name catches up (not seen in game).
function A.ZoneKind()
  if not IsInInstance then return "none" end
  local _, kind = IsInInstance()
  kind = kind or "none"
  if kind == "arena" then return "arena" end
  if kind == "pvp" then
    if A.ARENAS[GetRealZoneText() or ""] then return "arena" end
    if IsActiveBattlefieldArena then
      local ok, isArena = pcall(IsActiveBattlefieldArena)
      if ok and isArena then return "arena" end
    end
  end
  return kind
end
function A:InArena() return self.zone == "arena" end

-- The format in use: battlegrounds switch to BG / World when bgAuto is on, and
-- an arena is never BG / World whatever the setting says.
function A:Format()
  if self.zone == "arena" then
    if self.db.format == "bg" then return "auto" end
    return self.db.format
  end
  if self.db.bgAuto and self.zone == "pvp" then return "bg" end
  return self.db.format
end
function A:IsBG() return self:Format() == "bg" end

-- How many frames: a fixed format that many; auto = your own team's size in an
-- arena (they have as many as you), or as many as are known.
function A:Max()
  local f = self:Format()
  for i = 1, table.getn(A.FORMATS) do
    if A.FORMATS[i][1] == f and A.FORMATS[i][3] > 0 then return A.FORMATS[i][3] end
  end
  if self.test then return self.testMax or 3 end
  local known = self:SlotCount(A.MAX)
  if self.zone == "arena" then
    -- what the server says the other team is, else as many as your own
    local own = self.scoreSize or self:OwnTeamSize()
    if own > A.MAX then own = A.MAX end
    if known > own then return known end
    return own
  end
  return known
end

function A.FormatLabel(f)
  for i = 1, table.getn(A.FORMATS) do
    if A.FORMATS[i][1] == f then return A.FORMATS[i][2] end
  end
  return f
end

-- ---------------------------------------------------------------- spells

A.BYNAME = {}
A.GROUPS = {}     -- class -> shared cooldown group -> spells
A.BYCLASS = {}    -- class -> spells in row order
for i = 1, table.getn(A.SPELLS) do
  local s = A.SPELLS[i]
  s.texture = "Interface\\Icons\\" .. s.i
  A.BYNAME[s.n] = s
  if not A.BYCLASS[s.c] then A.BYCLASS[s.c] = {} end
  table.insert(A.BYCLASS[s.c], s)
  if s.g then
    if not A.GROUPS[s.c] then A.GROUPS[s.c] = {} end
    if not A.GROUPS[s.c][s.g] then A.GROUPS[s.c][s.g] = {} end
    table.insert(A.GROUPS[s.c][s.g], s)
  end
end
for _, list in pairs(A.BYCLASS) do
  table.sort(list, function(a, b)
    local ka, kb = KIND_ORDER[a.k] or 99, KIND_ORDER[b.k] or 99
    if ka ~= kb then return ka < kb end
    return a.n < b.n
  end)
end

-- Race token -> its racial (the "RACE:Orc" class names of the spell data).
A.RACIAL = {}
for i = 1, table.getn(A.SPELLS) do
  local _, _, race = string.find(A.SPELLS[i].c, "^RACE:(.+)$")
  if race then A.RACIAL[race] = A.SPELLS[i] end
end
A.TRINKET = A.BYNAME["Insignia"]

-- Cooldown resets, from each spell's own description in the game's table.
A.RESETS = {
  ["Cold Snap"] = function(s) return s.c == "MAGE" and s.sc == 4 and s.n ~= "Cold Snap" end,
  ["Preparation"] = function(s) return s.c == "ROGUE" and s.n ~= "Preparation" end,
  ["Readiness"] = function(s)
    return s.c == "HUNTER" and (s.n == "Deterrence" or s.n == "Feign Death" or string.find(s.n, " Trap$") ~= nil)
  end,
}

-- per-spell settings (the options override the spell data)
local function Opt(s) return A.db.spells[s.n] or {} end
-- 1 always shown, 2 shown while on cooldown, 0 off
function A.SpellTier(s) local o = Opt(s) if o.tier ~= nil then return o.tier end return s.t end
function A.SpellOn(s) return A.SpellTier(s) ~= 0 end
function A.SpellCD(s) return Opt(s).cd or s.cd end
function A.SpellPrio(s)
  local o = Opt(s)
  if o.prio ~= nil then return o.prio end
  return s.k == "interrupt" or s.k == "silence"
end
function A.SetSpell(name, key, value)
  local t = A.db.spells[name] or {}
  t[key] = value
  A.db.spells[name] = t
end

-- A spell id or name from anything that speaks to us -> our spell, or nil.
function A.SpellOf(id, name)
  if id and A.IDS[id] then return A.BYNAME[A.IDS[id]] end
  if name then return A.BYNAME[name] end
  return nil
end

-- ---------------------------------------------------------------- the event bus

local ev = CreateFrame("Frame", "OctoArenaFramesEvents")
A.events = ev
A.handlers = {}

function A:On(event, fn)
  if not self.handlers[event] then
    self.handlers[event] = {}
    ev:RegisterEvent(event)
  end
  table.insert(self.handlers[event], fn)
end

A.errors = {}
ev:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then A:Init() end
  if not A.db then return end
  -- while someone is still missing, anything that carries a GUID may name them
  local seen = A.hunting and A.huntFns and A.huntFns[event]
  if seen then
    local ok, err = pcall(seen, arg1, arg2, arg3, arg4)
    if not ok and table.getn(A.errors) < 30 then table.insert(A.errors, tostring(event) .. ": " .. tostring(err)) end
  end
  local list = A.handlers[event]
  if not list then return end
  for i = 1, table.getn(list) do
    local ok, err = pcall(list[i], arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    if not ok and table.getn(A.errors) < 30 then table.insert(A.errors, tostring(event) .. ": " .. tostring(err)) end
  end
end)
ev:RegisterEvent("VARIABLES_LOADED")

-- ---------------------------------------------------------------- changes

-- Something the frames show changed.
function A:Changed()
  self.dirty = true
  if self.Frames then self.Frames:Refresh() end
  if self.Bars then self.Bars:Refresh() end
  if self.Options and self.Options.Refresh then self.Options:Refresh() end
end

-- Badge text and colour.
function A:StatusText()
  if self.test then return "TEST  " .. A.FormatLabel(self:Format()), 0.75, 0.45, 1 end
  if self:IsBG() then return "BG / WORLD", 0.55, 0.82, 1 end
  local n, max = self:SlotCount(), self:Max()
  local fmt = A.FormatLabel(self:Format())
  if self.db.mode == "auto" then return "AUTO  " .. fmt .. "  " .. n .. "/" .. max, 1, 0.7, 0.1 end
  if n == max and max > 0 then return "STRICT  " .. fmt .. "  " .. n .. "/" .. max, 0.2, 0.9, 0.3 end
  return "STRICT  " .. fmt .. "  " .. n .. "/" .. max, 1, 0.3, 0.2
end

function A:DetectionText()
  if A.UseSW() then return "SuperWoW found: exact tracking by player ID." end
  if A.HasSuperWoW() then return "Combat log (chosen below)." end
  return "No SuperWoW: reading the combat log (by name). Health shows only for your target and mouseover."
end

-- ---------------------------------------------------------------- zones

-- Called on loading screens and zone changes. On the way into an arena the zone
-- name is still the old one for half a second, so it is asked again shortly after.
function A:CheckZone()
  local kind = A.ZoneKind()
  local g = A.GuidOf("player")
  if g then self.myGuid = g end    -- the server gives you another GUID inside a match
  if kind == self.zone then return end
  self.zone = kind
  self:NewZone(kind)
end

function A:NewZone(kind)
  if self.test then self:SetTest(false) end
  self:ResetMatch()
  self:EndMatch()
  self.foundAt = nil
  if kind == "arena" then
    self:StartMatch()
    self:NampowerEvents()
    -- the server's answer may have come while the zone name was still the old one
    if self.heldRoster and GetTime() - (self.heldAt or 0) < 5 then
      local held = self.heldRoster
      self.heldRoster = nil
      self:OnArenaMessage(held)
    end
    self:Scan(true)
  end
  self.heldRoster = nil
  if kind == "arena" and self.db.mode == "strict" and self:SlotCount() < self:Max() then
    self:Print("|cffff5533strict " .. A.FormatLabel(self:Format()) .. " has only " .. self:SlotCount() .. "/"
      .. self:Max() .. " enemies set|r - type /oaf to set them.")
  end
  self:Changed()
end

A:On("PLAYER_ENTERING_WORLD", function()
  A.zoneChecks = 3
  A.zoneCheckAt = GetTime() + 0.6
  A.zone = A.zone or A.ZoneKind()
  local was = A.zone
  A:CheckZone()
  -- a loading screen from one match to the next can keep the same kind
  if was == A.zone and A.db.resetOnZone then A:ResetMatch() A:Changed() end
end)
A:On("ZONE_CHANGED_NEW_AREA", function() A:CheckZone() end)

-- ---------------------------------------------------------------- ticking

-- One OnUpdate for the whole addon. What runs how often:
--   every frame  cast bars (only enemies casting), pop and shrink animations
--   20 a second  health, power, states
--   10 a second  cooldown numbers, cooldowns coming back
--    5 a second  auras (at once when nampower says one changed)
--    4 a second  enemy's target, range, finding enemies (stops once all are found)
local a20, a10, a5, a4 = 0, 0, 0, 0

function A:OnFrame(e)
  a20, a10, a5, a4 = a20 + e, a10 + e, a5 + e, a4 + e
  local now = GetTime()
  if self.zoneChecks and self.zoneChecks > 0 and now >= self.zoneCheckAt then
    self.zoneChecks = self.zoneChecks - 1
    self.zoneCheckAt = now + 1.5
    self:CheckZone()
  end
  if self.Frames then self.Frames:OnFrame(now) end
  if a20 >= 0.05 then
    a20 = 0
    if self.Frames then self.Frames:Fast(now) end
  end
  if a10 >= 0.1 then
    a10 = 0
    self:Tick(now)
    if self.Frames then self.Frames:Numbers(now) end
    if self.Bars then self.Bars:Update(now) end
  end
  if a5 >= 0.2 then
    a5 = 0
    if self.AuraTick then self:AuraTick(now) end
  end
  if a4 >= 0.25 then
    a4 = 0
    if self.Scan then self:Scan() end
    if self.Frames then self.Frames:Slow(now) end
  end
end

ev:SetScript("OnUpdate", function()
  if A.db then A:OnFrame(arg1 or 0) end
end)

-- ---------------------------------------------------------------- start

function A:Init()
  if self.db then return end
  if type(OctoArenaDB) ~= "table" then OctoArenaDB = {} end
  if type(OctoArenaGlobal) ~= "table" then OctoArenaGlobal = {} end
  local fresh = OctoArenaDB.format == nil
  Merge(OctoArenaDB, A.DEFAULTS)
  self.db = OctoArenaDB
  self.global = OctoArenaGlobal
  if type(self.global.profiles) ~= "table" then self.global.profiles = {} end
  if type(self.global.learned) ~= "table" then self.global.learned = {} end
  if type(self.global.seen) ~= "table" then self.global.seen = {} end
  for i = 1, A.MAX do
    if type(self.db.slots[i]) ~= "table" then self.db.slots[i] = {} end
  end
  self.zone = A.ZoneKind()
  self:BuildEnemies()
  if self.RegisterLog then self:RegisterLog() end
  if self.Frames then self.Frames:Build() end
  if self.Bars then self.Bars:Build() end
  if self.Options and self.Options.MenuButton then self.Options:MenuButton() end
  if self.ImportOctoKicks then self:ImportOctoKicks() end
  if fresh then self.firstRun = true end
  self:Changed()
end

-- ---------------------------------------------------------------- profiles

-- Layout, numbers, spells and alerts (not the enemies or the format).
A.PROFILE_SKIP = { slots = true, mode = true, format = true }

function A:SaveProfile(name)
  name = name and string.gsub(name, "^%s*(.-)%s*$", "%1")
  if not name or name == "" then return false end
  local p = {}
  for k, v in pairs(self.db) do
    if not A.PROFILE_SKIP[k] then p[k] = Copy(v) end
  end
  self.global.profiles[name] = p
  return true
end

function A:LoadProfile(name)
  local p = self.global.profiles[name]
  if not p then return false end
  for k, v in pairs(p) do
    if not A.PROFILE_SKIP[k] then self.db[k] = Copy(v) end
  end
  Merge(self.db, A.DEFAULTS)
  if self.RegisterLog then self:RegisterLog() end
  if self.Frames then self.Frames:Place() end
  if self.Bars then self.Bars:Place() end
  self:Changed()
  return true
end

function A:ResetLayout()
  for k, v in pairs(A.DEFAULTS) do
    if not A.PROFILE_SKIP[k] and k ~= "bgAuto" and k ~= "detection" and k ~= "learn" then self.db[k] = Copy(v) end
  end
  if self.RegisterLog then self:RegisterLog() end
  if self.Frames then self.Frames:Place() end
  if self.Bars then self.Bars:Place() end
  self:Changed()
end

-- ---------------------------------------------------------------- slash

-- /oaf target 2, /oaf focus 1, /oaf kick 3, /oaf cast 2 Polymorph: for macros.
SLASH_OCTOARENAFRAMES1 = "/oaf"
SLASH_OCTOARENAFRAMES2 = "/octoarena"
SlashCmdList["OCTOARENAFRAMES"] = function(msg)
  if not A.db then return end
  local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  if cmd == "" or cmd == "options" then
    A.Options:Toggle()
  elseif cmd == "test" and string.lower(rest or "") == "full" then
    if A.testFull then A:SetTest(false) else A:SetTest(true, true) end
  elseif cmd == "test" then
    A:SetTest(not A.test)
  elseif cmd == "reset" then
    A.db.pos, A.db.bgPos, A.db.intPos = nil, nil, nil
    A.db.locked = false
    A.Frames:Place()
    A.Bars:Place()
    A:Changed()
    A:Print("frames moved back and unlocked.")
  elseif cmd == "lock" then
    A.db.locked = not A.db.locked
    A:Changed()
  elseif cmd == "strict" or cmd == "auto" then
    A.db.mode = cmd
    A:Changed()
    A:Print("mode: " .. cmd .. ".")
  elseif cmd == "2v2" or cmd == "3v3" or cmd == "5v5" or cmd == "bg" then
    A:SetFormat(cmd)
    A:Print("format: " .. A.FormatLabel(cmd) .. ".")
  elseif cmd == "set" and tonumber(rest) and tonumber(rest) >= 1 and tonumber(rest) <= A.MAX then
    A:SetFromTarget(tonumber(rest))
  elseif cmd == "clear" then
    A:ClearSlots()
  elseif cmd == "target" and tonumber(rest) then
    A:TargetEnemy(tonumber(rest))
  elseif cmd == "focus" and tonumber(rest) then
    A:FocusEnemy(tonumber(rest))
  elseif cmd == "kick" and tonumber(rest) then
    A:KickEnemy(tonumber(rest))
  elseif cmd == "cast" then
    local _, _, n, spell = string.find(rest or "", "^(%d+)%s+(.+)$")
    if n then A:CastAtEnemy(tonumber(n), spell) end
  elseif cmd == "log" then
    -- how the last match's enemies were found, and when (seconds after entering)
    local m = A.global.arenaLog and A.global.arenaLog[1]
    if not m then
      A:Print("no arena played yet.")
    else
      A:Print("last arena: " .. tostring(m.zone) .. ", " .. tostring(m.when))
      for i = 1, table.getn(m.log) do DEFAULT_CHAT_FRAME:AddMessage(m.log[i]) end
    end
  elseif cmd == "errors" then
    if table.getn(A.errors) == 0 then A:Print("no errors.") end
    for i = 1, table.getn(A.errors) do A:Print(A.errors[i]) end
  elseif cmd == "probe" then
    A:Print("zone " .. tostring(GetRealZoneText()) .. ", kind " .. tostring(A.zone) .. ", format " .. A:Format()
      .. ", my GUID " .. tostring(A.myGuid))
    A:Print(A:DetectionText())
    A:Print(A:RosterText() .. (A.hunting and " (still looking)" or ""))
    for i = 1, A.MAX do
      local e = A.enemies[i]
      if e.name then
        A:Print(i .. ": " .. e.name .. " " .. tostring(e.class) .. " " .. tostring(e.race) .. " " .. tostring(e.guid)
          .. (e.unit and " in sight" or " out of sight"))
      end
    end
  else
    A:Print(A.FormatLabel(A:Format()) .. ", mode " .. A.db.mode .. ". " .. A:DetectionText())
    for i = 1, A.MAX do
      local s = A.db.slots[i]
      if s.name then A:Print("Enemy " .. i .. ": " .. s.name .. " " .. (s.class or "")) end
    end
    A:Print("/oaf - options, test, test full, lock, reset, 2v2, 3v3, 5v5, bg, strict, auto, set 1-5 (from target), clear, probe, log, errors")
    A:Print("macros: /oaf target 1, /oaf focus 2, /oaf kick 3, /oaf cast 2 Polymorph")
  end
end

-- Key bindings (Bindings.xml).
BINDING_HEADER_OCTOARENAFRAMES = "OctoArenaFrames"
for i = 1, A.MAX do
  setglobal("BINDING_NAME_OCTOARENA_TARGET" .. i, "Target enemy " .. i)
  setglobal("BINDING_NAME_OCTOARENA_FOCUS" .. i, "Focus enemy " .. i)
  setglobal("BINDING_NAME_OCTOARENA_KICK" .. i, "Interrupt enemy " .. i)
end
