-- OctoArenaFrames :: knowing the enemy team from the moment you enter
-- All of this runs from the loading screen on, before the gates open:
--
--   1. WHO: the server's own arena scoreboard, the one the game's score window uses
--      (patch-4 Turtle_ArenaUI.lua + WorldStateFrame.lua). RequestArenaScoreInfo() sends
--      TW_ARENA "C2S_SCOREBOARD"; the answer is an addon message
--        S2C_SCOREBOARD;<winner>;<count>;Name|team|x:Name|team|x:...
--      Your own row says which team is yours, so every other team's row is an enemy.
--      This is exact: no guessing from factions, which can be the same on both sides.
--   2. CLASS, RACE: GetBattlefieldScore, by name.
--   3. WHICH UNIT: ClassicAPI's UnitTokenFromName(name, true) searches every loaded unit
--      and gives back a token or the GUID. Failing that: every nampower event that
--      carries a GUID (a buff in the prep room is enough), SuperWoW's casts, nameplates,
--      your team's targets. Clients with neither DLL: a quick target swap before combat.
--
-- Nothing here is taken on faith: every step is written to OctoArenaGlobal.arenaLog
-- (/oaf log), so one played match shows what this server really answered and when.

local A = OctoArenaFrames

local MAX_LOG_MATCHES = 8
local MAX_LOG_LINES = 80

-- plain split: the client's explode() is not ours to rely on
local function Split(s, sep)
  local out, n, from = {}, 0, 1
  if not s or s == "" then return out end
  while true do
    local at = string.find(s, sep, from, true)
    n = n + 1
    if not at then
      out[n] = string.sub(s, from)
      return out
    end
    out[n] = string.sub(s, from, at - 1)
    from = at + 1
  end
end
A.Split = Split

-- ---------------------------------------------------------------- the match log

function A:Log(kind, text)
  local m = self.match
  if not m or table.getn(m.log) >= MAX_LOG_LINES then return end
  table.insert(m.log, string.format("%.1f %s %s", GetTime() - m.start, kind, tostring(text or "")))
end

function A:StartMatch()
  local g = self.global
  if type(g.arenaLog) ~= "table" then g.arenaLog = {} end
  self.match = { start = GetTime(), zone = GetRealZoneText(), when = date and date("%d %b %H:%M") or "", log = {} }
  table.insert(g.arenaLog, 1, self.match)
  while table.getn(g.arenaLog) > MAX_LOG_MATCHES do table.remove(g.arenaLog) end
  self.askNext, self.teamEnemy, self.teamAlly, self.teamComplete, self.lastRoster = nil, nil, nil, nil, nil
  self.scoreInfo, self.scoreSize, self.factionTried = nil, nil, nil
  self.sweepNext, self.sighted = nil, {}
  self:Log("enter", tostring(self.match.zone) .. " group " .. self:OwnTeamSize()
    .. " UnitTokenFromName " .. (UnitTokenFromName and "yes" or "no")
    .. " SuperWoW " .. (A.HasSuperWoW() and "yes" or "no")
    .. " nampower " .. (GetNampowerVersion and "yes" or "no"))
end

function A:EndMatch()
  self.match = nil
  self.teamEnemy, self.teamAlly, self.teamComplete, self.lastRoster, self.scoreInfo = nil, nil, nil, nil, nil
  self:SetHunting(false)
end

function A:OwnTeamSize()
  local own = 1 + (GetNumPartyMembers and GetNumPartyMembers() or 0)
  local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
  if raid > own then own = raid end
  return own
end

-- One line on how this match's finding is going.
function A:RosterText()
  if self.zone ~= "arena" or not self.match then return "Not in an arena." end
  local named, withId, list = 0, 0, self.enemies
  for i = 1, A.MAX do
    if list[i].name then
      named = named + 1
      if list[i].guid then withId = withId + 1 end
    end
  end
  return named .. " enemies named, " .. withId .. " with an ID"
    .. (self.teamEnemy and ", team list from the server" or ", no list from the server yet")
    .. (self.foundAt and string.format(", complete after %.1f s", self.foundAt) or "")
end

-- ---------------------------------------------------------------- 1. the server's list

