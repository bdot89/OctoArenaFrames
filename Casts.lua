-- OctoArenaFrames :: casts and interrupts
-- SuperWoW's UNIT_CASTEVENT is the source when it is there: it fires the moment the
-- client hears from the server, with the caster's GUID, the target, the spell id and
-- the real cast time (haste included). ClassicAPI's cast info then corrects pushback
-- and says what cannot be interrupted. Without SuperWoW the combat log gives the same
-- by name. Only one source at a time.

local A = OctoArenaFrames

-- ---------------------------------------------------------------- the cast bar's data

function A:CastStart(e, name, tex, ms, channel, now, id)
  local info = A.CASTS[name]
  ms = ms and ms > 0 and ms or (info and info.t) or 0
  if ms <= 0 then return end
  e.cast = {
    name = name, id = id, start = now, dur = ms / 1000, channel = channel,
    tex = tex or (info and ("Interface\\Icons\\" .. info.i)) or nil,
    school = info and info.s or nil, noint = info and info.ni or nil,
  }
  e.castEnd = nil
end

function A:CastEnd(e, now, text, r, g, b, keep)
  local c = e.cast
  if c then
    c.at = now
    e.lastCast = c
  end
  e.cast = nil
  e.castEnd = { text = text, r = r, g = g, b = b, stop = now + (keep or 0.2), name = c and c.name, tex = c and c.tex }
end

-- An interrupt spell went off at this enemy, from anyone. If they were casting
-- (or stopped a moment ago: the two messages can come either way round) that
-- school is locked for the time the game's table says.
function A:Kicked(e, s, now)
  local c = e.cast
  if not c and e.lastCast and now - e.lastCast.at < 0.4 then c = e.lastCast end
  if not c or c.noint then return end
  if s.lock and self.db.lockout then
    e.lockout = { stop = now + s.lock, school = c.school, by = s.n, tex = s.texture }
  end
  if e.cast then
    self:CastEnd(e, now, "INTERRUPTED", 1, 0.25, 0.2, 0.7)
  elseif e.castEnd then
    e.castEnd.text, e.castEnd.r, e.castEnd.g, e.castEnd.b = "INTERRUPTED", 1, 0.25, 0.2
    e.castEnd.stop = now + 0.7
  end
  if self.db.announceKicks and not self.test and GetNumPartyMembers and GetNumPartyMembers() > 0 then
    SendChatMessage("[OctoArena] " .. s.n .. " on " .. e.name .. "'s " .. c.name
      .. (c.school and A.SCHOOL_LABEL[c.school] and (": " .. A.SCHOOL_LABEL[c.school] .. " locked") or ""), "PARTY")
  end
end

-- Pushback and "cannot be interrupted" from ClassicAPI, while a cast is running.
function A:RefineCast(e, now)
  if not C_Spell or not e.guid or not e.unit then return end
  local c = e.cast
  local fn = c.channel and C_Spell.UnitChannelInfo or C_Spell.UnitCastingInfo
  if not fn then return end
  local ok, name, _, tex, startMs, endMs, _, _, noint = pcall(fn, e.guid)
  if not ok or not name or not startMs or not endMs then return end
  if c.channel then noint = nil end
  if endMs > startMs then
    local stop = endMs / 1000
    local diff = math.abs(stop - (c.start + c.dur))
    if diff > 0.05 and diff < 10 then     -- a bigger gap would be another clock, not pushback
      c.start = startMs / 1000
      c.dur = (endMs - startMs) / 1000
    end
  end
  if noint ~= nil then c.noint = noint and true or nil end
  if tex and not c.tex then c.tex = tex end
end

-- ---------------------------------------------------------------- SuperWoW

