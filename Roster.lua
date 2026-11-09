-- OctoArenaFrames :: who the enemies are
-- 1.12 has no arena1..5 units. Enemies come from the server's team list and every GUID
-- the client hears of (Arena.lua). Once in a slot an enemy stays in that slot for the
-- whole match, so "Enemy 2" always means the same player and a key bound to it never
-- changes hands. Scanning stops as soon as every slot is found.

local A = OctoArenaFrames

local function NewEnemy(i)
  return { i = i, cds = {}, seen = {}, flash = {}, dr = {}, auras = {}, strip = {} }
end
A.NewEnemy = NewEnemy

function A:BuildEnemies()
  self.enemies, self.byGuid, self.byName = {}, {}, {}
  for i = 1, A.MAX do
    local e = NewEnemy(i)
    local s = self.db.slots[i]
    e.name, e.class, e.auto = s.name, s.class, s.auto
    if s.name then self.byName[A.Key(s.name)] = e end
    self.enemies[i] = e
  end
  self.testEnemies = {}
  self.bg, self.testBg = {}, {}
  self.rejected, self.nrej = {}, 0
  self.ignored = 0
end

function A:Enemies()
  if self.test then return self.testEnemies end
  return self.enemies
end

function A:BGUnits()
  if self.test then return self.testBg end
  return self.bg
end

function A:SlotCount(limit)
  limit = limit or self:Max()
  local n, list = 0, self:Enemies()
  for i = 1, limit do
    if list[i] and list[i].name then n = n + 1 end
  end
  return n
end

-- Everything known about what an enemy is doing, gone (names stay).
local function ClearCombat(e)
  e.cds, e.seen, e.flash, e.dr, e.auras, e.strip = {}, {}, {}, {}, {}, {}
  e.cast, e.castEnd, e.lockout, e.lastCast = nil, nil, nil, nil
  e.big, e.immune, e.stealth, e.feign, e.dead = nil, nil, nil, nil, nil
  e.targetName, e.targetClass, e.onMe = nil, nil, nil
  e.unit, e.hp, e.hpMax, e.mana, e.manaMax, e.power = nil, nil, nil, nil, nil, nil
  e.known = nil
  e.far = nil
end
A.ClearCombat = ClearCombat

function A:SetSlot(i, name, class, auto)
  if not auto then name = A.CleanName(name) end    -- typed; the game's own spelling stays as it is
  local slot, e = self.db.slots[i], self.enemies[i]
  if slot.name ~= name then
    if e.guid then self.byGuid[e.guid] = nil end
    if e.name then self.byName[A.Key(e.name)] = nil end
    self.enemies[i] = NewEnemy(i)
    e = self.enemies[i]
  end
  slot.name, slot.class, slot.auto = name, name and class or nil, name and auto or nil
  e.name, e.class, e.auto = slot.name, slot.class, slot.auto
  if name then self.byName[A.Key(name)] = e end
  self:Changed()
end

function A:ClearSlots()
  for i = 1, A.MAX do self.db.slots[i] = {} end
  self.enemies, self.byGuid, self.byName = {}, {}, {}
  for i = 1, A.MAX do self.enemies[i] = NewEnemy(i) end
  self:Changed()
end

function A:ResetCooldowns()
  for i = 1, A.MAX do
    local e = self.enemies[i]
    e.cds, e.flash = {}, {}
  end
  self.bg = {}
  self:Changed()
end

function A:SetFormat(f)
  self.db.format = f
  if self.test then self:SetTest(true) end   -- sample enemies for the new size
  self:Changed()
end

-- A new match: auto-filled enemies go, named ones stay. GUIDs are not kept (the
-- server hands out new ones per match).
function A:ResetMatch()
  self.bg = {}
  self.rejected, self.nrej = {}, 0
  self.scoreSize, self.lastRoster, self.askNext = nil, nil, nil
  self.byGuid = {}
  for i = 1, A.MAX do
    local slot, e = self.db.slots[i], self.enemies[i]
    if slot.auto then
      self.db.slots[i] = {}
      if e.name then self.byName[A.Key(e.name)] = nil end
      self.enemies[i] = NewEnemy(i)
    else
      e.guid, e.petName = nil, nil
      if self.db.resetOnZone then ClearCombat(e) end
    end
  end
  self:RebuildFriends()
