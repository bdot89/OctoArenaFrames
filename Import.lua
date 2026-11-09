-- OctoArenaFrames :: taking over from OctoKicks
-- The first time this runs on a character with OctoKicks still enabled, its named
-- enemies, format, look and number settings are copied across. OctoKicks' own files
-- and saved settings are only read, never changed. Both running together would double
-- every sound and call-out, so a popup offers to switch OctoKicks off (one click, and
-- it can be switched back on in the addon list at any time).

local A = OctoArenaFrames

-- settings with the same meaning in both, under the same name
local SAME = {
  "bgAuto", "detection", "resetOnZone", "bgIconSize", "bgRows", "bgNames", "bgDim", "bgPos", "border", "shadow",
  "sweep", "desat", "pop", "unusedAlpha", "showText", "numFont", "numSize", "numOutline", "numPos", "numFormat",
  "numDecimals", "numColor", "soonColor", "soonAt", "soundUse", "soundUseFile", "soundReady", "soundReadyFile",
  "flashReady", "announce", "printChat", "nameFont", "fontSize",
}

function A:ImportOctoKicks()
  local old = OctoKicksDB
  if type(old) ~= "table" then return end
  if not self.db.kicksImported then
    self.db.kicksImported = true
    for _, k in ipairs(SAME) do
      if old[k] ~= nil then self.db[k] = A.Copy(old[k]) end
    end
    -- a tournament setup comes across whole; an empty strict setup would leave
    -- arenas with no frames, so OctoKicks' defaults are not copied
    local named = false
    if type(old.slots) == "table" then
      for i = 1, A.MAX do
        local s = old.slots[i]
        if type(s) == "table" and s.name and not s.auto then
          named = true
          self.db.slots[i] = { name = s.name, class = s.class }
          local e = self.enemies[i]
          e.name, e.class = s.name, s.class
          self.byName[A.Key(s.name)] = e
        end
      end
    end
    if named then
      if old.mode == "strict" then self.db.mode = "strict" end
      if old.format and old.format ~= "bg" then self.db.format = old.format end
    end
    -- cooldowns the user typed in on purpose stay; spells it switched off stay off
    if type(old.spells) == "table" then
      for name, o in pairs(old.spells) do
        if A.BYNAME[name] and type(o) == "table" then
          local t = {}
          if o.cd then t.cd = o.cd end
          if o.on == false then t.tier = 0 end
          if o.prio ~= nil then t.prio = o.prio end
          self.db.spells[name] = t
        end
      end
    end
    self:Print("OctoKicks' settings copied across. OctoKicks' own files were not touched.")
  end
  if IsAddOnLoaded and IsAddOnLoaded("OctoKicks") then
    self.kicksRunning = true
    self.askKicks = true
  end
end

StaticPopupDialogs["OCTOARENA_KICKS"] = {
  text = "OctoArenaFrames now does everything OctoKicks did.\n\nSwitch OctoKicks off and reload? (You can switch it back on in the addon list.)",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    DisableAddOn("OctoKicks")
    ReloadUI()
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
}

A:On("PLAYER_ENTERING_WORLD", function()
  if A.askKicks then
    A.askKicks = nil
    StaticPopup_Show("OCTOARENA_KICKS")
  end
  if A.firstRun then
    A.firstRun = nil
    A:Print("type |cffffff00/oaf|r for options, |cffffff00/oaf test|r to see the frames. They show by themselves in arenas.")
  end
end)