function A:OnCastEvent(caster, target, kind, id, ms)
  if not caster or not id then return end
  if target == "0x0000000000000000" then target = nil end
  local now = GetTime()
  local s = A.IDS[id] and A.BYNAME[A.IDS[id]]
  -- an interrupt lands on its target whoever cast it (you, your team, a pet)
  if s and s.lock and kind == "CAST" and target then
    local te = self.byGuid[target]
    if te then self:Kicked(te, s, now) end
  end
  if caster == self.myGuid then return end
  if kind == "MAINHAND" or kind == "OFFHAND" then
    if not self.byGuid[caster] then self:Consider(caster) end
    return
  end
  if not UnitExists(caster) then return end
  if not UnitIsPlayer(caster) then
    -- a pet: its cooldown is its owner's (a mob's Kick is not an enemy player's)
    if not s or not s.pet or (kind ~= "CAST" and kind ~= "CHANNEL") then return end
    local ok, has, owner = pcall(UnitExists, caster .. "owner")
    if ok and has and A.IsGuid(owner) and UnitIsPlayer(owner) then
      self:Credit(s, UnitName(owner), owner, id, { hostile = UnitCanAttack("player", owner) and true or false })
    elseif UnitCanAttack("player", caster) then
      self:Credit(s, UnitName(caster), nil, id, { pet = true, hostile = true })
    end
    return
  end
  if self:IsBG() then
    if s and (kind == "CAST" or kind == "CHANNEL") then
      self:Credit(s, UnitName(caster), caster, id, { hostile = UnitCanAttack("player", caster) and true or false })
    end
    return
  end
  local e = self:Consider(caster)
  if not e then
    if s and (kind == "CAST" or kind == "CHANNEL") then self.ignored = self.ignored + 1 end
    return
  end
  if e.stealth then e.stealth = nil end
  if kind == "START" or kind == "CHANNEL" then
    local name, _, tex = SpellInfo(id)
    if name then self:CastStart(e, name, tex, ms, kind == "CHANNEL", now, id) end
  elseif kind == "CAST" then
    if e.cast and e.cast.id == id and not e.cast.channel then
      self:CastEnd(e, now, nil, 0.3, 1, 0.4, 0.2)
    end
  elseif kind == "FAIL" then
    if e.cast then self:CastEnd(e, now, "STOPPED", 0.7, 0.7, 0.7, 0.45) end
  end
  if s and (kind == "CAST" or kind == "CHANNEL") then
    if s.n == "Stealth" or s.n == "Prowl" or s.n == "Vanish" or s.n == "Shadowmeld" then e.stealth = now end
    self:Use(e, s, id)
  end
end

A:On("UNIT_CASTEVENT", function(a1, a2, a3, a4, a5)
  if A.UseSW() then A:OnCastEvent(a1, a2, a3, a4, a5) end
end)

-- ---------------------------------------------------------------- combat log

local STARTS = { "^(.+) begins to cast (.+)%.$", "^(.+) begins to perform (.+)%.$" }
local USES = {
  "^(.+) casts (.+) on .+%.$", "^(.+) casts (.+)%.$", "^(.+) performs (.+) on .+%.$", "^(.+) performs (.+)%.$",
  "^(.+)'s (.+) hits ", "^(.+)'s (.+) crits ", "^(.+)'s (.+) was ", "^(.+)'s (.+) missed ",
  "^(.+)'s (.+) is ", "^(.+)'s (.+) failed", "^(.+) gains (.+)%.$",
}

-- The one enabled interrupt of a class ("Bob interrupts your Frostbolt." does not
-- say which spell); nil when the class has two (Warrior).
function A.ClassInterrupt(class)
  local list = A.BYCLASS[class]
  if not list then return nil end
  local found
  for i = 1, table.getn(list) do
    local s = list[i]
    if s.k == "interrupt" and s.t == 1 and A.SpellOn(s) then
      if found then return nil end
      found = s
    end
  end
  return found
end

local function Named(who)
  return A.byName and who and A.byName[A.Key(who)]
end

