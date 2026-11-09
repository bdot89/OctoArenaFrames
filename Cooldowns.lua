-- OctoArenaFrames :: cooldowns (what OctoKicks did, for every spell that matters)
-- A use starts: the spell's cooldown from the game's table; the shared cooldown of
-- every spell of that class in the same category (Pummel locks Shield Bash, every
-- shock locks Earth Shock, every trap the others); resets (Cold Snap, Preparation,
-- Readiness) as the game's own descriptions say. An early recast that talents can
-- explain teaches that player's real cooldown and is remembered by name; one that
-- talents cannot explain was a reset we missed, and only restarts the clock.

local A = OctoArenaFrames

local DEDUPE = 1.5     -- the same spell from the same enemy within this many seconds is one use
A.GONE = 0.35          -- BG mode: seconds a ready icon takes to shrink away
local LEARNED_MAX = 800

-- ---------------------------------------------------------------- learning

local function Evict(g)
  local n = 0
  for _ in pairs(g.learned) do n = n + 1 end
  if n < LEARNED_MAX then return end
  local list = {}
  for name in pairs(g.learned) do table.insert(list, name) end
  table.sort(list, function(a, b) return (g.seen[a] or 0) < (g.seen[b] or 0) end)
  for i = 1, 100 do
    g.learned[list[i]] = nil
    g.seen[list[i]] = nil
  end
end

function A:Learned(name, spell)
  if not self.db.learn or not name then return nil end
  local p = self.global.learned[name]
  return p and p[spell]
end

function A:Learn(name, spell, seconds)
  if not name then return end
  local g = self.global
  if not g.learned[name] then
    Evict(g)
    g.learned[name] = {}
  end
  local cur = g.learned[name][spell]
  if not cur or seconds < cur then g.learned[name][spell] = math.floor(seconds * 10 + 0.5) / 10 end
  g.seen[name] = time and time() or 0
end

-- ---------------------------------------------------------------- uses

-- How long this use takes: a changed setting, else what this player was seen to
-- have, else the rank's own number, else the table's.
function A:Duration(e, s, id)
  local d = A.SpellCD(s)
  if id and A.RANKCD[id] and not (self.db.spells[s.n] and self.db.spells[s.n].cd) then d = A.RANKCD[id] end
  if e then
    local l = self:Learned(e.name, s.n)
    if l and l < d then d = l end
  end
  return d
end

function A:Start(e, s, dur, now, shared)
  e.cds[s.n] = { start = now, dur = dur, shared = shared }
  e.flash[s.n] = nil
  self.dirty = true
end

-- A use by a slotted enemy.
function A:Use(e, s, id)
  local now = GetTime()
  local c = e.cds[s.n]
  if c and not c.shared and now - c.start < DEDUPE then return end
  local dur = self:Duration(e, s, id)
  -- back early: talents, or a reset we missed
  if c and not c.shared and not c.done and now < c.start + c.dur and not e.fake and self.db.learn then
    local seen = now - c.start
    local floor = s.min or s.cd
    if seen < c.dur - 0.5 and seen >= floor - 0.5 and floor < s.cd then
      self:Learn(e.name, s.n, seen)
      if seen < dur then dur = seen end
    end
  end
  self:Start(e, s, dur, now)
  e.seen[s.n] = true
  if s.tab and not e.spec then e.spec = s.tab end
  if not e.class and A.CLASS_LABEL[s.c] then e.class = s.c end
  -- the class's other spells in the same category
  if s.g and s.gcd then
    local groups = A.GROUPS[s.c]
    local list = groups and groups[s.g]
    if list then
      for i = 1, table.getn(list) do
        local o = list[i]
        if o ~= s then
          local oc = e.cds[o.n]
          local left = oc and (oc.start + oc.dur - now) or 0
          if left < s.gcd then self:Start(e, o, s.gcd, now, s.n) end
        end
      end
    end
  end
  -- resets
  local reset = A.RESETS[s.n]
  if reset then
    local list = A.BYCLASS[s.c]
    for i = 1, table.getn(list) do
      if reset(list[i]) then e.cds[list[i].n] = nil end
    end
  end
  self:Alert(e, s, dur)
  self:Changed()