function A:AskRoster(now)
  if self.zone ~= "arena" or not self.match then return end
  if self.askNext and now < self.askNext then return end
  local age = now - self.match.start
  -- every second until the whole other team has arrived, then rarely
  if self.teamComplete or age > 180 then self.askNext = now + 15 else self.askNext = now + 1 end
  if RequestArenaScoreInfo then
    pcall(RequestArenaScoreInfo)
  elseif SendAddonMessage then
    pcall(SendAddonMessage, "TW_ARENA", "C2S_SCOREBOARD", "GUILD")
  end
  if SetBattlefieldScoreFaction and not self.factionTried then
    self.factionTried = true
    pcall(SetBattlefieldScoreFaction, nil)     -- every row, not one side's
  end
  if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
end

-- Which team is yours: your own row, else a row of someone in your group.
local function MyTeam(self, rows)
  local me = A.Key(UnitName("player"))
  for i = 1, table.getn(rows) do
    if rows[i].key == me then return rows[i].team end
  end
  local tokens = {}
  for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do table.insert(tokens, "party" .. i) end
  for i = 1, (GetNumRaidMembers and GetNumRaidMembers() or 0) do table.insert(tokens, "raid" .. i) end
  for t = 1, table.getn(tokens) do
    local k = A.Key(UnitName(tokens[t]))
    for i = 1, table.getn(rows) do
      if k and rows[i].key == k then return rows[i].team end
    end
  end
  return nil
end

function A:OnArenaMessage(msg)
  local fields = Split(msg, ADDON_MSG_FIELD_DELIMITER or ";")
  if fields[1] ~= "S2C_SCOREBOARD" then return end
  if self.zone ~= "arena" or not self.match then
    -- on the way in the zone name lags: read it when we are there, if that is soon
    self.heldRoster, self.heldAt = msg, GetTime()
    return
  end
  if msg == self.lastRoster then return end
  self.lastRoster = msg
  self:Log("server", msg)
  local rows, teams, nteams = {}, {}, 0
  local list = Split(fields[4], ADDON_MSG_ARRAY_DELIMITER or ":")
  for i = 1, table.getn(list) do
    local sub = Split(list[i], ADDON_MSG_SUBFIELD_DELIMITER or "|")
    if sub[1] and sub[1] ~= "" and sub[2] then
      table.insert(rows, { name = sub[1], key = A.Key(sub[1]), team = sub[2] })
      if not teams[sub[2]] then
        teams[sub[2]] = true
        nteams = nteams + 1
      end
    end
  end
  local mine = MyTeam(self, rows)
  if not mine or nteams < 2 then
    self:Log("server", "cannot tell the sides yet: " .. table.getn(rows) .. " rows, " .. nteams .. " teams")
    return
  end
  local enemy, ally, nEnemy, nAlly = {}, {}, 0, 0
  for i = 1, table.getn(rows) do
    local r = rows[i]
    if r.team == mine then
      ally[r.key] = true
      nAlly = nAlly + 1
    else
      enemy[r.key] = true
      nEnemy = nEnemy + 1
    end
  end
  self.teamEnemy, self.teamAlly = enemy, ally
  self.scoreSize = math.max(nEnemy, nAlly)     -- their team is your size: frames wait for who has not arrived
  self.teamComplete = nEnemy >= nAlly
  -- a slot filled on a guess that the server now says is wrong gives way
  for i = 1, A.MAX do
    local e = self.enemies[i]
    if e.auto and e.name and not enemy[A.Key(e.name)] then
      self:Log("server", "not an enemy after all: " .. e.name)
      self:SetSlot(i, nil)
    end
  end
  for i = 1, table.getn(rows) do
    local r = rows[i]
    if r.team ~= mine then
      local e = self:FindSlot(r.name) or self:AutoFill(r.name)
      if e then
        self:ApplyScore(e)
        self:Log("named", r.name .. " in slot " .. e.i)
      end
    end
  end
  self:ResolveNames()
  if self:RosterFull() then self:SetHunting(false) end
  self.dirty = true
end

A:On("CHAT_MSG_ADDON", function(prefix, msg)
  if prefix == "TW_ARENA" and msg then A:OnArenaMessage(msg) end
end)

-- ---------------------------------------------------------------- 2. the scoreboard

local RACE_TOKEN = { ["Night Elf"] = "NightElf", ["Undead"] = "Scourge", ["High Elf"] = "HighElf" }

function A.ClassToken(class)
  if not class then return nil end
  if TW_CLASS_TOKEN and TW_CLASS_TOKEN[class] then return TW_CLASS_TOKEN[class] end
  local up = string.upper((string.gsub(class, "%s", "")))
  if A.CLASS_LABEL[up] then return up end
  return nil
end

