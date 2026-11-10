-- OctoArenaFrames :: options window (/oaf, or the Esc menu)
-- Same flat look and sidebar as OctoKicks: Match, Frames, Cooldowns, Strips, Spells,
-- Alerts, Profiles. Every control re-reads its setting in O:Refresh, so slash commands
-- and the frames stay in step with the window. Help is in tooltips, not on the page.

local A = OctoArenaFrames
local I = A.Icons
local O = { refresh = {}, pages = {}, tabs = {} }
A.Options = O

local WHITE = "Interface\\Buttons\\WHITE8X8"
local W, H = 720, 650
local SIDE = 150
local ACCENT = { 0.2, 0.62, 1 }
local BG = { 0.055, 0.06, 0.075 }
local PANEL = { 0.085, 0.09, 0.11 }
local LINE = { 0.2, 0.21, 0.25 }

-- ---------------------------------------------------------------- widgets

local function Flat(f, c, a, edge)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(c[1], c[2], c[3], a or 1)
  local e = edge or LINE
  f:SetBackdropBorderColor(e[1], e[2], e[3], 1)
end

local function Text(parent, size, r, g, b)
  local t = parent:CreateFontString(nil, "OVERLAY")
  t:SetFont(A.UI_FONT, size or 11, "")
  t:SetTextColor(r or 0.88, g or 0.89, b or 0.92)
  t:SetJustifyH("LEFT")
  return t
end

local function Tip(f, text)
  if not text then return end
  f:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(text, 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Button(parent, label, w, onClick, tip, h)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(w)
  b:SetHeight(h or 22)
  Flat(b, { 0.13, 0.135, 0.165 })
  b.label = Text(b, 11)
  b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.label:SetJustifyH("CENTER")
  b.label:SetText(label)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function() onClick(this, arg1) end)
  b:SetScript("OnEnter", function()
    this:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    if tip then
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(tip, 1, 1, 1, 1)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function()
    this:SetBackdropBorderColor(LINE[1], LINE[2], LINE[3], 1)
    GameTooltip:Hide()
  end)
  return b
end

-- a button that looks pressed when on
local function SetOn(b, on)
  if on then
    b:SetBackdropColor(ACCENT[1] * 0.45, ACCENT[2] * 0.45, ACCENT[3] * 0.45, 1)
    b.label:SetTextColor(1, 1, 1)
  else
    b:SetBackdropColor(0.13, 0.135, 0.165, 1)
    b.label:SetTextColor(0.7, 0.72, 0.76)
  end
end

-- slim on/off switch with a label
local function Switch(parent, label, get, set, tip, w)
  local c = CreateFrame("Button", nil, parent)
  c:SetWidth(w or 250)
  c:SetHeight(20)
  local track = c:CreateTexture(nil, "ARTWORK")
  track:SetTexture(WHITE)
  track:SetWidth(26)
  track:SetHeight(12)
  track:SetPoint("LEFT", c, "LEFT", 0, 0)
  local knob = c:CreateTexture(nil, "OVERLAY")
  knob:SetTexture(WHITE)
  knob:SetWidth(10)
  knob:SetHeight(10)
  local t = Text(c, 11)
  t:SetPoint("LEFT", track, "RIGHT", 8, 0)
  t:SetText(label)
  c:SetScript("OnClick", function()
    set(not get())
    A:Changed()
  end)
  Tip(c, tip)
  table.insert(O.refresh, function()
    knob:ClearAllPoints()
    if get() then
      track:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
      knob:SetVertexColor(1, 1, 1)
      knob:SetPoint("RIGHT", track, "RIGHT", -1, 0)
    else
      track:SetVertexColor(0.22, 0.23, 0.27)
      knob:SetVertexColor(0.6, 0.62, 0.66)
      knob:SetPoint("LEFT", track, "LEFT", 1, 0)
    end
  end)
  return c
end

