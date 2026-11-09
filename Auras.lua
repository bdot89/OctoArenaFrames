-- OctoArenaFrames :: what is on an enemy right now
-- Health, power and state are read 20 times a second; auras 5 times a second, and at
-- once when nampower says one changed. The aura itself is the truth: a crowd control
-- icon goes the moment the debuff goes, whatever the timer said.
--
-- Timers: 1.12 does not send other players' aura times. A timer is the table's time,
-- capped for players (Polymorph is 50 s in the table but never more than 15 s in the
-- user's logs: 38 casts, longest 15.0 s; Freezing Trap 16 s, Fear 12 s), halved by
-- diminishing returns, from the moment it appeared. ClassicAPI's end time is used when
-- it is shorter. Nothing is shown when the start was not seen, or the time depends on
-- combo points (Kidney Shot).
--
-- Diminishing returns: each landing halves the next (100, 50, 25, then immune); the
-- count resets 15 s after the effect ends. The groups follow the game's mechanics.

local A = OctoArenaFrames

local PVP_CAP = 15
A.DR_WINDOW = 15
A.DR_KINDS = {
  stun = "Stun", incap = "Incapacitate", disorient = "Disorient", fear = "Fear", horror = "Horror",
  sleep = "Sleep / freeze", charm = "Charm", root = "Root", silence = "Silence", banish = "Banish",
}
local DR_ORDER = { "stun", "incap", "disorient", "fear", "horror", "sleep", "silence", "root", "charm", "banish" }
A.DR_ORDER = DR_ORDER
local DR_MULT = { 1, 0.5, 0.25, 0 }

-- which aura is worth the big icon
local PRIO = {
  immune = 100, banish = 96, stun = 92, incap = 90, disorient = 88, fear = 86, horror = 86, sleep = 84, charm = 82,
  silence = 70, root = 60, defense = 40, offense = 30, mobility = 20,
}
A.AURA_PRIO = PRIO

-- without spell ids (no SuperWoW) an aura is known by its picture
A.AURA_TEX = {}
for id, def in pairs(A.AURAS) do
  def.texture = "Interface\\Icons\\" .. def.i
  local low = string.lower(def.texture)
  local old = A.AURA_TEX[low]
  if not old or (def.d or 0) > (old.d or 0) then A.AURA_TEX[low] = def end
end

local function Wanted(def)
  if A.DR_KINDS[def.k] then return true end
  local s = A.BYNAME[def.n]
  return not s or A.SpellOn(s)
end

-- ---------------------------------------------------------------- reading a unit

function A:Read(e, now)
  local u = self:UnitOf(e)
  if u ~= e.unit then
    if u and not e.unit then e.known = nil end   -- back in sight: what is on them started unseen
    e.unit = u
    self.dirty = true
  end
  if not u then
    if e.feign then e.feign = nil end
    return
  end
  e.lastSeen = now
  if e.stealth and now - e.stealth > 1 then e.stealth = nil end
  if not e.race or not e.class then self:ReadIdentity(e, u) end
  e.hp, e.hpMax = UnitHealth(u), UnitHealthMax(u)
  e.mana, e.manaMax = UnitMana(u), UnitManaMax(u)
  e.power = UnitPowerType and UnitPowerType(u) or 0
  local dead = (UnitIsDeadOrGhost and UnitIsDeadOrGhost(u)) or (e.hp == 0)
  e.feign = nil
  if dead and UnitIsFeignDeath then
    local ok, f = pcall(UnitIsFeignDeath, u)
    if ok and f then
      e.feign, dead = true, false
    end
  end
  if e.auras[5384] then e.feign, dead = true, false end
  if (dead and true or nil) ~= e.dead then
    e.dead = dead and true or nil
    self.dirty = true
  end
end

-- Who they have targeted, and whether you can reach them.
function A:ReadSlow(e, now)
  local u = e.unit
  if not u then
    e.targetName, e.targetClass, e.onMe, e.far = nil, nil, nil, nil
    return
  end
  -- SuperWoW takes "<guid>target"; a token gets "target" added
  local token = u .. "target"
  local ok, has, g = pcall(UnitExists, token)
  if ok and has then
    e.targetName = UnitName(token)
    local _, c = UnitClass(token)
    e.targetClass = c
    e.onMe = (g and g == self.myGuid) or (not g and UnitIsUnit(token, "player")) or nil
  else
    e.targetName, e.targetClass, e.onMe = nil, nil, nil
  end
  e.far = self:IsFar(u)
end

-- More than 40 yards away or out of line of sight? nil when nothing can tell.
function A:IsFar(u)
  if not UnitExists(u) then return nil end
  if UnitInLineOfSight then
    local ok, los = pcall(UnitInLineOfSight, u)
    if ok and los == false then return true end
  end
  if UnitDistanceSquared then
    local ok, sq, checked = pcall(UnitDistanceSquared, u)
    if ok and checked and sq then return sq > 1600 end
  end
  if UnitXP then
    local ok, los = pcall(UnitXP, "inSight", "player", u)
    if ok and los == false then return true end
    local ok2, d = pcall(UnitXP, "distanceBetween", "player", u)
    if ok2 and type(d) == "number" and d >= 0 then return d > 40 end
  end
  return nil
end

-- ---------------------------------------------------------------- auras

function A:AuraAdded(e, key, def, now, known)
  local a = { key = key, def = def, start = now, tex = def.texture }
  local dur = def.d
  if dur == 0 then dur = nil end
  if A.DR_KINDS[def.k] then
    local dr = e.dr[def.k]
    local running = dr and (dr.active > 0 or (dr.stop and now < dr.stop))
    local level = running and dr.level or 0
    if dur then dur = math.min(dur, PVP_CAP) * (DR_MULT[level + 1] or 0.25) end
    e.dr[def.k] = { level = math.min(level + 1, 3), active = (running and dr.active or 0) + 1, tex = def.texture, stop = nil }
  end
  if not known then dur = nil end
  if dur and dur > 0 then
    a.dur = dur
    a.stop = now + dur
  end
  e.auras[key] = a
  self.dirty = true
  return a
end

function A:AuraRemoved(e, key, a, now)
  e.auras[key] = nil
  local def = a.def
  if A.DR_KINDS[def.k] then
    local dr = e.dr[def.k]
    if dr then
      dr.active = math.max(0, dr.active - 1)
      if dr.active == 0 then dr.stop = now + A.DR_WINDOW end
    end
  end
  self:AuraGone(e, def.n)
  self.dirty = true
end

local seen = {}

local function See(self, e, sid, tex, now)
  local def = sid and A.AURAS[sid]
  if not def and not sid and tex then def = A.AURA_TEX[string.lower(tex)] end
  if not def or not Wanted(def) then return nil end
  local key = sid or def.n
  seen[key] = true
  if e.auras[key] then return nil end
  self:AuraAdded(e, key, def, now, e.known)
  return true
end

-- ClassicAPI's end times, when it knows them and they are shorter than ours.
local function Refine(e, u, now)
  if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) or not A.IsGuid(u) then return end
  local filters = { "HARMFUL", "HELPFUL" }
  for f = 1, 2 do
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, u, filters[f])
    if ok and type(list) == "table" then
      for i = 1, table.getn(list) do
        local x = list[i]
        local a = type(x) == "table" and x.spellId and e.auras[x.spellId]
        if a and x.expirationTime and x.expirationTime > now then
          local cap = A.DR_KINDS[a.def.k] and (now + PVP_CAP) or nil
          local stop = x.expirationTime
          if cap and stop > cap then stop = cap end
          if not a.stop or stop < a.stop then
            a.stop = stop
            a.dur = a.dur or (stop - now)
          end
        end
      end
    end
  end