end

-- A use whose aura stays up starts its cooldown when the aura ends (Presence of
-- Mind, Nature's Swiftness, Feign Death...): the clock is started again then.
function A:AuraGone(e, name)
  local s = A.BYNAME[name]
  if not s or not s.wa then return end
  local c = e.cds[name]
  if c then
    c.start = GetTime()
    c.done = nil
    self.dirty = true
  end
end

function A:Alert(e, s, dur)
  if self.test or e.fake then return end
  local db = self.db
  if s == A.TRINKET and db.soundTrinket then PlaySoundFile(A.SoundFile(db.soundTrinketFile))
  elseif db.soundUse then PlaySoundFile(A.SoundFile(db.soundUseFile)) end
  local text = e.name .. " used " .. s.n .. " (" .. math.floor(dur) .. "s)"
  if db.printChat then self:Print(text) end
  if db.announce and GetNumPartyMembers and GetNumPartyMembers() > 0 then
    SendChatMessage("[OctoArena] " .. text, "PARTY")
  end
end

-- Seconds left on an enemy's spell (0 = ready), and whether it was ever used.
function A.Remaining(e, name, now)
  local c = e.cds[name]
  if not c then return 0, false end
  local left = c.start + c.dur - (now or GetTime())
  if left < 0 then left = 0 end
  return left, true
end

-- A tracked spell was seen. opts: pet (cast by a pet), hostile, aura (only the
-- debuff was seen, caster unknown).
function A:Credit(s, casterName, guid, id, opts)
  if not s then return end
  opts = opts or {}
  casterName = A.RealName(casterName)
  if self:IsBG() then
    if not A.SpellOn(s) or opts.aura or not casterName or not opts.hostile then return end
    self:BGUse(casterName, guid, s, opts.pet, id)
    return
  end
  local e
  if not opts.pet and not opts.aura then e = self:FindSlot(casterName, guid) end
  if not e and opts.pet then e = self:FindByPet(casterName) end
  if not e and (opts.pet or opts.aura) then
    e = A.CLASS_LABEL[s.c] and self:FindByClass(s.c) or nil
    if e and opts.pet then e.petName = casterName end
  end
  if not e and opts.hostile and not opts.pet and not opts.aura then
    local class = A.CLASS_LABEL[s.c] and s.c or nil
    e = self:AutoFill(casterName, guid, class)
  end
  if not e then
    self.ignored = self.ignored + 1
    return
  end
  self:Use(e, s, id)
end

-- ---------------------------------------------------------------- BG / World

-- One entry per player (by GUID with SuperWoW, else by name). Pets with no known
-- owner get their own entry, coloured by the spell's class.
function A:BGUse(name, guid, s, pet, id)
  local units = self:BGUnits()
  local key = guid or ((pet and "pet:" or "") .. name)
  local u = units[key]
  local now = GetTime()
  if not u then
    local class = A.CLASS_LABEL[s.c] and s.c or nil
    if guid and not pet then
      local _, token = UnitClass(guid)
      if token then class = token end
    end
    u = { key = key, name = name, guid = guid, class = class, cds = {}, order = 0, first = now }
    units[key] = u
  end
  local c = u.cds[s.n]
  if c and not c.done and now - c.start < DEDUPE then return end
  u.order = u.order + 1
  u.cds[s.n] = { start = now, dur = self:Duration(nil, s, id), slot = u.order }
  u.last = now
end

-- ---------------------------------------------------------------- tick

-- Cooldowns that just came back glow and may play a sound; BG icons that came
-- back shrink away, then their row goes.
function A:Tick(now)
  local list = self:Enemies()
  for i = 1, self:Max() do
    local e = list[i]
    if e and e.name then
      for name, c in pairs(e.cds) do
        if not c.done and now >= c.start + c.dur then
          c.done = true
          self.dirty = true
          if self.db.flashReady and e.seen[name] then e.flash[name] = now end
          if self.db.soundReady and not self.test and e.seen[name] then
            PlaySoundFile(A.SoundFile(self.db.soundReadyFile))
          end
        end
      end
    end
  end
  local units = self:BGUnits()
  for key, u in pairs(units) do
    local any = false
    for name, c in pairs(u.cds) do
      if not c.done and now >= c.start + c.dur then c.done = now end
      if c.done and now - c.done > A.GONE then u.cds[name] = nil else any = true end
    end
    if not any then units[key] = nil end
  end
  if self.test then self:TestTick(now) end
end

-- ---------------------------------------------------------------- test mode

local function Pickable(class, used)
  local out = {}
  local spells = A.BYCLASS[class]
  if not spells then return out end
  for i = 1, table.getn(spells) do
    local s = spells[i]
    if A.SpellTier(s) ~= 0 and not used(s) then table.insert(out, s) end
  end
  return out
end

local CC_SAMPLES = { 12826, 10308, 2094, 6215, 10230, 15487, 8643, 11958 }
local CAST_SAMPLES = {
  { "Polymorph", 1500 }, { "Greater Heal", 2500 }, { "Fear", 1500 }, { "Frostbolt", 2500 }, { "Mind Flay", 3000, true },
}

-- Full test only: an enemy's cast gets kicked (school lockout), or a trinket /
-- racial goes. Returns true when it did something.
function A:TestExtra(e, now)
  local roll = math.random(1, 3)
  if roll == 1 then
    local who
    for k = 1, self:Max() do
      local o = self.testEnemies[k]
      if o and o.cast and not o.cast.channel and not o.cast.noint then who = o break end
    end
    if who then
      self:Kicked(who, A.BYNAME["Kick"] or A.BYNAME["Pummel"], now)
      return true
    end
    -- nobody casting: start a kickable cast, the next roll may kick it
    if not e.cast then
      self:CastStart(e, "Polymorph", nil, 1500, nil, now)
      return true
    end
  elseif roll == 2 then
    if A.TRINKET and A.Remaining(e, A.TRINKET.n, now) == 0 then
      self:Use(e, A.TRINKET)
      return true
    end
  else
    local s = A.RACIAL[e.race or ""]
    if s and A.Remaining(e, s.n, now) == 0 then
      self:Use(e, s)
      return true
    end
  end
end

function A:TestTick(now)
  if self.testEnds and now >= self.testEnds then
    self:SetTest(false)
    return
  end
  if now < self.testNext then return end
  if self:IsBG() then
    self.testNext = now + 0.4 + math.random() * 1.2
    local e = A.BG_SAMPLES[math.random(1, table.getn(A.BG_SAMPLES))]
    local u = self.testBg[e[1]]
    local list = Pickable(e[2], function(s) return u and u.cds[s.n] end)
    if table.getn(list) > 0 then self:BGUse(e[1], nil, list[math.random(1, table.getn(list))], nil) end
    return
  end
  self.testNext = now + 0.7 + math.random() * 1.1
  local i = math.random(1, self:Max())
  local e = self.testEnemies[i]
  if not e then return end
  -- health moves a little so the bars show life
  e.hp = math.max(8, math.min(100, (e.hp or 80) + math.random(-14, 12)))
  if self.testFull and math.random(1, 2) == 1 and self:TestExtra(e, now) then
    self:Changed()
    return
  end
  local roll = math.random(1, 3)
  if roll == 1 then
    local list = Pickable(e.class, function(s) return A.Remaining(e, s.n, now) > 0 end)
    if table.getn(list) > 0 then self:Use(e, list[math.random(1, table.getn(list))]) end
  elseif roll == 2 and not e.cast then
    local c = CAST_SAMPLES[math.random(1, table.getn(CAST_SAMPLES))]
    self:CastStart(e, c[1], nil, c[2], c[3], now)
  else
    local id = CC_SAMPLES[math.random(1, table.getn(CC_SAMPLES))]
    local def = A.AURAS[id]
    if def and not e.auras[id] and self.AuraAdded then self:AuraAdded(e, id, def, now, true) end
  end
  self:Changed()
end