local function Slider(parent, label, lo, hi, step, get, set, fmt)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(250)
  f:SetHeight(32)
  local t = Text(f, 11)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  local val = Text(f, 11, 1, 1, 1)
  val:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, 0)
  val:SetJustifyH("RIGHT")
  t:SetText(label)
  local s = CreateFrame("Slider", nil, f)
  s:SetOrientation("HORIZONTAL")
  s:SetWidth(240)
  s:SetHeight(14)
  s:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -15)
  s:EnableMouse(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetTexture(WHITE)
  track:SetVertexColor(0.18, 0.19, 0.23)
  track:SetHeight(4)
  track:SetPoint("LEFT", s, "LEFT", 0, 0)
  track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
  -- as OctoBG: thumb by path, then size and colour the texture it made
  s:SetThumbTexture(WHITE)
  local thumb = s.GetThumbTexture and s:GetThumbTexture()
  if thumb then
    thumb:SetWidth(8)
    thumb:SetHeight(14)
    thumb:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
  end
  s:SetMinMaxValues(lo, hi)
  s:SetValueStep(step)
  local busy = false
  local function Show(v) val:SetText(fmt and fmt(v) or tostring(v)) end
  s:SetScript("OnValueChanged", function()
    if busy then return end
    local v = math.floor(this:GetValue() / step + 0.5) * step
    if step < 1 then v = math.floor(v * 100 + 0.5) / 100 end
    set(v)
    Show(v)
    A:Changed()
  end)
  table.insert(O.refresh, function()
    busy = true
    s:SetValue(get())
    busy = false
    Show(get())
  end)
  return f
end

-- click: next choice, right-click: previous. choices = { { value, label }, ... }
local function Cycle(parent, label, choices, get, set, w, tip)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(250)
  f:SetHeight(22)
  local t = Text(f, 11)
  t:SetPoint("LEFT", f, "LEFT", 0, 0)
  t:SetText(label)
  local b = Button(f, "", w or 130, function(_, button)
    local cur, n = get(), table.getn(choices)
    local idx = 1
    for i = 1, n do if choices[i][1] == cur then idx = i end end
    if button == "RightButton" then idx = idx - 1 else idx = idx + 1 end
    if idx > n then idx = 1 elseif idx < 1 then idx = n end
    set(choices[idx][1])
    A:Changed()
  end, tip or "Click for the next choice, right-click for the previous one.")
  b:SetPoint("RIGHT", f, "RIGHT", -6, 0)
  table.insert(O.refresh, function()
    local cur = get()
    local text = tostring(cur)
    for i = 1, table.getn(choices) do
      if choices[i][1] == cur then text = choices[i][2] end
    end
    b.label:SetText(text .. "  |cff6f7380>|r")
  end)
  f.button = b
  return f
end

local function Edit(parent, w, onCommit)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetWidth(w)
  e:SetHeight(22)
  e:SetAutoFocus(false)
  e:SetFont(A.UI_FONT, 11, "")
  e:SetTextColor(1, 1, 1)
  e:SetTextInsets(6, 6, 0, 0)
  Flat(e, { 0.04, 0.045, 0.055 })
  e:SetScript("OnEscapePressed", function() this:ClearFocus() O:Refresh() end)
  e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  e:SetScript("OnEditFocusGained", function() this.focused = true end)
  e:SetScript("OnEditFocusLost", function()
    this.focused = nil
    if onCommit then onCommit(this:GetText()) end
  end)
  return e
end

-- widgets stack down a column: Col(page, x) then col:Add(widget, gap)
local function Col(page, x, y)
  local c = { page = page, x = x, y = y or -4 }
  function c:Add(w, gap)
    w:SetPoint("TOPLEFT", self.page, "TOPLEFT", self.x, self.y)
    self.y = self.y - w:GetHeight() - (gap or 6)
    return w
  end
  return c
end

-- section title with a hairline under it
local function Heading(page, text, w)
  local f = CreateFrame("Frame", nil, page)
  f:SetWidth(w or 250)
  f:SetHeight(22)
  local t = Text(f, 12, 1, 1, 1)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
  t:SetText(text)
  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetTexture(WHITE)
  line:SetVertexColor(LINE[1], LINE[2], LINE[3])
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 2)
  line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 2)
  return f
end

local function Note(page, text, w, h)
  local f = CreateFrame("Frame", nil, page)
  f:SetWidth(w or 530)
  f:SetHeight(h or 14)
  local t = Text(f, 10, 0.6, 0.62, 0.68)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  t:SetWidth(w or 530)
  t:SetText(text)
  f.text = t
  return f
end

local function Num(key) return function() return A.db[key] end, function(v) A.db[key] = v end end
local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end
local function pxs(v) return v .. " px" end

local function FontChoices()
  local out = {}
  for _, f in ipairs(A.FONTS) do table.insert(out, { f.key, f.label }) end
  return out
end

-- ---------------------------------------------------------------- window

local PAGES = { "Match", "Frames", "Cooldowns", "Strips", "Spells", "Alerts", "Profiles" }

function O:Build()
  if self.win then return end
  local win = CreateFrame("Frame", "OctoArenaOptions", UIParent)
  win:SetWidth(W)
  win:SetHeight(H)
  win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  win:SetFrameStrata("DIALOG")
  win:SetMovable(true)
  win:EnableMouse(true)
  win:SetClampedToScreen(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function() this:StartMoving() end)
  win:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  Flat(win, BG, 0.98)
  table.insert(UISpecialFrames, "OctoArenaOptions")
  self.win = win

  -- sidebar
  local side = CreateFrame("Frame", nil, win)
  side:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
  side:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 1, 1)
  side:SetWidth(SIDE)
  side:SetBackdrop({ bgFile = WHITE })
  side:SetBackdropColor(PANEL[1], PANEL[2], PANEL[3], 1)
  local accent = side:CreateTexture(nil, "ARTWORK")
  accent:SetTexture(WHITE)
  accent:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
  accent:SetWidth(3)
  accent:SetHeight(26)
  accent:SetPoint("TOPLEFT", side, "TOPLEFT", 12, -14)
  local title = Text(side, 13, 1, 1, 1)
  title:SetPoint("TOPLEFT", side, "TOPLEFT", 22, -14)
  title:SetText("OctoArenaFrames")
  local ver = Text(side, 9, 0.5, 0.52, 0.58)
  ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  ver:SetText("arena frames  " .. A.VERSION)

  for i = 1, table.getn(PAGES) do
    local idx = i
    local tab = CreateFrame("Button", nil, side)
    tab:SetWidth(SIDE)
    tab:SetHeight(30)
    tab:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -60 - (i - 1) * 32)
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetTexture(WHITE)
    tab.bg:SetAllPoints(tab)
    tab.mark = tab:CreateTexture(nil, "ARTWORK")
    tab.mark:SetTexture(WHITE)
    tab.mark:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
    tab.mark:SetWidth(3)
    tab.mark:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    tab.mark:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    tab.label = Text(tab, 12)
    tab.label:SetPoint("LEFT", tab, "LEFT", 22, 0)
    tab.label:SetText(PAGES[i])
    tab:SetScript("OnClick", function() O:ShowPage(idx) end)
    self.tabs[i] = tab
    local page = CreateFrame("Frame", nil, win)
    page:SetPoint("TOPLEFT", win, "TOPLEFT", SIDE + 18, -46)
    page:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    page:Hide()
    self.pages[i] = page
  end

  -- page title + close
  self.pageTitle = Text(win, 15, 1, 1, 1)
  self.pageTitle:SetPoint("TOPLEFT", win, "TOPLEFT", SIDE + 18, -16)
  local close = Button(win, "x", 24, function() win:Hide() end, nil, 24)
  close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -10)

  -- sidebar foot: status + the things you need while setting up
  local status = Text(side, 10)
  status:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 14, 152)
  local status2 = Text(side, 10)
  status2:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 14, 138)
  status2:SetTextColor(0.62, 0.66, 0.72)
  local full = Button(side, "Full test", SIDE - 24, function()
    if A.testFull then A:SetTest(false) else A:SetTest(true, true) end
  end, "Everything at once until you stop it: every frame (all five when the format is Auto), casts, kicks with school lockouts, crowd control with diminishing returns, cooldowns, trinkets, racials and the interrupt bar. In BG / World it fills the rows. Never announces or plays sounds. Entering an arena stops it.")
  full:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 12, 106)
  local test = Button(side, "Test mode", SIDE - 24, function()
    if A.test then A:SetTest(false) else A:SetTest(true) end
  end, "Sample enemies cast, get crowd controlled and use cooldowns for 60 seconds, so you can place and size everything. Never announces or plays sounds.")
  test:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 12, 76)
  local lock = Button(side, "Lock frames", SIDE - 24, function() A.db.locked = not A.db.locked A:Changed() end,
    "Unlocked, the frames have a bar on top: drag it (or a frame) to move, right-click it for these options.")
  lock:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 12, 46)
  local reset = Button(side, "Reset position", SIDE - 24, function()
    if A:IsBG() then A.db.bgPos = nil else A.db.pos = nil end
    A.Frames:Place()
    A.Bars:Place()
    A:Changed()
  end, "Moves the frames (or the BG / World rows while they are in use) back to where they start.")
  reset:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 12, 16)
  table.insert(self.refresh, function()
    local tag, size, count, r, g, b = A:StatusParts()
    status:SetText(tag .. (size and ("  |cffdddddd" .. size .. "|r") or ""))
    status:SetTextColor(r, g, b)
    status2:SetText(count or "")
    SetOn(full, A.testFull)
    full.label:SetText(A.testFull and "Stop full test" or "Full test")
    SetOn(test, A.test and not A.testFull)
    test.label:SetText((A.test and not A.testFull) and "Stop test" or "Test mode")
    SetOn(lock, not A.db.locked)
    lock.label:SetText(A.db.locked and "Unlock frames" or "Lock frames")
  end)

  self:BuildMatch(self.pages[1])
  self:BuildFrames(self.pages[2])
  self:BuildCooldowns(self.pages[3])
  self:BuildStrips(self.pages[4])
  self:BuildSpells(self.pages[5])
  self:BuildAlerts(self.pages[6])
  self:BuildProfiles(self.pages[7])
  win:SetScript("OnShow", function() O:Refresh() end)
  win:Hide()   -- new frames start shown; Toggle opens it
  self:ShowPage(1)