end

-- Fills slot i from your target (any player, so a friendly duel works for practice).
function A:SetFromTarget(i)
  if not UnitExists("target") or not UnitIsPlayer("target") then
    self:Print("target a player first.")
    return
  end
  local _, class = UnitClass("target")
  self:SetSlot(i, UnitName("target"), class)
  local g = A.GuidOf("target")
  if g then self:Bind(self.enemies[i], g) end
end

-- ---------------------------------------------------------------- teammates

function A:RebuildFriends()
  local f, players = {}, 0
  local g = A.GuidOf("player")
  if g then
    f[g] = true
    self.myGuid = g
    players = 1
  end
  local nr = GetNumRaidMembers and GetNumRaidMembers() or 0
  if nr > 0 then
    for i = 1, nr do
      g = A.GuidOf("raid" .. i)
      if g then
        if not f[g] then players = players + 1 end
        f[g] = true
      end
      g = A.GuidOf("raidpet" .. i)
      if g then f[g] = true end
    end
  else
    for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
      g = A.GuidOf("party" .. i)
      if g then
        f[g] = true
        players = players + 1
      end
      g = A.GuidOf("partypet" .. i)
      if g then f[g] = true end
    end
  end
  g = A.GuidOf("pet")
  if g then f[g] = true end
  self.friends, self.friendsN = f, players
end

-- Is your whole group known, a moment after entering? Only then can "not on my team"
-- mean anything: the group's data arrives after the loading screen.
function A:GroupSettled()
  if not self.match or GetTime() - self.match.start < 2 then return false end
  local own = self:OwnTeamSize()
  return own > 1 and (self.friendsN or 0) >= own
end
A:On("PARTY_MEMBERS_CHANGED", function() A:RebuildFriends() end)
A:On("RAID_ROSTER_UPDATE", function() A:RebuildFriends() end)

-- ---------------------------------------------------------------- slots

-- Remember this enemy's GUID, class and race; they are read while the unit exists.
function A:Bind(e, guid)
  if e.guid and e.guid ~= guid then self.byGuid[e.guid] = nil end
  e.guid = guid
  self.byGuid[guid] = e
  self:ReadIdentity(e, guid)
end

function A:ReadIdentity(e, unit)
  if not UnitExists(unit) then return end
  local _, class = UnitClass(unit)
  if class and e.class ~= class then
    e.class = class
    self.dirty = true
    if not self.test and self.db.slots[e.i].name then self.db.slots[e.i].class = class end
  end
  if UnitRace then
    local _, race = UnitRace(unit)
    if race and e.race ~= race then
      e.race = race
      self.dirty = true
    end
  end
end

function A:FindSlot(name, guid)
  if guid and self.byGuid[guid] then return self.byGuid[guid] end
  local e = name and self.byName[A.Key(name)]
  if e and guid then self:Bind(e, guid) end
  return e
end

-- The one slot with this class, or nil when none or more than one (no guessing).
function A:FindByClass(class)
  local found
  for i = 1, self:Max() do
    local e = self.enemies[i]
    if e.name and e.class == class then
      if found then return nil end
      found = e
    end
  end
  return found
end

function A:FindByPet(petName)
  if not petName then return nil end
  for i = 1, self:Max() do
    local e = self.enemies[i]
    if e.name and e.petName == petName then return e end
  end
  return nil
end

function A:MayFill()
  if self.test or self:IsBG() or self.db.mode ~= "auto" then return false end
  return self.zone == "arena" or self.db.worldFill
end