function A:ApplyScore(e)
  local info = self.scoreInfo and self.scoreInfo[A.Key(e.name)]
  if not info then return end
  if info.class and not e.class then
    e.class = info.class
    if self.db.slots[e.i].name then self.db.slots[e.i].class = info.class end
    self.dirty = true
  end
  if info.race and not e.race then
    e.race = info.race
    self.dirty = true
  end
end

function A:ReadScore()
  if self.zone ~= "arena" or not GetNumBattlefieldScores or self:IsBG() then return end
  local n = GetNumBattlefieldScores()
  if not n or n < 1 then return end
  local info, me = {}, A.Key(UnitName("player"))
  local mine
  for i = 1, n do
    local name, _, _, _, _, faction, _, race, class = GetBattlefieldScore(i)
    if name then
      local key = A.Key(name)
      info[key] = { name = name, faction = faction, class = A.ClassToken(class),
                    race = race and (RACE_TOKEN[race] or string.gsub(race, "%s", "")) or nil }
      if key == me then mine = faction end
    end
  end
  if not self.scoreInfo and self.match then self:Log("score", n .. " rows") end
  self.scoreInfo = info
  for i = 1, A.MAX do
    local e = self.enemies[i]
    if e.name then self:ApplyScore(e) end
  end
  -- No list from the server after a few seconds: the faction column can only stand in
  -- for it when your whole group is on your side of it, and it could not be otherwise.
  if self.teamEnemy or mine == nil or not self.match or GetTime() - self.match.start < 3 then return end
  local same, other = 0, 0
  for _, r in pairs(info) do
    if r.faction == mine then same = same + 1 else other = other + 1 end
  end
  if same ~= self:OwnTeamSize() or other < 1 then return end
  self:Log("score", "sides from the faction column: " .. same .. " and " .. other)
  self.scoreSize = other
  for _, r in pairs(info) do
    if r.faction ~= mine then
      local e = self:FindSlot(r.name) or self:AutoFill(r.name, nil, r.class)
      if e then self:ApplyScore(e) end
    end
  end
  self.dirty = true
end
A:On("UPDATE_BATTLEFIELD_SCORE", function() A:ReadScore() end)

-- ---------------------------------------------------------------- 3. which unit

-- Name to GUID, without touching your target. The result is checked before it counts.
function A:ResolveOne(e)
  if not UnitTokenFromName then return false end
  local names = { e.name }
  local base = string.gsub(e.name, "%-%a+$", "")
  if base ~= e.name then names[2] = base end
  for i = 1, table.getn(names) do
    local ok, tok = pcall(UnitTokenFromName, names[i], true)
    if ok and tok then
      local g = A.IsGuid(tok) and tok or A.GuidOf(tok)
      if g and UnitExists(g) and UnitIsPlayer(g) and A.Key(UnitName(g)) == A.Key(e.name)
         and g ~= self.myGuid and not (self.friends and self.friends[g] and e.auto) then
        self:Bind(e, g)
        self:Log("id", e.name .. " from UnitTokenFromName")
        return true
      end
    end
  end
  return false
end

function A:ResolveNames()
  if not UnitTokenFromName or not A.GuidUnits() then return end
  for i = 1, A.MAX do
    local e = self.enemies[i]
    if e.name and not e.guid then self:ResolveOne(e) end
  end
end

-- Nameplates: ClassicAPI's list of GUIDs, else the plates among WorldFrame's children.
function A:ScanPlates()
  if not A.GuidUnits() then return end
  if C_NamePlate and C_NamePlate.GetNamePlateGUIDs then
    local r = { pcall(C_NamePlate.GetNamePlateGUIDs) }
    if r[1] then
      if type(r[2]) == "table" then
        for _, g in pairs(r[2]) do
          if A.IsGuid(g) then self:Consider(g, "plate") end
        end
      else
        for i = 2, table.getn(r) do
          if A.IsGuid(r[i]) then self:Consider(r[i], "plate") end
        end
      end
      return
    end
  end
  local kids = { WorldFrame:GetChildren() }
  for i = 1, table.getn(kids) do
    local ok, g = pcall(kids[i].GetName, kids[i], 1)
    if ok and A.IsGuid(g) then self:Consider(g, "plate") end
  end
end