end

function O:ShowPage(n)
  for i = 1, table.getn(self.pages) do
    local tab = self.tabs[i]
    if i == n then
      self.pages[i]:Show()
      tab.bg:SetVertexColor(ACCENT[1] * 0.18, ACCENT[2] * 0.18, ACCENT[3] * 0.22, 1)
      tab.mark:Show()
      tab.label:SetTextColor(1, 1, 1)
    else
      self.pages[i]:Hide()
      tab.bg:SetVertexColor(0, 0, 0, 0)
      tab.mark:Hide()
      tab.label:SetTextColor(0.62, 0.64, 0.7)
    end
  end
  self.pageTitle:SetText(PAGES[n])
  self.page = n
  self:Refresh()
end

function O:Toggle()
  self:Build()
  if self.win:IsShown() then self.win:Hide() else self.win:Show() end
end

function O:Refresh()
  if not self.win or not self.win:IsShown() then return end
  for _, fn in ipairs(self.refresh) do fn() end
end

-- ---------------------------------------------------------------- Match

local CLASS_CHOICES = { { "none", "Class?" } }
for _, c in ipairs(A.CLASSES) do table.insert(CLASS_CHOICES, { c, A.CLASS_LABEL[c] }) end

function O:BuildMatch(p)
  local col = Col(p, 0)
  col:Add(Heading(p, "Format", 530), 8)
  local fmts = {}
  for i = 1, table.getn(A.FORMATS) do
    local f = A.FORMATS[i][1]
    local b = Button(p, A.FORMATS[i][2], i == 5 and 110 or 70, function() A:SetFormat(f) end, nil, 26)
    if i == 1 then col:Add(b, 6) else b:SetPoint("LEFT", fmts[i - 1], "RIGHT", 6, 0) end
    fmts[i] = b
  end
  local fmtNote = col:Add(Note(p, "", 530, 28), 4)
  col:Add(Switch(p, "Arenas find out the size by themselves (2v2, 3v3, 5v5)", function() return A.db.arenaDetect end,
    function(v) A.db.arenaDetect = v end,
    "In a match the frames follow that match: the server's team list when it comes, else the size of your own group "
    .. "(teammates still loading count). Off: the format above is used in arenas too.", 400), 4)
  col:Add(Switch(p, "Battlegrounds switch to BG / World on their own", function() return A.db.bgAuto end,
    function(v) A.db.bgAuto = v end,
    "Inside a battleground the frames make way for rows of enemy cooldowns; outside it goes back to the format above. "
    .. "Arenas always use the frames.", 400), 10)

  col:Add(Heading(p, "Who is tracked", 530), 8)
  local auto = Button(p, "Auto", 90, function() A.db.mode = "auto" A:Changed() end,
    "In an arena the frames fill by themselves with the players you are fighting.", 24)
  col:Add(auto, 6)
  local strict = Button(p, "Strict", 90, function() A.db.mode = "strict" A:Changed() end,
    "Tournament setting: only the players named below are tracked.", 24)
  strict:SetPoint("LEFT", auto, "RIGHT", 6, 0)
  local modeNote = col:Add(Note(p, "", 530, 28), 4)
  col:Add(Switch(p, "Auto also fills outside arenas (open world duels)", function() return A.db.worldFill end,
    function(v) A.db.worldFill = v end, "Any hostile player seen using a tracked spell takes a free slot until the next loading screen.", 400), 2)
  col:Add(Switch(p, "Without ClassicAPI: find enemies with a quick target swap", function() return A.db.huntTarget end,
    function(v) A.db.huntTarget = v end,
    "Only for players without ClassicAPI, only before combat, and your target goes straight back. "
    .. "With ClassicAPI enemies are found by name with no target swap.", 400), 4)
  local detect = Cycle(p, "Detection", { { "auto", "SuperWoW if found" }, { "log", "Combat log only" } },
    function() return A.db.detection end, function(v) A.db.detection = v A:RegisterLog() end, 150,
    "SuperWoW reads every cast with the player's ID: exact, and health for all of them. The combat log matches by name. Only one is used at a time.")
  detect:SetWidth(300)
  col:Add(detect, 2)
  local detectNote = col:Add(Note(p, "", 530, 14), 4)
  local when = Cycle(p, "Show the frames", { { "arena", "Only in arenas" }, { "set", "Arenas + named enemies" }, { "always", "Always" } },
    function() return A.db.showWhen end, function(v) A.db.showWhen = v end, 150,
    "They always show while unlocked or in test mode.")
  when:SetWidth(300)
  col:Add(when, 10)

  local head = col:Add(Heading(p, "Enemies", 530), 8)
  local clearAll = Button(head, "Clear all", 80, function() A:ClearSlots() end, nil, 18)
  clearAll:SetPoint("RIGHT", head, "RIGHT", -6, 2)
  local resetCd = Button(head, "Reset cooldowns", 110, function() A:ResetCooldowns() end,
    "Marks every enemy spell as ready (for example between rounds).", 18)
  resetCd:SetPoint("RIGHT", clearAll, "LEFT", -6, 0)
  local bgNote = Note(p, "BG / World has no slots: every enemy near you who uses a tracked spell gets a row of icons "
    .. "(your target's first) that disappears when their spells are ready.", 530, 28)
  bgNote:SetPoint("TOPLEFT", p, "TOPLEFT", 0, col.y)
  local rows = {}
  for i = 1, A.MAX do
    local idx = i
    local row = CreateFrame("Frame", nil, p)
    row:SetWidth(530)
    row:SetHeight(24)
    col:Add(row, 4)
    local lab = Text(row, 11, 0.7, 0.72, 0.78)
    lab:SetPoint("LEFT", row, "LEFT", 0, 0)
    lab:SetText("Enemy " .. i)
    local e = Edit(row, 140, function(text)
      local name = A.CleanName(text)
      local slot = A.db.slots[idx]
      if name ~= slot.name then A:SetSlot(idx, name, slot.class) end
    end)
    e:SetPoint("LEFT", row, "LEFT", 62, 0)
    local cls = Cycle(row, "", CLASS_CHOICES,
      function() return A.db.slots[idx].class or "none" end,
      function(v)
        if A.db.slots[idx].name then
          A.db.slots[idx].class = (v ~= "none") and v or nil
          A.enemies[idx].class = A.db.slots[idx].class
        end
      end, 96,
      "The enemy's class decides which icons show before they use anything. Set automatically from your target or their first cast.")
    cls:SetWidth(102)
    cls:SetPoint("LEFT", e, "RIGHT", 4, 0)
    local tgt = Button(row, "From target", 92, function() A:SetFromTarget(idx) end,
      "Target the player and click: name and class are filled in. Works on friendly players too, for practice.")
    tgt:SetPoint("LEFT", cls, "RIGHT", 4, 0)
    local clr = Button(row, "Clear", 52, function() A:SetSlot(idx, nil) end)
    clr:SetPoint("LEFT", tgt, "RIGHT", 6, 0)
    local tag = Text(row, 10, 1, 0.7, 0.1)
    tag:SetPoint("LEFT", clr, "RIGHT", 8, 0)
    rows[i] = row
    table.insert(self.refresh, function()
      local slot = A.db.slots[idx]
      if not e.focused then e:SetText(slot.name or "") end
      tag:SetText(slot.auto and "auto" or "")
    end)
  end
  local opts = Col(p, 0, col.y - 2)
  opts:Add(Switch(p, "Reset cooldowns on every loading screen", function() return A.db.resetOnZone end,
    function(v) A.db.resetOnZone = v end, "A new match starts with every enemy spell ready.", 400), 2)
  local ignored = opts:Add(Note(p, "", 530, 14), 2)
  opts:Add(Note(p, "Keys: Esc > Key Bindings > OctoArenaFrames (target, focus, interrupt enemy 1-5). "
    .. "Macros: /oaf target 1, /oaf kick 2, /oaf cast 2 Polymorph. Click a frame: target. Right: focus. Middle: your interrupt.", 530, 28))

  table.insert(self.refresh, function()
    local bg = A:IsBG()
    for i = 1, table.getn(A.FORMATS) do SetOn(fmts[i], A.db.format == A.FORMATS[i][1]) end
    if bg and A.db.format ~= "bg" then
      fmtNote.text:SetText("|cff8cd1ffIn a battleground now: BG / World is in use.|r Your " .. A.FormatLabel(A.db.format)
        .. " setup comes back when you leave.")
    elseif bg then
      fmtNote.text:SetText("No frames and no names: enemy cooldowns pop up in a row per player near you and shrink away when ready.")
    elseif A.zone == "arena" and A:Format() == "auto" then
      fmtNote.text:SetText("|cff8cd1ffIn an arena now: " .. A:MatchSize() .. "|r, found out for this match.")
    elseif A.db.format == "auto" then
      fmtNote.text:SetText("As many frames as your own team in an arena, more if more enemies show up. Up to five.")
    elseif A.db.arenaDetect then
      fmtNote.text:SetText(A:Max() .. " frames here. In an arena the match's own size is used.")
    else
      fmtNote.text:SetText(A:Max() .. " frames, whoever is in them yet.")
    end
    SetOn(strict, A.db.mode == "strict")
    SetOn(auto, A.db.mode == "auto")
    if A.db.mode == "strict" then
      modeNote.text:SetText("|cff33dd55Strict:|r only the players below are tracked. Casts from anyone else - spectators, "
        .. "other duels, teammates - are ignored. Best for a tournament.")
    else
      modeNote.text:SetText("|cffffaa11Auto:|r in an arena the frames fill with the players you are fighting and stay in that "
        .. "order all match; forgotten at the next loading screen. Names below stay.")
    end
    detectNote.text:SetText(A:DetectionText())
    local fixed = 5
    if A.db.format == "2v2" then fixed = 2 elseif A.db.format == "3v3" then fixed = 3 end
    for i = 1, A.MAX do
      if not bg and i <= fixed then rows[i]:Show() else rows[i]:Hide() end
    end
    if bg then bgNote:Show() else bgNote:Hide() end
    ignored.text:SetText(A:RosterText() .. "  Casts ignored this session: " .. A.ignored)
  end)