-- The first free slot takes this enemy; a fixed format's slots lock when full.
function A:AutoFill(name, guid, class)
  name = A.RealName(name)
  if not name or not self:MayFill() then return nil end
  local cap = A.MAX
  local f = self:Format()
  if f == "2v2" then cap = 2 elseif f == "3v3" then cap = 3 elseif f == "5v5" then cap = 5 end
  for i = 1, cap do
    if not self.db.slots[i].name then
      self:SetSlot(i, name, class, true)
      local e = self.enemies[i]
      if guid then self:Bind(e, guid) end
      if self.db.printChat then self:Print("Enemy " .. i .. " is " .. e.name .. ".") end
      return e
    end
  end
  return nil
end

-- All slots of this match filled, each with its GUID (or no way to get one)?
function A:RosterFull()
  local max = self:Max()
  if max == 0 then return false end
  local ids = A.GuidUnits()
  for i = 1, max do
    local e = self.enemies[i]
    if not e.name or (ids and not e.guid) then return false end
  end
  return true
end

local function Reject(self, guid)
  self.rejected[guid] = true
  self.nrej = self.nrej + 1
  if self.nrej > 500 then self.rejected, self.nrej = {}, 0 end
end

-- A GUID seen anywhere. Returns its enemy, finding it a slot when it may have one.
-- Who counts as an enemy, best evidence first: the server's team list; "can attack";
-- and in an arena, once your group is known, anyone who is not on your team (the gates
-- may keep the other team unattackable until they open). That last one is a guess the
-- server's list overrules.
function A:Consider(guid, src)
  if not guid then return nil end
  local e = self.byGuid[guid]
  if e then return e end
  if self.rejected[guid] or guid == self.myGuid then return nil end
  if self:IsBG() or not A.IsGuid(guid) or not UnitExists(guid) then return nil end
  local player = UnitIsPlayer(guid)
  local name = player and A.RealName(UnitName(guid))   -- "Unknown" until loaded: asked again later
  -- a named player counts even when friendly: a duel with a teammate is practice
  e = name and self:FindSlot(name, guid)
  if e then
    self:Log("id", e.name .. " from " .. tostring(src or "a cast"))
    return e
  end
  if not player or (self.friends and self.friends[guid]) then
    Reject(self, guid)
    return nil
  end
  if not name then return nil end
  local key = A.Key(name)
  if self.teamAlly and self.teamAlly[key] then
    Reject(self, guid)
    return nil
  end
  local attackable = UnitCanAttack("player", guid) and true or false
  if self.match and self.sighted and not self.sighted[key] then
    self.sighted[key] = true       -- first sight: can they be attacked yet? the log tells
    self:Log("seen", name .. " by " .. tostring(src or "a cast") .. ", can attack: " .. tostring(attackable)
      .. ", enemy: " .. tostring(UnitIsEnemy and UnitIsEnemy("player", guid) and true or false))
  end
  local yes
  if self.teamEnemy then
    yes = self.teamEnemy[key] or (attackable and not self.teamComplete)
  else
    yes = attackable or (self.zone == "arena" and self:GroupSettled() and self:SlotCount(A.MAX) < self:Max())
  end
  if not yes then return nil end     -- asked again later
  local _, class = UnitClass(guid)
  e = self:AutoFill(name, guid, class)
  if e then self:Log("named", name .. " in slot " .. e.i .. " from " .. tostring(src or "a cast")) end
  return e
end

-- A unit token: without GUIDs it still names an enemy and shows their class.
function A:ConsiderToken(unit)
  if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
  local g = A.GuidOf(unit)
  if g and A.GuidUnits() then
    self:Consider(g, unit)
    return
  end
  local name = A.RealName(UnitName(unit))
  if not name or name == UnitName("player") then return end
  local key = A.Key(name)
  local e = self:FindSlot(name)
  if not e and not (self.teamAlly and self.teamAlly[key]) then
    local yes
    if self.teamEnemy then yes = self.teamEnemy[key] else yes = UnitCanAttack("player", unit) end
    if yes then
      local _, class = UnitClass(unit)
      e = self:AutoFill(name, nil, class)
    end
  end
  if e then self:ReadIdentity(e, unit) end
end

local TOKENS = { "target", "mouseover", "targettarget", "pettarget", "party1target", "party2target", "party3target", "party4target" }

