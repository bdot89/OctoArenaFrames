-- OctoArenaFrames :: acting on an enemy: target, focus, interrupt, cast
-- 1.12 protects none of this, so it all works in combat. Clicks on the frames, the key
-- bindings (Bindings.xml) and macros (/oaf target 1, /oaf kick 2) come here.

local A = OctoArenaFrames

function A:EnemyAt(i)
  local e = self:Enemies()[i]
  if e and e.name then return e end
  return nil
end

function A:TargetEnemy(i)
  local e = self:EnemyAt(i)
  if not e or e.fake then return end
  if e.guid and A.GuidUnits() and UnitExists(e.guid) and TargetUnit then
    TargetUnit(e.guid)
  else
    TargetByName(e.name, true)
  end
end

-- ClassicAPI's focus when it is there (pfUI Octo follows it), else pfUI's own.
function A:FocusEnemy(i)
  local e = self:EnemyAt(i)
  if not e or e.fake then return end
  if FocusUnit and e.guid and C_UnitAuras then
    local ok = pcall(FocusUnit, e.guid)
    if ok then
      self.dirty = true
      return
    end
  end
  local f = pfUI and pfUI.uf and pfUI.uf.focus
  if f then
    local ft = pfUI.uf.focustarget
    if e.guid then
      f.unitname, f.label, f.id = nil, e.guid, ""
      if ft then ft.unitname, ft.label, ft.id = nil, e.guid .. "target", "" end
    else
      f.unitname = string.lower(e.name)
      f.label, f.id = nil, ""
      if ft then ft.unitname, ft.label, ft.id = f.unitname, nil, "" end
    end
    self.focusGuid = e.guid or e.name
    self.dirty = true
    return
  end
  self:Print("no focus available: this needs ClassicAPI or pfUI.")
end

-- The enemy you have focused, as a GUID or a name.
function A:FocusKey()
  if C_UnitAuras and UnitGUID then
    local ok, g = pcall(UnitGUID, "focus")
    if ok and A.IsGuid(g) then return g end
  end
  local f = pfUI and pfUI.uf and pfUI.uf.focus
  if f then
    if f.label and A.IsGuid(f.label) then return f.label end
    if f.unitname then return f.unitname end
  end
  return nil
end

function A:CastAtEnemy(i, spell)
  local e = self:EnemyAt(i)
  if not e or e.fake or not spell then return end
  if e.guid and A.UseSW() and UnitExists(e.guid) then
    CastSpellByName(spell, e.guid)    -- SuperWoW: casts at the GUID, your target stays
    return
  end
  -- plain 1.12: swap target, cast, swap back
  local key = A.Key(e.name)
  local had = UnitExists("target") and A.Key(UnitName("target")) ~= key
  TargetByName(e.name, true)
  if UnitExists("target") and A.Key(UnitName("target")) == key then CastSpellByName(spell) end
  if had then TargetLastTarget() end
end

-- Your interrupt that is ready, at this enemy.
function A:KickEnemy(i)
  local name, _, left = self:MyKick(GetTime())
  if not name then
    self:Print("no interrupt found in your spell book or on your pet's bar.")
    return
  end
  if left and left > 0 then
    UIErrorsFrame:AddMessage(name .. ": " .. math.ceil(left) .. "s", 1, 0.3, 0.2, 1, 2)
    return
  end
  self:CastAtEnemy(i, name)
end

-- ---------------------------------------------------------------- mouseover casting
-- With the mouse over an enemy frame, your interrupt (or any spell, by setting) goes to
-- that enemy: action buttons and their keys, /cast macros and the spell book alike.
-- SuperWoW casts at the GUID and your target never changes; without it the target is
-- swapped for the cast and put straight back (CastAtEnemy). With SuperWoW the frame
-- also becomes the game's own "mouseover" unit, so mouseover macros (pfUI's /pfcast)
-- work on it too.

function A:HoverEnter(i)
  self.hover = i
  local e = self:EnemyAt(i)
  local f = self.Frames and self.Frames.frames[i]
  if e and not e.fake and e.guid and A.UseSW() then
    if SetMouseoverUnit then pcall(SetMouseoverUnit, e.guid) end
    if f then f.label, f.id = e.guid, "" end     -- pfUI's /pfcast reads label .. id
  elseif f then
    f.label, f.id = nil, nil
  end