end

-- ---------------------------------------------------------------- Frames

function O:BuildFrames(p)
  local L = Col(p, 0)
  local R = Col(p, 275)
  local g, s
  local function place() A.Frames:Place() end

  L:Add(Heading(p, "Frame"), 6)
  g = function() return A.db.scale end
  s = function(v) A.db.scale = v place() A.Bars:Place() end
  L:Add(Slider(p, "Scale", 0.5, 2, 0.05, g, s, pct))
  g, s = Num("alpha") L:Add(Slider(p, "Opacity", 0.2, 1, 0.05, g, s, pct))
  g, s = Num("barW") L:Add(Slider(p, "Bar width", 100, 300, 2, g, s, pxs))
  g, s = Num("frameH") L:Add(Slider(p, "Height", 32, 72, 2, g, s, pxs))
  g, s = Num("powerH") L:Add(Slider(p, "Power bar height", 4, 20, 1, g, s, pxs))
  g, s = Num("spacing") L:Add(Slider(p, "Gap between enemies", 0, 40, 1, g, s, pxs))
  local bars = {}
  for _, b in ipairs(A.BARS) do table.insert(bars, { b.key, b.label }) end
  L:Add(Cycle(p, "Bar look", bars, function() return A.db.barTex end, function(v) A.db.barTex = v end), 4)
  L:Add(Cycle(p, "Name font", FontChoices(), function() return A.db.nameFont end, function(v) A.db.nameFont = v end), 4)
  g, s = Num("fontSize") L:Add(Slider(p, "Name size", 8, 20, 1, g, s))
  L:Add(Cycle(p, "Frames grow", { { "DOWN", "Down" }, { "UP", "Up" } },
    function() return A.db.grow end, function(v)
      A.db.grow = v
      if A.db.pos then A.Frames:SavePos() else place() end
    end), 4)
  g, s = Num("mirror") L:Add(Switch(p, "Mirror (icon on the right)", g, s,
    "For frames on the left of the screen: the class icon goes right, and diminishing returns grow to the right."), 8)
  L:Add(Cycle(p, "Mouseover casting", { { "harmful", "Offensive spells" }, { "kicks", "Interrupts only" },
      { "all", "Every spell" }, { "off", "Off" } },
    function() return A.db.mouseCast end, function(v) A.db.mouseCast = v end, 120,
    "With the mouse anywhere on an enemy's frame (buffs, bars, cast bar, cooldowns), your offensive spells and "
    .. "interrupts go to that enemy: action buttons, their keys, /cast macros and the spell book. Your target does "
    .. "not change. Heals and self buffs cast as usual. /oaf mouse shows what it did with your last presses. "
    .. "Key binding: Interrupt the enemy under the mouse."), 8)
  L:Add(Button(p, "Reset layout", 120, function() A:ResetLayout() end,
    "Frames, Cooldowns, Strips, Spells and Alerts back to default. Keeps the enemies and the format."))

  R:Add(Heading(p, "What a frame shows"), 4)
  g, s = Num("showName") R:Add(Switch(p, "Name", g, s), 1)
  g, s = Num("showSpec") R:Add(Switch(p, "Talent tree, once a talent spell is seen", g, s,
    "1.12 cannot read an enemy's talents. When they use a talent spell, its tree shows next to their name."), 1)
  g, s = Num("showNumber") R:Add(Switch(p, "Enemy number before the name", g, s, "A gold 1, 2, 3 in front of each name, for calling targets on voice (\"kill 2\"). The same number your keys, macros and /oaf target use. With names off it shows on the icon."), 1)
  R:Add(Cycle(p, "Health text", { { "percent", "Percent" }, { "none", "None" } },
    function() return A.db.hpText end, function(v) A.db.hpText = v end, 90), 2)
  g, s = Num("showEnemyTarget") R:Add(Switch(p, "Who they target (> YOU in red)", g, s), 1)
  g, s = Num("classBars") R:Add(Switch(p, "Class colour health bar", g, s), 1)
  g, s = Num("dimFar") R:Add(Switch(p, "Fade when out of reach", g, s,
    "More than 40 yards away or out of line of sight (where the client can tell)."), 1)
  g, s = Num("trinket") R:Add(Switch(p, "PvP trinket", g, s, "Bright when ready. Cooldown 3 minutes as measured on this server."), 1)
  g, s = Num("racial") R:Add(Switch(p, "Racial", g, s, "From the enemy's race, with this game's cooldown."), 8)

  R:Add(Heading(p, "Cast bar"), 4)
  g, s = Num("cast") R:Add(Switch(p, "Cast bar", g, s), 1)
  g, s = Num("castH") R:Add(Slider(p, "Height", 10, 28, 1, g, s, pxs))
  g, s = Num("castIcon") R:Add(Switch(p, "Spell icon", g, s), 1)
  g, s = Num("castTime") R:Add(Switch(p, "Time left", g, s), 1)
  g, s = Num("castSchool") R:Add(Switch(p, "Colour by school", g, s, "Off: one colour. Grey always means it cannot be interrupted."), 1)
  g, s = Num("kickMark") R:Add(Switch(p, "Your interrupt beside it", g, s,
    "Green edge: you can kick this cast right now. Dark with a number: when yours comes back."), 1)
  g, s = Num("lockout") R:Add(Switch(p, "School lockout after a kick", g, s,
    "A purple LOCKED bar for the time the game's table gives that interrupt."), 8)

  R:Add(Heading(p, "On them now"), 4)
  g, s = Num("big") R:Add(Switch(p, "Crowd control on the class icon", g, s, "The worst thing on them right now, with a timer."), 1)
  g, s = Num("immuneGlow") R:Add(Switch(p, "Gold edge while immune", g, s, "Ice Block, Divine Shield..."), 1)
  g, s = Num("strip") R:Add(Switch(p, "Other auras beside the frame", g, s), 1)
  g, s = Num("dr") R:Add(Switch(p, "Diminishing returns", g, s, "What the next one lands at: 50%, 25%, IMM. The timer is when it resets."), 1)