-- The unit to read an enemy through: its GUID in sight, else a token showing them.
function A:UnitOf(e)
  if e.fake or not e.name then return nil end
  if e.guid and A.GuidUnits() then
    if UnitExists(e.guid) then return e.guid end
    return nil
  end
  local key = A.Key(e.name)
  for i = 1, table.getn(TOKENS) do
    local t = TOKENS[i]
    if UnitExists(t) and A.Key(UnitName(t)) == key then return t end
  end
  return nil
end

-- Every 0.25 s until the roster is complete, from the moment you are in the arena;
-- nameplates once a second. Once everyone is found none of this runs.
local nextPlates = 0
function A:Scan(force)
  if self.test or self:IsBG() then
    self:SetHunting(false)
    return
  end
  local now = GetTime()
  if self.zone == "arena" then
    if not self.match then      -- a /reload inside an arena
      self:StartMatch()
      self:NampowerEvents()
    end
    self:AskRoster(now)
  end
  local inPlay = self:MayFill() or self:SlotCount(A.MAX) > 0
  local full = self:RosterFull()
  self:SetHunting(inPlay and not full)
  if not inPlay or full then return end
  if self.zone == "arena" then self:RebuildFriends() end
  self:ResolveNames()
  for i = 1, table.getn(TOKENS) do self:ConsiderToken(TOKENS[i]) end
  if force or now >= nextPlates then
    nextPlates = now + 1
    self:ScanPlates()
    self.rejected, self.nrej = {}, 0
  end
  self:TargetSweep(now)
  full = self:RosterFull()
  if full then self:SetHunting(false) end
end

-- ---------------------------------------------------------------- test mode

local SAMPLES = {
  { name = "Frostmage", class = "MAGE", race = "Gnome" },
  { name = "Sneaky", class = "ROGUE", race = "NightElf" },
  { name = "Holyfist", class = "PRIEST", race = "Dwarf" },
  { name = "Felguy", class = "WARLOCK", race = "Human" },
  { name = "Bashface", class = "WARRIOR", race = "Orc" },
}
A.BG_SAMPLES = {
  { "Kicky", "ROGUE" }, { "Blinker", "MAGE" }, { "Shocker", "SHAMAN" }, { "Pummler", "WARRIOR" },
  { "Darkpriest", "PRIEST" }, { "Felbound", "WARLOCK" }, { "Moonbear", "DRUID" }, { "Stabbs", "ROGUE" },
}
local TEST_TIME = 60

-- Sample enemies (your real named ones where set) that play out casts, crowd
-- control, cooldowns and diminishing returns, so everything can be set up anywhere.
-- Never announces or plays sounds. The quick test ends on its own after a minute;
-- the full test (full = true) runs until stopped, fills every slot when the format
-- is auto, and also plays interrupts with school lockouts, trinkets and racials.
function A:SetTest(on, full)
  if on then
    self.testEnemies = {}
    for i = 1, A.MAX do
      local e = NewEnemy(i)
      local real = self.db.slots[i]
      if real.name and real.class then
        e.name, e.class, e.race = real.name, real.class, "Human"
      else
        e.name, e.class, e.race = SAMPLES[i].name, SAMPLES[i].class, SAMPLES[i].race
      end
      e.fake = true
      e.hp, e.hpMax, e.mana, e.manaMax, e.power = 60 + i * 7, 100, 80 - i * 9, 100, 0
      if e.class == "ROGUE" then e.power = 3 end
      if e.class == "WARRIOR" then e.power = 1 end
      self.testEnemies[i] = e
    end
    self.testBg = {}
    if full then
      self.testEnds = nil
    elseif not self.test or self.testFull then
      self.testEnds = GetTime() + TEST_TIME
    end
    self.testFull = full and true or nil
    self.testNext = GetTime() + 0.3
    local f = self.db.format
    self.testMax = (f == "2v2" and 2) or (f == "3v3" and 3) or (f == "5v5" and 5) or (full and A.MAX) or 3
  else
    self.testFull = nil
  end
  self.test = on and true or nil
  self:Changed()
end