end

function A:ScanAuras(e, now)
  local u = e.unit
  if not u then return end
  for k in pairs(seen) do seen[k] = nil end
  local added
  for i = 1, 16 do
    local tex, _, _, sid = UnitDebuff(u, i)
    if not tex then break end
    if See(self, e, sid, tex, now) then added = true end
  end
  for i = 1, 32 do
    local tex, _, sid = UnitBuff(u, i)
    if not tex then break end
    if See(self, e, sid, tex, now) then added = true end
  end
  for key, a in pairs(e.auras) do
    if not seen[key] then self:AuraRemoved(e, key, a, now) end
  end
  if added then Refine(e, u, now) end
  e.known = true
  self:PickAuras(e, now)
end

-- The big icon, the small strip and the immunity mark.
local list = {}
function A:PickAuras(e, now)
  local n = 0
  e.immune = nil
  for _, a in pairs(e.auras) do
    n = n + 1
    list[n] = a
    if a.def.k == "immune" then e.immune = a end
  end
  for i = table.getn(list), n + 1, -1 do list[i] = nil end
  table.sort(list, function(x, y)
    local px, py = PRIO[x.def.k] or 0, PRIO[y.def.k] or 0
    if px ~= py then return px > py end
    local sx, sy = x.stop or 0, y.stop or 0
    if sx ~= sy then return sx > sy end
    return tostring(x.key) < tostring(y.key)
  end)
  local big = list[1]
  if big ~= e.big then
    e.big = big
    self.dirty = true
  end
  local strip = e.strip
  local changed = false
  local max = self.db.stripMax
  for i = 1, max do
    if strip[i] ~= list[i + 1] then
      strip[i] = list[i + 1]
      changed = true
    end
  end
  for i = table.getn(strip), max + 1, -1 do strip[i] = nil end
  if changed then self.dirty = true end