end

-- ---------------------------------------------------------------- Cooldowns

function O:BuildCooldowns(p)
  -- live preview
  local box = CreateFrame("Frame", nil, p)
  box:SetWidth(530)
  box:SetHeight(72)
  box:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -4)
  Flat(box, { 0.03, 0.035, 0.045 })
  local cap = Text(box, 9, 0.5, 0.52, 0.58)
  cap:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
  cap:SetText("PREVIEW")
  local preview = I.NewPreview(box)
  table.insert(self.refresh, function()
    local size = A.db.cdSize + 8
    local w = 4 * (size + A.db.cdSpacing + 2)
    I.PaintPreview(preview, math.floor((530 - w) / 2), -math.floor((72 - size) / 2))
  end)

  local L = Col(p, 0, -86)
  local R = Col(p, 275, -86)
  local g, s
  L:Add(Heading(p, "Cooldown row"), 6)
  g, s = Num("cdRow") L:Add(Switch(p, "Cooldowns under each frame", g, s), 2)
  g, s = Num("cdSize") L:Add(Slider(p, "Icon size", 14, 40, 1, g, s, pxs))
  g, s = Num("cdSpacing") L:Add(Slider(p, "Icon spacing", 0, 10, 1, g, s, pxs))
  g, s = Num("cdPerRow") L:Add(Slider(p, "Most icons", 1, 12, 1, g, s))
  g, s = Num("showReady") L:Add(Switch(p, "Show spells that are ready", g, s,
    "Off: only spells on cooldown show (OmniBar style)."), 1)
  g, s = Num("showTalents") L:Add(Switch(p, "Show talent spells not seen yet", g, s,
    "They show faded with a ? until the enemy uses one. Off: only once seen."), 1)
  g, s = Num("learn") L:Add(Switch(p, "Learn each player's real cooldown", g, s,
    "Used earlier than the game's table says, but no earlier than talents allow: remembered for that player by name."), 8)

  L:Add(Heading(p, "Icon look"), 6)
  L:Add(Cycle(p, "Border colour", { { "kind", "Spell type" }, { "class", "Class colour" }, { "none", "Black" } },
    function() return A.db.border end, function(v) A.db.border = v end, 130,
    "Spell type: blue interrupt, purple silence, orange stun, pink crowd control, green defensive, red offensive."), 4)
  g, s = Num("borderPx") L:Add(Slider(p, "Border (screen pixels)", 0, 4, 1, g, s, pxs))
  L:Add(Cycle(p, "Cooldown sweep", { { "clock", "Clock" }, { "fill", "Draining fill" }, { "none", "None" } },
    function() return A.db.sweep end, function(v) A.db.sweep = v end), 4)
  g, s = Num("unusedAlpha") L:Add(Slider(p, "Opacity of ready spells", 0, 1, 0.05, g, s, pct))
  g, s = Num("shadow") L:Add(Switch(p, "Dark outline", g, s), 1)
  g, s = Num("desat") L:Add(Switch(p, "Grey while on cooldown", g, s), 1)
  g, s = Num("pop") L:Add(Switch(p, "Pop when used", g, s), 1)

  R:Add(Heading(p, "Numbers"), 6)
  g, s = Num("showText") R:Add(Switch(p, "Show cooldown numbers", g, s), 4)
  R:Add(Cycle(p, "Font", FontChoices(), function() return A.db.numFont end, function(v) A.db.numFont = v end), 6)
  g, s = Num("numSize") R:Add(Slider(p, "Size (of the icon)", 25, 85, 1, g, s, function(v) return v .. "%" end))
  R:Add(Cycle(p, "Outline", { { "NONE", "Drop shadow" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" } },
    function() return A.db.numOutline end, function(v) A.db.numOutline = v end), 4)
  R:Add(Cycle(p, "Position", { { "CENTER", "Middle" }, { "BOTTOM", "Bottom" }, { "TOP", "Top" }, { "BOTTOMRIGHT", "Bottom right" } },
    function() return A.db.numPos end, function(v) A.db.numPos = v end), 4)
  R:Add(Cycle(p, "Over a minute", { { "sec", "Seconds (75)" }, { "clock", "Clock (1:15)" }, { "short", "Minutes (2m)" } },
    function() return A.db.numFormat end, function(v) A.db.numFormat = v end, 130), 6)
  g, s = Num("numDecimals") R:Add(Slider(p, "Tenths below (0 = never)", 0, 5, 1, g, s, function(v) return v .. "s" end))
  local colors = {}
  for _, c in ipairs(A.COLORS) do table.insert(colors, { c.key, c.label }) end
  R:Add(Cycle(p, "Colour", colors, function() return A.db.numColor end, function(v) A.db.numColor = v end), 4)
  R:Add(Cycle(p, "Colour when nearly ready", colors, function() return A.db.soonColor end,
    function(v) A.db.soonColor = v end), 6)
  g, s = Num("soonAt") R:Add(Slider(p, "Nearly ready below (0 = off)", 0, 10, 1, g, s, function(v) return v .. "s" end))
end

-- ---------------------------------------------------------------- Strips

function O:BuildStrips(p)
  local L = Col(p, 0)
  local R = Col(p, 275)
  local g, s
  L:Add(Heading(p, "Interrupt bar"), 6)
  g, s = Num("intBar") L:Add(Switch(p, "Interrupt bar", g, s,
    "OctoKicks' bar: every enemy's interrupts in one strip, soonest back first, name under each. Move it while unlocked."), 4)
  g, s = Num("intAll") L:Add(Switch(p, "All their always-shown spells too", g, s), 4)
  g, s = Num("intSize") L:Add(Slider(p, "Icon size", 16, 64, 1, g, s, pxs))
  g, s = Num("intPerRow") L:Add(Slider(p, "Icons per row", 1, 16, 1, g, s))
  g, s = Num("intNames") L:Add(Switch(p, "Names under the icons", g, s), 8)

  L:Add(Heading(p, "Buffs above the frame"), 6)
  g, s = Num("buffs") L:Add(Switch(p, "Show their buffs", g, s,
    "A row of the enemy's buffs above each frame while they are in sight. Shields, immunities, offensive and escape buffs come first with a coloured edge. 1.12 does not send other players' buff times, so they have no timer."), 4)
  g, s = Num("buffSize") L:Add(Slider(p, "Icon size", 12, 32, 1, g, s, pxs))
  g, s = Num("buffMax") L:Add(Slider(p, "Most shown", 1, 16, 1, g, s), 8)

  R:Add(Heading(p, "BG / World rows"), 6)
  g, s = Num("bgIconSize") R:Add(Slider(p, "Icon size", 16, 64, 1, g, s, pxs))
  g, s = Num("bgRows") R:Add(Slider(p, "Most enemies shown", 1, 15, 1, g, s))
  g, s = Num("bgNames") R:Add(Switch(p, "Show names", g, s, "Off: only a class-coloured strip per row."), 4)
  g, s = Num("bgDim") R:Add(Switch(p, "Dim enemies out of sight", g, s, "Needs SuperWoW."), 4)
end

-- ---------------------------------------------------------------- Spells

local TIERS = { [1] = "Always", [2] = "When used", [0] = "Off" }
local TIER_COLOR = { [1] = { 0.2, 0.55, 0.25 }, [2] = { 0.15, 0.35, 0.6 }, [0] = { 0.13, 0.135, 0.165 } }
local NEXT_TIER = { [1] = 2, [2] = 0, [0] = 1 }
local SPELL_ROWS = 34

function O:SpellList()
  local key = self.spellClass or "WARRIOR"
  if key == "OTHER" then
    local out = {}
    for i = 1, table.getn(A.SPELLS) do
      local s = A.SPELLS[i]
      if not A.CLASS_LABEL[s.c] then table.insert(out, s) end
    end
    return out
  end
  return A.BYCLASS[key] or {}
end

function O:BuildSpells(p)
  self.spellClass = "WARRIOR"
  -- class tabs
  local tabs = {}
  local keys = {}
  for _, c in ipairs(A.CLASSES) do table.insert(keys, c) end
  table.insert(keys, "OTHER")
  for i = 1, table.getn(keys) do
    local key = keys[i]
    local b = Button(p, key == "OTHER" and "Racials, items" or A.CLASS_LABEL[key], 100, function()
      O.spellClass = key
      O:Refresh()
    end, nil, 20)
    b:SetPoint("TOPLEFT", p, "TOPLEFT", math.mod(i - 1, 5) * 106, -4 - math.floor((i - 1) / 5) * 24)
    tabs[key] = b
  end
  local head = Note(p, "Click: Always shown > When used > Off.  Box: cooldown in seconds, from the game's own table; "
    .. "change it only if the server differs.  Blue dot: glows longer when it comes back.", 530, 28)
  head:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -54)
  local reset = Button(p, "Back to the game's numbers", 170, function()
    A.db.spells = {}
    A:Changed()
  end, "Forgets every change on this page, for all classes.", 18)
  reset:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -84)
  local forget = Button(p, "Forget learned cooldowns", 170, function()
    A.global.learned, A.global.seen = {}, {}
    A:Print("learned cooldowns forgotten.")
  end, "Every player's cooldowns learned from early recasts.", 18)
  forget:SetPoint("LEFT", reset, "RIGHT", 6, 0)

  local rows = {}
  for i = 1, SPELL_ROWS do
    local idx = i
    local cx = (i <= SPELL_ROWS / 2) and 0 or 272
    local cy = -108 - math.mod(i - 1, SPELL_ROWS / 2) * 25
    local row = CreateFrame("Frame", nil, p)
    row:SetWidth(262)
    row:SetHeight(23)
    row:SetPoint("TOPLEFT", p, "TOPLEFT", cx, cy)
    Flat(row, PANEL)
    local tier = Button(row, "", 62, function()
      local s = row.spell
      if s then
        A.SetSpell(s.n, "tier", NEXT_TIER[A.SpellTier(s)])
        A:Changed()
      end
    end, "Always: on the frame all the time. When used: appears while it is on cooldown. Off: not shown.", 18)
    tier:SetPoint("LEFT", row, "LEFT", 2, 0)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("LEFT", tier, "RIGHT", 4, 0)
    local name = Text(row, 10)
    name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    name:SetWidth(108)
    name:SetHeight(20)
    local e = Edit(row, 36, function(text)
      local s = row.spell
      if not s then return end
      local v = tonumber(text)
      if v and v > 0 and v <= 7200 then
        if v == s.cd then A.SetSpell(s.n, "cd", nil) else A.SetSpell(s.n, "cd", v) end
      end
      A:Changed()
    end)
    e:SetHeight(18)
    e:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    local glow = Button(row, "", 12, function()
      local s = row.spell
      if s then
        A.SetSpell(s.n, "prio", not A.SpellPrio(s))
        A:Changed()
      end
    end, "Glows longer and brighter when it comes back.", 12)
    glow:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    rows[idx] = row
    table.insert(self.refresh, function()
      local list = O:SpellList()
      local s = list[idx]
      row.spell = s
      if not s then
        row:Hide()
        return
      end
      row:Show()
      local t = A.SpellTier(s)
      tier.label:SetText(TIERS[t])
      local tc = TIER_COLOR[t]
      tier:SetBackdropColor(tc[1], tc[2], tc[3], 1)
      icon:SetTexture(s.texture)
      name:SetText(s.n .. (s.tal and " |cff777b85*|r" or ""))
      local kc = A.KIND_COLOR[s.k] or A.KIND_COLOR.utility
      name:SetTextColor(kc[1], kc[2], kc[3])
      if not e.focused then e:SetText(tostring(A.SpellCD(s))) end
      SetOn(glow, A.SpellPrio(s))
    end)
  end
  table.insert(self.refresh, function()
    for key, b in pairs(tabs) do SetOn(b, key == O.spellClass) end
  end)