end

function A:HoverLeave(i)
  if self.hover ~= i then return end
  self.hover = nil
  if SetMouseoverUnit then pcall(SetMouseoverUnit) end
end

-- The enemy under the mouse: anywhere on their block (buff row, frame, cast bar,
-- cooldown row), asked at the moment of the cast. The frame itself is only the top
-- row, so OnEnter alone missed the mouse on the cast bar or the cooldowns.
function A:Hovered()
  local F = self.Frames
  if not F or not F.frames or not F.anchor or not F.anchor:IsVisible() then return nil end
  local m = F.m
  if MouseIsOver and m then
    local up, down = m.top or 0, -((m.total or m.H) - m.H)
    for i = 1, self:Max() do
      local f = F.frames[i]
      if f and f:IsVisible() and MouseIsOver(f, up, down, 0, 0) then
        local e = self:EnemyAt(i)
        if e and not e.fake then return e, i end
        return nil
      end
    end
    return nil
  end
  local i = self.hover          -- no MouseIsOver: what OnEnter said
  local e = i and self:EnemyAt(i)
  if e and not e.fake then return e, i end
  return nil
end

-- What kind of spell: "harm" (aimed at an enemy), "help" (heals, buffs on others) or
-- "self" (no target). ClassicAPI says it straight; without it the spell book tooltip:
-- a range line means it takes a target, healing / friendly words make that helpful.
local kindCache = {}
local HELP_WORDS = { "heal", "restor", "friendly", "party member", "raid member", "ally", "allies", "resurrect" }
local scanTip
local function ScanTip()
  if not scanTip then scanTip = CreateFrame("GameTooltip", "OctoArenaScanTip", nil, "GameTooltipTemplate") end
  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanTip:ClearLines()
  return scanTip
end
local function BookSlot(name)
  if not GetSpellName then return nil end
  local found
  for i = 1, 400 do
    local n = GetSpellName(i, "spell")
    if not n then break end
    if n == name then found = i end     -- the last one is the highest rank
  end
  return found
end
local function Ask(fn, a, b)
  if not fn then return nil end
  local ok, v = pcall(fn, a, b)
  if ok then return v and true or false end
  return nil
end
function A:SpellKind(name)
  if not name then return nil end
  if kindCache[name] then return kindCache[name] end
  local kind
  local slot = BookSlot(name)
  local help = Ask(IsHelpfulSpell or IsSpellHelpful, name)
  local harm = Ask(IsHarmfulSpell or IsSpellHarmful, name)
  if slot and help == nil and harm == nil then
    help = Ask(IsHelpfulSpell or IsSpellHelpful, slot, "spell")
    harm = Ask(IsHarmfulSpell or IsSpellHarmful, slot, "spell")
  end
  -- only a yes from the API counts: whether it answers no as false or nil (and for
  -- a name at all) is not known on this client, so a no falls through to the tooltip
  if help then kind = "help" elseif harm then kind = "harm"
  elseif slot then
    local tip = ScanTip()
    tip:SetSpell(slot, "spell")
    local ranged, helps = false, false
    for l = 1, 12 do
      for _, side in ipairs({ "Left", "Right" }) do
        local fs = getglobal("OctoArenaScanTipText" .. side .. l)
        local t = fs and fs:GetText()
        if t then
          local low = string.lower(t)
          if string.find(low, "yd range", 1, true) or string.find(low, "melee range", 1, true) then ranged = true end
          if l > 1 then
            for w = 1, table.getn(HELP_WORDS) do
              if string.find(low, HELP_WORDS[w], 1, true) then helps = true end
            end
          end
        end
      end
    end
    if helps then kind = "help" elseif ranged then kind = "harm" else kind = "self" end
  end
  if kind then kindCache[name] = kind end
  return kind
end
A:On("SPELLS_CHANGED", function() for k in pairs(kindCache) do kindCache[k] = nil end end)

local function IsKick(self, name)
  local s = A.BYNAME[name]
  if s and (s.k == "interrupt" or s.k == "silence") then return true end
  if not self.myKicks then self:ScanMyKicks() end
  for k = 1, table.getn(self.myKicks or {}) do
    if self.myKicks[k].name == name then return true end
  end
  return false