function A:OnLog(ev, msg)
  if not msg then return end
  local now = GetTime()
  if string.find(ev, "PERIODIC_SELF") or string.find(ev, "PERIODIC_PARTY") then
    local _, _, aura = string.find(msg, "afflicted by (.+)%.$")
    local s = aura and A.BYNAME[aura]
    if s then self:Credit(s, nil, nil, nil, { aura = true }) end
    return
  end
  -- you / your team interrupt an enemy: their school is locked
  local _, _, victim = string.find(msg, "^You interrupt (.+)'s ")
  local kicker
  if not victim then _, _, kicker, victim = string.find(msg, "^(.+) interrupts (.+)'s ") end
  if victim then
    local e = Named(victim)
    if e then self:Kicked(e, { n = "Interrupt" }, now) end
    local ek = kicker and Named(kicker)
    if ek and ek.class then
      local s = A.ClassInterrupt(ek.class)
      if s then self:Use(ek, s) end
    end
    return
  end
  local creature = string.find(ev, "CREATURE") ~= nil
  if not creature then
    for i = 1, table.getn(STARTS) do
      local _, _, who, spell = string.find(msg, STARTS[i])
      if who then
        local e = self:FindSlot(who)
        if e then self:CastStart(e, spell, nil, nil, nil, now) end
        return
      end
    end
  end
  for i = 1, table.getn(USES) do
    local _, _, who, spell = string.find(msg, USES[i])
    if who then
      local s = A.BYNAME[spell]
      if s then
        if s.pet then
          self:Credit(s, who, nil, nil, { pet = true, hostile = true })
        elseif not creature then
          self:Credit(s, who, nil, nil, { hostile = true })
          local e = self:FindSlot(who)
          if e and e.cast and e.cast.name == spell then self:CastEnd(e, now, nil, 0.3, 1, 0.4, 0.2) end
        end
      else
        local e = not creature and self:FindSlot(who)
        if e and e.cast and e.cast.name == spell then self:CastEnd(e, now, nil, 0.3, 1, 0.4, 0.2) end
      end
      return
    end
  end
  if creature then return end
  -- "Bob interrupts your Frostbolt." (they kicked you)
  local _, _, who = string.find(msg, "^(.+) interrupts ")
  if not who then return end
  if self:IsBG() then
    local u = self:BGUnits()[who]
    local s = u and A.ClassInterrupt(u.class)
    if s then self:BGUse(who, nil, s) end
    return
  end
  local e = self:FindSlot(who)
  local s = e and e.class and A.ClassInterrupt(e.class)
  if s then self:Use(e, s) end
end

A.LOG_EVENTS = {
  "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
  "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS",
  "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE",
  "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
  "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
  "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_PARTY_DAMAGE", "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
}

function A:RegisterLog()
  local useLog = not A.UseSW()
  for _, e in ipairs(A.LOG_EVENTS) do
    local name = e
    if not self.handlers[name] then
      self.handlers[name] = { function(a1) A:OnLog(name, a1) end }
    end
    if useLog then self.events:RegisterEvent(name) else self.events:UnregisterEvent(name) end
  end
end

-- ---------------------------------------------------------------- your own interrupts

-- Your interrupts: from your spell book and your pet's bar. Shown beside an enemy's
-- cast bar and used by the kick keys.
function A:ScanMyKicks()
  local out = {}
  local _, class = UnitClass("player")
  local wanted = {}
  local list = class and A.BYCLASS[class]
  if list then
    for i = 1, table.getn(list) do
      local s = list[i]
      if s.k == "interrupt" or s.k == "silence" then wanted[s.n] = s end
    end
  end
  local found = {}
  if GetSpellName then
    local i = 1
    while true do
      local name = GetSpellName(i, "spell")
      if not name then break end
      if wanted[name] then found[name] = i end   -- the last rank is the highest
      i = i + 1
    end
  end
  for name, slot in pairs(found) do
    local s = wanted[name]
    table.insert(out, { name = name, slot = slot, tex = s.texture, cd = s.cd })
  end
  if GetPetActionInfo then
    for i = 1, 10 do
      local name, _, tex = GetPetActionInfo(i)
      if name and wanted[name] then
        table.insert(out, { name = name, petSlot = i, tex = tex or wanted[name].texture, cd = wanted[name].cd })
      end
    end
  end
  table.sort(out, function(a, b) return a.cd < b.cd end)
  self.myKicks = out
end

-- The interrupt to use now: the first ready one, else the one back soonest.
-- Returns name, texture, seconds left (0 = ready); nil when you have none.
function A:MyKick(now)
  if not self.myKicks then self:ScanMyKicks() end
  local best, bestLeft
  for i = 1, table.getn(self.myKicks) do
    local k = self.myKicks[i]
    local start, dur
    if k.petSlot then
      if GetPetActionCooldown then start, dur = GetPetActionCooldown(k.petSlot) end
    else
      start, dur = GetSpellCooldown(k.slot, "spell")
    end
    local left = 0
    if start and start > 0 and dur and dur > 1.5 then
      left = start + dur - now
      if left < 0 then left = 0 end
    end
    if left == 0 then return k.name, k.tex, 0 end
    if not bestLeft or left < bestLeft then best, bestLeft = k, left end
  end
  if best then return best.name, best.tex, bestLeft end
  return nil
end

A:On("SPELLS_CHANGED", function() A.myKicks = nil end)
A:On("LEARNED_SPELL_IN_TAB", function() A.myKicks = nil end)
A:On("PET_BAR_UPDATE", function() A.myKicks = nil end)