end

-- ---------------------------------------------------------------- Alerts

local SOUND_CHOICES = {}
for _, s in ipairs(A.SOUNDS) do table.insert(SOUND_CHOICES, { s.key, s.label }) end

function O:BuildAlerts(p)
  local col = Col(p, 0)
  local g, s
  col:Add(Heading(p, "Sounds", 530), 6)
  local function Row(label, key, fileKey)
    local a, b = Num(key)
    col:Add(Switch(p, label, a, b, nil, 400), 4)
    local c = col:Add(Cycle(p, "      Sound", SOUND_CHOICES, function() return A.db[fileKey] end,
      function(v) A.db[fileKey] = v end), 8)
    local play = Button(p, "Play", 50, function() PlaySoundFile(A.SoundFile(A.db[fileKey])) end)
    play:SetPoint("LEFT", c, "RIGHT", 4, 0)
  end
  Row("Sound when an enemy uses their trinket", "soundTrinket", "soundTrinketFile")
  Row("Sound when an enemy uses a tracked spell", "soundUse", "soundUseFile")
  Row("Sound when one of their spells is ready again", "soundReady", "soundReadyFile")

  col:Add(Heading(p, "On screen", 530), 6)
  g, s = Num("flashReady") col:Add(Switch(p, "Icon glows when a spell comes back", g, s,
    "Spells marked on the Spells page glow longer and brighter. Interrupts and silences are marked to begin with.", 400), 14)

  col:Add(Heading(p, "Chat", 530), 6)
  g, s = Num("printChat") col:Add(Switch(p, "Print each use in your chat window", g, s, nil, 400), 4)
  g, s = Num("announce") col:Add(Switch(p, "Announce each use in party chat", g, s,
    "Your team sees: [OctoArena] Bob used Counterspell (30s). Only real uses: never in test mode, "
    .. "never from players outside the slots.", 400), 4)
  g, s = Num("announceKicks") col:Add(Switch(p, "Announce interrupts in party chat", g, s,
    "[OctoArena] Kick on Bob's Greater Heal: Holy locked.", 400), 6)
  col:Add(Note(p, "Every message names the enemy, so a call-out always says who used what. "
    .. "Sounds and chat are for the frames; BG / World stays quiet.", 530, 28))
