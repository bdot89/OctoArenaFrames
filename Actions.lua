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

A:On("PLAYER_TARGET_CHANGED", function() A.dirty = true end)
A:On("PLAYER_FOCUS_CHANGED", function() A.dirty = true end)