end

-- Is this spell one that should go to the frame under the mouse?
--   harmful (default): every offensive spell, your interrupts always
--   kicks: interrupts only; all: everything; off
function A:MouseCastWants(name)
  local mode = self.db and self.db.mouseCast
  if not name or not mode or mode == "off" then return false end
  if mode == "all" then return true end
  if IsKick(self, name) then return true end
  if mode == "harmful" then return self:SpellKind(name) == "harm" end
  return false
end

-- The last few decisions, for /oaf mouse.
A.mouseLog = {}
function A:MouseNote(text)
  table.insert(self.mouseLog, date and (date("%H:%M:%S") .. "  " .. text) or text)
  if table.getn(self.mouseLog) > 10 then table.remove(self.mouseLog, 1) end
end

local inside = false
-- Cast this spell at the hovered enemy. true = done here, the game's own cast is skipped.
function A:MouseCast(name)
  if inside or not name or not self.db or self.db.mouseCast == "off" then return false end
  local e, i = self:Hovered()
  if not e then return false end
  if not self:MouseCastWants(name) then
    self:MouseNote(name .. " over enemy " .. i .. ": left alone (" .. tostring(self:SpellKind(name) or "unknown") .. ")")
    return false
  end
  inside = true
  local ok, err = pcall(self.CastAtEnemy, self, i, name)
  inside = false
  self:MouseNote(name .. " -> enemy " .. i .. " " .. e.name .. (e.guid and A.UseSW() and " (by GUID)" or " (target swap)")
    .. (ok and "" or ("  ERROR " .. tostring(err))))
  if not ok and table.getn(A.errors) < 30 then table.insert(A.errors, "mouse cast: " .. tostring(err)) end
  return true
end

-- "Kick (Rank 2)" -> "Kick"
local function BareName(spell)
  if type(spell) ~= "string" then return nil end
  local s = string.gsub(spell, "%(.-%)", "")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end
A.BareName = BareName

-- The spell on an action slot, by its tooltip (1.12 has no other way); cached per
-- slot and picture, so a changed button is read again. Macros are left to /cast.
local slotCache = {}
function A:ActionSpell(slot)
  if not slot or (GetActionText and GetActionText(slot)) then return nil end
  local tex = GetActionTexture and GetActionTexture(slot)
  if not tex then return nil end
  local c = slotCache[slot]
  if c and c.tex == tex then return c.name end
  local scanTip = ScanTip()
  scanTip:SetAction(slot)
  local line = getglobal("OctoArenaScanTipTextLeft1")
  local name = line and line:GetText()
  slotCache[slot] = { tex = tex, name = name }
  return name
end

-- Wrap the three ways a spell is cast. Done once, after every addon has loaded, so
-- whatever they hooked still runs for every cast that is not redirected.
function A:HookMouseCast()
  if self.mouseHooked then return end
  self.mouseHooked = true
  local castByName, useAction, castSpell = CastSpellByName, UseAction, CastSpell
  if castByName then
    CastSpellByName = function(spell, a2)
      if a2 == nil and not inside and A:Hovered() and A:MouseCast(BareName(spell)) then return end
      return castByName(spell, a2)
    end
  end
  if useAction then
    UseAction = function(slot, a2, a3)
      if not inside and A.db.mouseCast ~= "off" and A:Hovered() and A:MouseCast(A:ActionSpell(slot)) then return end
      return useAction(slot, a2, a3)
    end
  end
  if castSpell then
    CastSpell = function(id, book)
      if not inside and book ~= "pet" and GetSpellName and A:Hovered() then
        local name = GetSpellName(id, book)
        if A:MouseCast(name) then return end
      end
      return castSpell(id, book)
    end
  end
end
A:On("PLAYER_ENTERING_WORLD", function() A:HookMouseCast() end)

-- Key binding / macro: your interrupt at the enemy under the mouse.
function A:KickHovered()
  local _, i = self:Hovered()
  if i then self:KickEnemy(i) end
end

A:On("PLAYER_TARGET_CHANGED", function() A.dirty = true end)
A:On("PLAYER_FOCUS_CHANGED", function() A.dirty = true end)