end

-- ---------------------------------------------------------------- Profiles

function O:BuildProfiles(p)
  local col = Col(p, 0)
  col:Add(Note(p, "A profile keeps every setting except the enemies and the format. "
    .. "Profiles are shared by all your characters.", 530, 28), 8)
  local row = CreateFrame("Frame", nil, p)
  row:SetWidth(530)
  row:SetHeight(24)
  col:Add(row, 14)
  local e = Edit(row, 200)
  e:SetPoint("LEFT", row, "LEFT", 0, 0)
  local save = Button(row, "Save current as", 130, function()
    if A:SaveProfile(e:GetText()) then
      A:Print("profile saved: " .. e:GetText())
      e:SetText("")
      O:Refresh()
    end
  end, "Type a name in the box first (healer, dps...). The same name overwrites.")
  save:SetPoint("LEFT", e, "RIGHT", 6, 0)

  local list = {}
  for i = 1, 10 do
    local r = CreateFrame("Frame", nil, p)
    r:SetWidth(530)
    r:SetHeight(26)
    col:Add(r, 4)
    Flat(r, PANEL)
    r.name = Text(r, 11)
    r.name:SetPoint("LEFT", r, "LEFT", 10, 0)
    r.load = Button(r, "Load", 64, function() if r.profile then A:LoadProfile(r.profile) end end, nil, 20)
    r.load:SetPoint("RIGHT", r, "RIGHT", -76, 0)
    r.del = Button(r, "Delete", 64, function()
      if r.profile then
        A.global.profiles[r.profile] = nil
        O:Refresh()
      end
    end, nil, 20)
    r.del:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    list[i] = r
  end
  local empty = Note(p, "No profiles yet.", 300, 14)
  empty:SetPoint("TOPLEFT", list[1], "TOPLEFT", 0, 0)
  table.insert(self.refresh, function()
    local names = {}
    for name in pairs(A.global.profiles) do table.insert(names, name) end
    table.sort(names)
    for i = 1, 10 do
      local r = list[i]
      r.profile = names[i]
      if names[i] then r.name:SetText(names[i]) r:Show() else r:Hide() end
    end
    if names[1] then empty:Hide() else empty:Show() end
  end)
end

-- ---------------------------------------------------------------- Esc menu

-- A way back that needs no chat: a button under the game menu.
function O:MenuButton()
  if self.menu or not GameMenuFrame then return end
  local b = CreateFrame("Button", "OctoArenaMenuButton", GameMenuFrame, "GameMenuButtonTemplate")
  b:SetPoint("TOP", GameMenuFrame, "BOTTOM", 0, -2)
  b:SetText("OctoArenaFrames")
  b:SetScript("OnClick", function()
    HideUIPanel(GameMenuFrame)
    O:Build()
    O.win:Show()
  end)
  self.menu = b
end