-- Clients without ClassicAPI: a named enemy with no ID yet is found by targeting them
-- for an instant, only before combat, and your target is put straight back. One a
-- second, three tries each. With ClassicAPI this never runs: it needs no target swap.
function A:TargetSweep(now)
  if UnitTokenFromName or not self.db.huntTarget or self.zone ~= "arena" then return end
  if UnitAffectingCombat("player") or (SpellIsTargeting and SpellIsTargeting()) then return end
  if self.sweepNext and now < self.sweepNext then return end
  for i = 1, A.MAX do
    local e = self.enemies[i]
    if e.name and (not e.class or not e.race or (A.GuidUnits() and not e.guid)) and (e.sweeps or 0) < 3 then
      self.sweepNext = now + 1
      e.sweeps = (e.sweeps or 0) + 1
      local had = UnitExists("target")
      TargetByName(e.name, true)
      if UnitExists("target") and A.Key(UnitName("target")) == A.Key(e.name) then
        local g = A.GuidOf("target")
        if g and A.GuidUnits() then self:Bind(e, g) end
        self:ReadIdentity(e, "target")
        self:Log("id", e.name .. " from a target swap")
      end
      if had then TargetLastTarget() else ClearTarget() end
      return
    end
  end
end

-- ---------------------------------------------------------------- every event with a GUID

-- Which arguments of each nampower / ClassicAPI event hold a unit's GUID.
local SEEN = {
  SPELL_START_OTHER = { 3, 4 }, SPELL_GO_OTHER = { 3, 4 }, AUTO_ATTACK_OTHER = { 1, 2 },
  SPELL_DAMAGE_EVENT_OTHER = { 1, 2 }, SPELL_MISS_OTHER = { 1, 2 }, SPELL_HEAL_BY_OTHER = { 1, 2 },
  SPELL_ENERGIZE_BY_OTHER = { 1, 2 }, AURA_CAST_ON_OTHER = { 2, 3 }, DAMAGE_SHIELD_OTHER = { 1, 2 },
  SPELL_DISPEL_BY_OTHER = { 1, 2 }, ENVIRONMENTAL_DMG_OTHER = { 1 }, DEBUFF_ADDED_OTHER = { 1 },
  BUFF_ADDED_OTHER = { 1 }, DEBUFF_REMOVED_OTHER = { 1 }, BUFF_REMOVED_OTHER = { 1 },
  UNIT_HEALTH_GUID = { 1 }, UNIT_AURA_GUID = { 1 }, UNIT_FLAGS_GUID = { 1 }, UNIT_COMBAT_GUID = { 1 },
  UNIT_NAME_UPDATE_GUID = { 1 }, UNIT_MANA_GUID = { 1 }, UNIT_RAGE_GUID = { 1 }, UNIT_ENERGY_GUID = { 1 },
  PLAYER_GUILD_UPDATE_GUID = { 1 },
}
A.huntFns = {}

local function Seer(name, spots)
  return function(a1, a2, a3, a4)
    for i = 1, table.getn(spots) do
      local g
      if spots[i] == 1 then g = a1 elseif spots[i] == 2 then g = a2 elseif spots[i] == 3 then g = a3 else g = a4 end
      if A.IsGuid(g) and not A.byGuid[g] then A:Consider(g, name) end
    end
  end
end
for name, spots in pairs(SEEN) do A.huntFns[name] = Seer(name, spots) end
A.huntFns["NAME_PLATE_UNIT_ADDED"] = function(unit)
  local g = unit and A.GuidOf(unit)
  if g and not A.byGuid[g] then A:Consider(g, "plate event") end
end

-- These events are only listened to while someone is still missing.
function A:SetHunting(on)
  on = on and true or nil
  if not on and self.match and not self.foundAt and self:RosterFull() then
    self.foundAt = GetTime() - self.match.start
    self:Log("complete", self:RosterText())
  end
  if on == self.hunting then return end
  self.hunting = on
  for name in pairs(A.huntFns) do
    if on then
      self.events:RegisterEvent(name)
    elseif not self.handlers[name] then
      self.events:UnregisterEvent(name)
    end
  end
end

-- nampower's optional events, as OctoBG and Spy switch them on.
local NP_CVARS = { "NP_EnableSpellStartEvents", "NP_EnableSpellGoEvents", "NP_EnableAutoAttackEvents", "NP_EnableAuraCastEvents" }
function A:NampowerEvents()
  if self.npDone or not GetNampowerVersion then return end
  self.npDone = true
  for i = 1, table.getn(NP_CVARS) do
    local ok, v = pcall(GetCVar, NP_CVARS[i])
    if ok and v ~= nil and v ~= "1" then pcall(SetCVar, NP_CVARS[i], "1") end
  end
end