end

function A:AuraTick(now)
  local all = self:Enemies()
  for i = 1, self:Max() do
    local e = all[i]
    if e and e.name then
      if e.fake then
        -- test mode: nothing to read, the timers decide
        for key, a in pairs(e.auras) do
          if a.stop and now >= a.stop then self:AuraRemoved(e, key, a, now) end
        end
        self:PickAuras(e, now)
      elseif e.unit then
        self:ScanAuras(e, now)
      elseif e.big or next(e.auras) then
        -- out of sight: nothing about them is known any more, except the clock of
        -- what we saw land (a timer that passed its end cannot be still running)
        for key, a in pairs(e.auras) do
          if not a.stop or now >= a.stop then self:AuraRemoved(e, key, a, now) end
        end
        self:PickAuras(e, now)
      end
      for _, dr in pairs(e.dr) do
        if dr.stop and now >= dr.stop then
          dr.level, dr.stop, dr.active = 0, nil, 0
          self.dirty = true
        end
      end
    end
  end
end

-- The diminishing returns worth showing, in a fixed order.
function A.DrList(e, out)
  local n = 0
  for i = 1, table.getn(DR_ORDER) do
    local k = DR_ORDER[i]
    local dr = e.dr[k]
    if dr and dr.level > 0 then
      n = n + 1
      out[n] = k
    end
  end
  for i = table.getn(out), n + 1, -1 do out[i] = nil end
  return n
end

-- nampower: an aura changed on someone: look now rather than at the next tick.
local function AuraEvent(guid)
  local e = guid and A.byGuid[guid]
  if e and e.unit and not A.test then A:ScanAuras(e, GetTime()) end
end
A:On("UNIT_AURA_GUID", function(g) AuraEvent(g) end)
A:On("BUFF_ADDED_OTHER", function(g) AuraEvent(g) end)
A:On("BUFF_REMOVED_OTHER", function(g) AuraEvent(g) end)
A:On("DEBUFF_ADDED_OTHER", function(g) AuraEvent(g) end)
A:On("DEBUFF_REMOVED_OTHER", function(g) AuraEvent(g) end)
