-- OctoArenaFrames :: the arena frames
--
--    [auras <-][ ]                                    one frame, mirrored by the option:
--    [DR    <-][class / CC icon][ name       100% ][trinket]
--              [               ][ health bar      ][racial ]
--              [               ][ power  > target ]
--              [ cast bar:  icon  Polymorph     1.2  [your kick]]
--              [ cooldowns: interrupt, stun, ...                ]
--
-- Every part stays where it is whether it has something to show or not, so nothing
-- jumps in the middle of a fight. The numbers come from F.Metrics, shared with the
-- tests, which check that no parts overlap.

local A = OctoArenaFrames
local I = A.Icons
local F = { frames = {} }
A.Frames = F

local WHITE = "Interface\\Buttons\\WHITE8X8"
local POWER = { [0] = { 0.2, 0.45, 1 }, [1] = { 0.9, 0.15, 0.15 }, [2] = { 1, 0.55, 0.25 }, [3] = { 1, 0.92, 0.25 } }
local NO_KICK = { 0.55, 0.55, 0.6 }
local KICK_COLOR = { 1, 0.75, 0.2 }

-- ---------------------------------------------------------------- measures

function F.Metrics(db)
  local m = {}
  m.H = db.frameH
  m.gap = 2
  m.side = (db.trinket or db.racial) and math.floor((m.H - m.gap) / 2) or 0
  m.icon = m.H
  m.barW = db.barW
  m.W = m.icon + m.gap + m.barW + (m.side > 0 and (m.gap + m.side) or 0)
  m.y = m.H
  if db.cast then
    m.castY = m.y + m.gap
    m.castH = db.castH
    m.y = m.castY + m.castH
  end
  if db.cdRow then
    m.cdY = m.y + m.gap
    m.cdSize = db.cdSize
    m.y = m.cdY + m.cdSize
    m.cdMax = math.floor((m.W + db.cdSpacing) / (db.cdSize + db.cdSpacing))
    if m.cdMax > db.cdPerRow then m.cdMax = db.cdPerRow end
  end
  m.total = m.y
  -- the buff row sits above the frame, inside each enemy's share of the height
  m.top = 0
  m.buffMax = 0
  if db.buffs then
    m.buffSize = db.buffSize
    m.top = db.buffSize + m.gap
    m.buffMax = math.floor((m.W + 2) / (db.buffSize + 2))
    if m.buffMax > db.buffMax then m.buffMax = db.buffMax end
  end
  m.pitch = m.top + m.total + db.spacing
  m.outer = db.drSize
  return m
end

-- x of a part w wide, from the frame's left, mirrored when the option says.
local function MX(db, m, x, w)
  if db.mirror then return m.W - x - w end
  return x
end

-- ---------------------------------------------------------------- building

local function Text(parent, size, justify)
  local t = parent:CreateFontString(nil, "OVERLAY")
  t:SetFont(A.UI_FONT, size or 11, "OUTLINE")
  t:SetTextColor(1, 1, 1)
  t:SetJustifyH(justify or "LEFT")
  return t
end

local function Rect(tex, owner, x, y, w, h)
  tex:ClearAllPoints()
  tex:SetPoint("TOPLEFT", owner, "TOPLEFT", x, y)
  tex:SetWidth(w)
  tex:SetHeight(h)
end

local function Outline(parent)
  local o = CreateFrame("Frame", nil, parent)
  o:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
  o:SetBackdropBorderColor(1, 1, 1, 1)
  o:Hide()
  return o
end

local function NewFrame(i)
  local f = CreateFrame("Button", "OctoArenaFrame" .. i, F.anchor)
  f.i = i
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnClick", function()
    if A.justMoved then return end
    if arg1 == "RightButton" then A:FocusEnemy(this.i)
    elseif arg1 == "MiddleButton" then A:KickEnemy(this.i)
    else A:TargetEnemy(this.i) end
  end)
  f:SetScript("OnDragStart", function() if not A.db.locked then F.anchor:StartMoving() end end)
  f:SetScript("OnDragStop", function()
    F.anchor:StopMovingOrSizing()
    F:SavePos()
  end)
  f:SetScript("OnEnter", function()
    A:HoverEnter(this.i)
    if A.db.locked then return end
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("Enemy " .. this.i)
    GameTooltip:AddLine("Drag to move. Click: target. Right-click: focus. Middle-click: your interrupt. "
      .. "Your interrupt key while the mouse is here kicks this enemy.", 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function()
    A:HoverLeave(this.i)
    GameTooltip:Hide()
  end)
  f:SetScript("OnHide", function() A:HoverLeave(this.i) end)

  -- class / crowd control icon
  local ic = CreateFrame("Frame", nil, f)
  f.ic = ic
  ic.edge = ic:CreateTexture(nil, "BORDER")
  ic.edge:SetTexture(WHITE)
  ic.edge:SetAllPoints(ic)
  ic.edge:SetVertexColor(0, 0, 0, 1)
  ic.tex = ic:CreateTexture(nil, "ARTWORK")
  ic.cd = CreateFrame("Model", nil, ic, "CooldownFrameTemplate")
  ic.cd:SetAllPoints(ic.tex)
  ic.cd.noCooldownCount = true
  ic.cd:Hide()
  local top = CreateFrame("Frame", nil, ic)
  top:SetAllPoints(ic)
  top:SetFrameLevel(ic.cd:GetFrameLevel() + 2)
  ic.num = Text(top, 10)
  ic.num:SetPoint("TOPLEFT", ic, "TOPLEFT", 2, -2)
  ic.time = Text(top, 20, "CENTER")
  ic.time:SetPoint("CENTER", ic, "CENTER", 0, 0)

  -- bars
  f.bars = f:CreateTexture(nil, "BACKGROUND")
  f.bars:SetTexture(WHITE)
  f.bars:SetVertexColor(0, 0, 0, 1)
  f.hp = CreateFrame("StatusBar", nil, f)
  f.hp:SetMinMaxValues(0, 100)
  f.hpBg = f.hp:CreateTexture(nil, "BACKGROUND")
  f.hpBg:SetTexture(WHITE)
  f.hpBg:SetAllPoints(f.hp)
  f.mp = CreateFrame("StatusBar", nil, f)
  f.mp:SetMinMaxValues(0, 100)
  f.mpBg = f.mp:CreateTexture(nil, "BACKGROUND")
  f.mpBg:SetTexture(WHITE)
  f.mpBg:SetAllPoints(f.mp)
  local words = CreateFrame("Frame", nil, f)
  words:SetAllPoints(f.hp)
  words:SetFrameLevel(f.hp:GetFrameLevel() + 2)
  f.name = Text(words, 13)
  f.name:SetPoint("LEFT", f.hp, "LEFT", 4, 0)
  f.hpText = Text(words, 13, "RIGHT")
  f.hpText:SetPoint("RIGHT", f.hp, "RIGHT", -4, 0)
  local mpw = CreateFrame("Frame", nil, f)
  mpw:SetAllPoints(f.mp)
  mpw:SetFrameLevel(f.mp:GetFrameLevel() + 2)
  f.tgt = Text(mpw, 9, "RIGHT")
  f.tgt:SetPoint("RIGHT", f.mp, "RIGHT", -2, 0)

  -- marks
  f.hl = Outline(f)
  f.imm = Outline(f)
  f.imm:SetBackdropBorderColor(1, 0.85, 0.2, 1)

  -- trinket, racial
  f.trinket = I.New(f)
  f.racial = I.New(f)
  f.vTrinket, f.vRacial = {}, {}

  -- cast bar
  local c = CreateFrame("Frame", nil, f)
  f.castF = c
  c.bg = c:CreateTexture(nil, "BACKGROUND")
  c.bg:SetTexture(WHITE)
  c.bg:SetAllPoints(c)
  c.bg:SetVertexColor(0, 0, 0, 0.85)
  c.bar = CreateFrame("StatusBar", nil, c)
  c.bar:SetMinMaxValues(0, 1)
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local cw = CreateFrame("Frame", nil, c)
  cw:SetAllPoints(c)
  cw:SetFrameLevel(c.bar:GetFrameLevel() + 2)
  c.text = Text(cw, 11)
  c.time = Text(cw, 11, "RIGHT")
  c.kick = cw:CreateTexture(nil, "OVERLAY")
  c.kick:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.kickEdge = cw:CreateTexture(nil, "ARTWORK")
  c.kickEdge:SetTexture(WHITE)
  c.kickText = Text(cw, 10, "CENTER")
  c:Hide()

  -- cooldown row, diminishing returns, aura strip (made as they are needed)
  f.cdIcons, f.drIcons, f.stripIcons = {}, {}, {}
  f.row, f.drKeys = {}, {}
  return f
end

function F:Build()
  if self.anchor then return end
  local a = CreateFrame("Frame", "OctoArenaFramesAnchor", UIParent)
  a:SetFrameStrata("MEDIUM")
  a:SetMovable(true)
  a:SetClampedToScreen(true)
  a:SetWidth(100)
  a:SetHeight(20)
  self.anchor = a
  self.handle = self:BuildHandle(a)
  -- the badge: format and how many enemies are known
  local b = a:CreateFontString(nil, "OVERLAY")
  b:SetFont(A.UI_FONT, 9, "OUTLINE")
  self.badge = b
  for i = 1, A.MAX do self.frames[i] = NewFrame(i) end
  self:Place()
end

-- ---------------------------------------------------------------- the handle
-- The bar over the frames while they are unlocked (or in a test): title, a status chip
-- in the status colour (A:StatusParts), and lock / options buttons on the right. The
-- how-to lives in its tooltip. Drag anywhere on it to move.
local HANDLE_H = 22
local TITLE_FONT = A.FontFile and A.FontFile("fira") or A.UI_FONT

local function HandleTip(owner, title, lines)
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  GameTooltip:AddLine(title, 1, 1, 1)
  for i = 1, table.getn(lines) do GameTooltip:AddLine(lines[i], 0.75, 0.78, 0.84, 1) end
  GameTooltip:Show()
end

-- A small square button with a picture (or a letter), grey until the mouse is on it.
local function HandleButton(h, tex, text, tip, onClick)
  local b = CreateFrame("Button", nil, h)
  b:SetWidth(HANDLE_H - 4)
  b:SetHeight(HANDLE_H - 4)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetTexture(WHITE)
  b.bg:SetAllPoints(b)
  b.bg:SetVertexColor(1, 1, 1, 0)
  if tex then
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(tex)
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  else
    b.icon = b:CreateFontString(nil, "OVERLAY")
    b.icon:SetFont(TITLE_FONT, 11, "")
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.icon:SetText(text)
  end
  local isText = not tex
  local function Tint(on)
    local v = on and 1 or 0.55
    if isText then b.icon:SetTextColor(v, v, v) else b.icon:SetVertexColor(v, v, v) end
    b.bg:SetVertexColor(1, 1, 1, on and 0.08 or 0)
  end
  Tint(false)
  b:SetScript("OnEnter", function()
    Tint(true)
    HandleTip(this, tip[1], { tip[2] })
  end)
  b:SetScript("OnLeave", function()
    Tint(false)
    GameTooltip:Hide()
  end)
  b:SetScript("OnClick", onClick)
  return b
end

function F:BuildHandle(a)
  local h = CreateFrame("Frame", nil, a)
  h:SetHeight(HANDLE_H)
  h:EnableMouse(true)
  h:RegisterForDrag("LeftButton")
  h:SetScript("OnDragStart", function() a:StartMoving() end)
  h:SetScript("OnDragStop", function()
    a:StopMovingOrSizing()
    F:SavePos()
  end)
  h:SetScript("OnMouseUp", function() if arg1 == "RightButton" then A.Options:Toggle() end end)
  h:SetScript("OnEnter", function()
    HandleTip(this, "OctoArenaFrames", { "Drag to move the frames.", "Right-click: options.",
      "Lock them when they are where you want them." })
  end)
  h:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- body: dark, a hairline edge, a thin accent line along the bottom
  h.bg = h:CreateTexture(nil, "BACKGROUND")
  h.bg:SetTexture(WHITE)
  h.bg:SetAllPoints(h)
  h.bg:SetVertexColor(0.055, 0.06, 0.075, 0.94)
  h.edge = {}
  local sides = { { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
                  { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }
  for k = 1, 4 do
    local s = sides[k]
    local t = h:CreateTexture(nil, "BORDER")
    t:SetTexture(WHITE)
    t:SetVertexColor(0, 0, 0, 1)
    t:SetPoint(s[1], h, s[1], 0, 0)
    t:SetPoint(s[2], h, s[2], 0, 0)
    if s[3] then t:SetWidth(s[3]) end
    if s[4] then t:SetHeight(s[4]) end
    h.edge[k] = t
  end
  h.accent = h:CreateTexture(nil, "ARTWORK")
  h.accent:SetTexture(WHITE)
  h.accent:SetHeight(1)
  h.accent:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 1, 1)
  h.accent:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -1, 1)
  -- left: a status stripe and the title
  h.stripe = h:CreateTexture(nil, "ARTWORK")
  h.stripe:SetTexture(WHITE)
  h.stripe:SetWidth(3)
  h.stripe:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1)
  h.stripe:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 1, 1)
  h.title = h:CreateFontString(nil, "OVERLAY")
  h.title:SetFont(TITLE_FONT, 11, "")
  h.title:SetTextColor(0.93, 0.94, 0.96)
  h.title:SetPoint("LEFT", h, "LEFT", 10, 0)
  h.title:SetText("OCTO ARENA")
  -- the status chip
  h.chip = CreateFrame("Frame", nil, h)
  h.chip:SetHeight(HANDLE_H - 8)
  h.chip:SetPoint("LEFT", h.title, "RIGHT", 8, 0)
  h.chip.bg = h.chip:CreateTexture(nil, "ARTWORK")
  h.chip.bg:SetTexture(WHITE)
  h.chip.bg:SetAllPoints(h.chip)
  h.chip.text = h.chip:CreateFontString(nil, "OVERLAY")
  h.chip.text:SetFont(TITLE_FONT, 10, "")
  h.chip.text:SetPoint("LEFT", h.chip, "LEFT", 6, 0)
  h.count = h:CreateFontString(nil, "OVERLAY")
  h.count:SetFont(A.UI_FONT, 10, "")
  h.count:SetTextColor(0.62, 0.66, 0.72)
  h.count:SetPoint("LEFT", h.chip, "RIGHT", 7, 0)
  -- right: options, then lock (or stop, during a test)
  h.opts = HandleButton(h, "Interface\\Icons\\INV_Misc_Gear_01", nil, { "Options", "Every setting of OctoArenaFrames." },
    function() A.Options:Toggle() end)
  h.opts.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  h.opts:SetPoint("RIGHT", h, "RIGHT", -3, 0)
  h.lock = HandleButton(h, "Interface\\ChatFrame\\UI-ChatFrame-LockIcon", nil,
    { "Lock the frames", "The bar goes and the frames stay put. Unlock again in the options or with /oaf lock." },
    function()
      A.db.locked = true
      A:Changed()
    end)
  h.lock:SetPoint("RIGHT", h.opts, "LEFT", -2, 0)
  h.stop = HandleButton(h, nil, "STOP", { "Stop the test", "The sample enemies go away." },
    function() A:SetTest(false) end)
  h.stop:SetWidth(36)
  h.stop:SetPoint("RIGHT", h.opts, "LEFT", -2, 0)
  return h
end

-- Fills the handle from the status; the count hides when the bar is too narrow.
function F:PaintHandle(h, w)
  local tag, size, count, r, g, b = A:StatusParts()
  h:SetWidth(w)
  h.stripe:SetVertexColor(r, g, b, 1)
  h.accent:SetVertexColor(r, g, b, 0.55)
  h.chip.text:SetText(tag .. (size and ("  " .. size) or ""))
  h.chip.text:SetTextColor(r, g, b)
  h.chip.bg:SetVertexColor(r, g, b, 0.14)
  h.chip:SetWidth((h.chip.text:GetStringWidth() or 40) + 12)
  local inTest = A.test and true or false
  if inTest then h.stop:Show() h.lock:Hide() else h.stop:Hide() h.lock:Show() end
  if A.db.locked then h.lock:Hide() end
  -- the count in the room left between the chip and the buttons: "1/3 found", else
  -- "1/3", else nothing
  local room = w - (10 + (h.title:GetStringWidth() or 70) + 8 + h.chip:GetWidth() + 7)
    - (3 + h.opts:GetWidth() + 2 + (inTest and h.stop:GetWidth() or h.lock:GetWidth()) + 6)
  local short = count and (string.gsub(count, " found$", "")) or ""
  if short == "waiting for a match" then short = "no match" end
  h.count:SetText(count or "")
  if (h.count:GetStringWidth() or 0) > room then h.count:SetText(short) end
  if (h.count:GetStringWidth() or 0) > room then h.count:Hide() else h.count:Show() end
end

-- The position lives in our settings only. StartMoving marks a frame "user placed",
-- and the client then keeps its own copy in layout-cache.txt (written at logout) and
-- puts the frame back there after loading screens: the frames jumped back after every
-- arena. So the client's copy is switched off after each drag.
function F:SavePos()
  local a = self.anchor
  if a.SetUserPlaced then a:SetUserPlaced(false) end
  local s = a:GetEffectiveScale() / UIParent:GetEffectiveScale()
  A.db.pos = { left = a:GetLeft() * s, top = a:GetTop() * s, bottom = a:GetBottom() * s }
  self:Place()
end

function F:Place()
  local a, db = self.anchor, A.db
  if not a or not db then return end
  if a.SetUserPlaced then a:SetUserPlaced(false) end   -- drops an old layout-cache entry too
  a:SetScale(db.scale)
  a:ClearAllPoints()
  local p = db.pos
  if not p then
    a:SetPoint("RIGHT", UIParent, "RIGHT", -160, 120)
  else
    local s = UIParent:GetEffectiveScale() / a:GetEffectiveScale()
    if db.grow == "UP" then
      a:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.left * s, p.bottom * s)
    else
      a:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.left * s, p.top * s)
    end
  end
  self.settingsKey = nil
  A.dirty = true
end

function F:ShouldShow()
  local db = A.db
  if A:IsBG() then return false end
  if A.test or not db.locked or A.zone == "arena" then return true end
  if db.showWhen == "always" then return true end
  if db.showWhen == "set" then return A:SlotCount(A.MAX) > 0 end
  return false
end

function F:Refresh()
  A.dirty = true
end

-- ---------------------------------------------------------------- layout

local function Apply(f, db, m, px)
  local x, y, w
  -- icon
  local ic = f.ic
  x = MX(db, m, 0, m.icon)
  ic:ClearAllPoints()
  ic:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
  ic:SetWidth(m.icon)
  ic:SetHeight(m.icon)
  ic.tex:ClearAllPoints()
  ic.tex:SetPoint("TOPLEFT", ic, "TOPLEFT", px, -px)
  ic.tex:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", -px, px)
  I.FitSweep(ic.cd, m.icon, ic)
  ic.time:SetFont(A.FontFile(db.numFont), math.floor(m.icon * 0.46), "OUTLINE")
  ic.num:SetFont(A.UI_FONT, math.max(12, math.floor(m.icon * 0.32)), "OUTLINE")
  -- bars
  x = MX(db, m, m.icon + m.gap, m.barW)
  Rect(f.bars, f, x, 0, m.barW, m.H)
  local hpH = m.H - db.powerH - 3 * px
  f.hp:ClearAllPoints()
  f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", x + px, -px)
  f.hp:SetWidth(m.barW - 2 * px)
  f.hp:SetHeight(hpH)
  f.mp:ClearAllPoints()
  f.mp:SetPoint("TOPLEFT", f, "TOPLEFT", x + px, -px - hpH - px)
  f.mp:SetWidth(m.barW - 2 * px)
  f.mp:SetHeight(db.powerH)
  local tex = A.BarFile(db.barTex)
  f.hp:SetStatusBarTexture(tex)
  f.mp:SetStatusBarTexture(tex)
  f.hpBg:SetVertexColor(0.12, 0.12, 0.14, 1)
  f.mpBg:SetVertexColor(0.08, 0.08, 0.1, 1)
  local font = A.FontFile(db.nameFont)
  f.name:SetFont(font, db.fontSize, "OUTLINE")
  f.name:SetWidth(m.barW - 46)
  f.name:SetHeight(db.fontSize + 4)
  f.hpText:SetFont(font, db.fontSize, "OUTLINE")
  f.tgt:SetFont(font, math.max(8, db.powerH), "OUTLINE")
  f.tgt:SetWidth(m.barW - 8)
  f.tgt:SetHeight(db.powerH + 2)
  -- marks: around the whole block, on whole pixels
  local edge = 2 * px
  f.hl:SetBackdrop({ edgeFile = WHITE, edgeSize = edge })
  f.hl:ClearAllPoints()
  f.hl:SetPoint("TOPLEFT", f, "TOPLEFT", -edge, edge)
  f.hl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", edge, -edge)
  f.hl:SetFrameLevel(f.hp:GetFrameLevel() + 6)
  f.imm:SetBackdrop({ edgeFile = WHITE, edgeSize = edge })
  f.imm:SetBackdropBorderColor(1, 0.85, 0.2, 1)
  f.imm:ClearAllPoints()
  f.imm:SetPoint("TOPLEFT", f.hp, "TOPLEFT", -edge, edge)
  f.imm:SetPoint("BOTTOMRIGHT", f.mp, "BOTTOMRIGHT", edge, -edge)
  f.imm:SetFrameLevel(f.hp:GetFrameLevel() + 5)
  -- trinket and racial, stacked at the inner side
  if m.side > 0 then
    x = MX(db, m, m.icon + m.gap + m.barW + m.gap, m.side)
    I.Place(f.trinket, f, x + m.side / 2, -m.side / 2, m.side, px)
    I.Place(f.racial, f, x + m.side / 2, -(m.side + m.gap) - m.side / 2, m.side, px)
  end
  -- cast bar
  local c = f.castF
  if db.cast then
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -m.castY)
    c:SetWidth(m.W)
    c:SetHeight(m.castH)
    local h = m.castH
    local kickW = db.kickMark and h or 0
    local iconW = db.castIcon and h or 0
    local bx = db.mirror and kickW or iconW
    c.icon:ClearAllPoints()
    c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", db.mirror and (m.W - iconW) or 0, 0)
    c.icon:SetWidth(math.max(iconW, 1))
    c.icon:SetHeight(h)
    c.bar:ClearAllPoints()
    c.bar:SetPoint("TOPLEFT", c, "TOPLEFT", bx + px, -px)
    c.bar:SetWidth(m.W - iconW - kickW - 2 * px)
    c.bar:SetHeight(h - 2 * px)
    c.bar:SetStatusBarTexture(tex)
    c.text:SetFont(font, math.max(8, h - 5), "OUTLINE")
    c.text:ClearAllPoints()
    c.text:SetPoint("LEFT", c.bar, "LEFT", 3, 0)
    c.text:SetWidth(m.W - iconW - kickW - 44)
    c.text:SetHeight(h)
    c.time:SetFont(font, math.max(8, h - 5), "OUTLINE")
    c.time:ClearAllPoints()
    c.time:SetPoint("RIGHT", c.bar, "RIGHT", -3, 0)
    local kx = db.mirror and 0 or (m.W - kickW)
    c.kickEdge:ClearAllPoints()
    c.kickEdge:SetPoint("TOPLEFT", c, "TOPLEFT", kx, 0)
    c.kickEdge:SetWidth(math.max(kickW, 1))
    c.kickEdge:SetHeight(h)
    c.kick:ClearAllPoints()
    c.kick:SetPoint("TOPLEFT", c, "TOPLEFT", kx + px, -px)
    c.kick:SetWidth(math.max(kickW - 2 * px, 1))
    c.kick:SetHeight(h - 2 * px)
    c.kickText:SetFont(font, math.max(8, h - 6), "OUTLINE")
    c.kickText:ClearAllPoints()
    c.kickText:SetPoint("CENTER", c.kick, "CENTER", 0, 0)
  end
end

-- What the cooldown row shows for an enemy: always-shown spells in class order, then
-- what they have just used. Never wider than the frame.
local function RowList(e, m, db, now)
  local out, n = {}, 0
  local function Add(s)
    n = n + 1
    out[n] = s
  end
  local list = e.class and A.BYCLASS[e.class]
  if list then
    for i = 1, table.getn(list) do
      local s = list[i]
      if A.SpellTier(s) == 1 then
        local left = A.Remaining(e, s.n, now)
        if s.tal and not e.seen[s.n] and not db.showTalents and left <= 0 then
          -- a talent they may not have
        elseif db.showReady or left > 0 then
          Add(s)
        end
      end
    end
    for i = 1, table.getn(list) do
      local s = list[i]
      if A.SpellTier(s) == 2 and A.Remaining(e, s.n, now) > 0 then Add(s) end
    end
  end
  -- anything else they used: items, another table's spell, a racial with no slot
  for name in pairs(e.cds) do
    local s = A.BYNAME[name]
    if s and A.Remaining(e, name, now) > 0 and A.SpellOn(s) and s.c ~= e.class then
      local own = (s == A.TRINKET and db.trinket) or (s == A.RACIAL[e.race or ""] and db.racial)
      if not own then
        local dup = false
        for i = 1, n do if out[i] == s then dup = true end end
        if not dup then Add(s) end
      end
    end
  end
  return out, math.min(n, m.cdMax or 0)
end

function F:Layout(now)
  local db = A.db
  local a = self.anchor
  if not a then return end
  if not self:ShouldShow() then
    a:Hide()
    return
  end
  a:Show()
  a:SetAlpha(db.alpha)
  local m = F.Metrics(db)
  self.m = m
  local px = I.Pixel(a)
  self.px = px
  local key = table.concat({ m.W, m.H, m.pitch, px, db.barTex, db.nameFont, db.fontSize, db.powerH, db.castH,
    tostring(db.mirror), tostring(db.cast), tostring(db.castIcon), tostring(db.kickMark), db.numFont, tostring(db.trinket), tostring(db.racial) }, "|")
  local apply = key ~= self.settingsKey
  self.settingsKey = key
  local max = A:Max()
  a:SetWidth(m.W)
  a:SetHeight(math.max(m.pitch * math.max(max, 1) - db.spacing, 20))
  local list = A:Enemies()
  -- handle and badge
  local h = self.handle
  if db.locked and not A.test then
    h:Hide()
  else
    h:ClearAllPoints()
    h:SetPoint("BOTTOMLEFT", a, "TOPLEFT", 0, 4)
    self:PaintHandle(h, m.W)
    h:Show()
  end
  self.badge:Hide()
  for i = 1, A.MAX do
    local f = self.frames[i]
    if i <= max then
      if apply or f.m ~= m.pitch then
        Apply(f, db, m, px)
        f.m = m.pitch
      end
      f:ClearAllPoints()
      local off = (i - 1) * m.pitch
      if db.grow == "UP" then
        f:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 0, off + (m.total - m.H))
      else
        f:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -(off + m.top))
      end
      f:SetWidth(m.W)
      f:SetHeight(m.H)
      f:Show()
      f:EnableMouse(true)
      self:Fill(f, list[i], db, m, px, now)
    else
      f:Hide()
    end
  end
end

-- Who is in this frame: the parts that change only when something happens.
function F:Fill(f, e, db, m, px, now)
  e = e or {}
  f.e = e
  f.lastHp, f.lastMp, f.lastState = nil, nil, nil
  -- name
  local c = e.class and A.CLASS_COLOR[e.class]
  -- the number goes in front of the name, in gold, so the team can call "kill 2"
  local name = e.name or (db.showNumber and "not seen yet" or ("Enemy " .. f.i))
  if e.spec and db.showSpec and e.name then name = name .. " |cffbbbbbb" .. e.spec .. "|r" end
  if db.showNumber then name = "|cffffd100" .. f.i .. "|r  " .. name end
  if db.showName then
    f.name:SetText(name)
    f.ic.num:SetText("")
  else
    f.name:SetText("")
    f.ic.num:SetText(db.showNumber and tostring(f.i) or "")
  end
  if c then f.name:SetTextColor(1, 1, 1) else f.name:SetTextColor(0.75, 0.75, 0.75) end
  -- icon: what is on them, else their class
  self:PaintBig(f, e, db, now)
  -- health / power colours
  if db.classBars and c then f.hp:SetStatusBarColor(c[1], c[2], c[3]) else f.hp:SetStatusBarColor(0.2, 0.8, 0.25) end
  local pc = POWER[e.power or 0] or POWER[0]
  f.mp:SetStatusBarColor(pc[1], pc[2], pc[3])
  if not e.name then
    f.hp:SetValue(0)
    f.mp:SetValue(0)
    f.hpText:SetText("")
    f.tgt:SetText("")
    f:SetAlpha(0.55)
  end
  -- marks
  self:PaintMarks(f, e, db)
  -- trinket / racial visible?
  if not db.trinket or not e.name then f.trinket:Hide() end
  local racial = e.race and A.RACIAL[e.race]
  if not db.racial or not racial or not e.name then f.racial:Hide() end
  -- cooldown row
  local n = 0
  if db.cdRow and e.name then
    local row, count = RowList(e, m, db, now)
    f.row = row
    n = count
    for k = 1, n do
      local b = f.cdIcons[k]
      if not b then
        b = I.New(f)
        b.v = {}
        f.cdIcons[k] = b
      end
      local x = MX(db, m, (k - 1) * (db.cdSize + db.cdSpacing), db.cdSize)
      I.Place(b, f, x + db.cdSize / 2, -(m.cdY + db.cdSize / 2), db.cdSize, px)
    end
  end
  f.rowN = n
  for k = n + 1, table.getn(f.cdIcons) do f.cdIcons[k]:Hide() end
  -- diminishing returns and the aura strip, growing away on the outer side
  local dn = 0
  if db.dr and e.name then dn = A.DrList(e, f.drKeys) end
  f.drN = dn
  local size = db.drSize
  local half = m.H - size
  for k = 1, dn do
    local b = f.drIcons[k]
    if not b then
      b = I.New(f)
      b.v = {}
      f.drIcons[k] = b
    end
    local off = (k - 1) * (size + 2) + 2 + size / 2
    local x = db.mirror and (m.W + off) or -off
    I.Place(b, f, x, -(half + size / 2), size, px)
  end
  for k = dn + 1, table.getn(f.drIcons) do f.drIcons[k]:Hide() end
  local sn = 0
  if db.strip and e.name and e.strip then
    sn = table.getn(e.strip)
    if sn > db.stripMax then sn = db.stripMax end
  end
  f.stripN = sn
  for k = 1, sn do
    local b = f.stripIcons[k]
    if not b then
      b = I.New(f)
      b.v = {}
      f.stripIcons[k] = b
    end
    local off = (k - 1) * (size + 2) + 2 + size / 2
    local x = db.mirror and (m.W + off) or -off
    I.Place(b, f, x, -size / 2, size, px)
  end
  for k = sn + 1, table.getn(f.stripIcons) do f.stripIcons[k]:Hide() end
  self:PaintBuffs(f, e, db, m, px)
  self:PaintNumbers(f, e, db, now)
end

-- The enemy's buffs in a row above the frame: the ones that matter (immunities,
-- defensives, offensives, mobility) first with a coloured edge, then the rest.
-- 1.12 does not tell other players' buff times, so these have no timer.
function F:PaintBuffs(f, e, db, m, px)
  f.buffIcons = f.buffIcons or {}
  local list = db.buffs and e.name and e.buffList or nil
  local n = list and table.getn(list) or 0
  if n > m.buffMax then n = m.buffMax end
  local size = m.buffSize or db.buffSize
  for k = 1, n do
    local b = f.buffIcons[k]
    if not b then
      b = CreateFrame("Frame", nil, f)
      b.edge = b:CreateTexture(nil, "BORDER")
      b.edge:SetTexture(WHITE)
      b.edge:SetAllPoints(b)
      b.tex = b:CreateTexture(nil, "ARTWORK")
      b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      f.buffIcons[k] = b
    end
    local x = MX(db, m, (k - 1) * (size + 2), size)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", f, "TOPLEFT", I.Snap(x, px), I.Snap(m.gap, px))
    b:SetWidth(I.Snap(size, px))
    b:SetHeight(I.Snap(size, px))
    b.tex:ClearAllPoints()
    b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", px, -px)
    b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -px, px)
    local a = list[k]
    b.tex:SetTexture(a.tex)
    local col = a.kind and A.KIND_COLOR[a.kind]
    if col then b.edge:SetVertexColor(col[1], col[2], col[3], 1) else b.edge:SetVertexColor(0, 0, 0, 0.9) end
    b:Show()
  end
  for k = n + 1, table.getn(f.buffIcons) do f.buffIcons[k]:Hide() end
end

-- ---------------------------------------------------------------- painting

function F:PaintBig(f, e, db, now)
  local ic = f.ic
  local a = db.big and e.big
  if a then
    if ic.shown ~= a then
      ic.shown = a
      ic.tex:SetTexture(a.tex)
      ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      local col = A.KIND_COLOR[a.def.k] or A.KIND_COLOR.stun
      if A.DR_KINDS[a.def.k] then col = A.KIND_COLOR.stun end
      if a.def.k == "immune" then col = A.KIND_COLOR.immune end
      ic.edge:SetVertexColor(col[1], col[2], col[3], 1)
      if a.dur and db.sweep == "clock" then
        CooldownFrame_SetTimer(ic.cd, a.start, a.dur, 1)
        ic.cd:Show()
      else
        ic.cd:Hide()
      end
    end
    if a.stop then
      local left = a.stop - now
      if left < 0 then left = 0 end
      ic.time:SetText(left >= 3 and tostring(math.ceil(left)) or string.format("%.1f", left))
      ic.time:Show()
    else
      ic.time:SetText("")
    end
    return
  end
  local class = e.class or "none"
  if ic.shown ~= class then
    ic.shown = class
    local t = e.class and A.CLASS_TCOORDS[e.class]
    if t then
      ic.tex:SetTexture(A.CLASS_ART)
      ic.tex:SetTexCoord(t[1], t[2], t[3], t[4])
    else
      ic.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
      ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    ic.edge:SetVertexColor(0, 0, 0, 1)
    ic.cd:Hide()
    ic.time:SetText("")
  end
end

function F:PaintMarks(f, e, db)
  local hl, kind = false, nil
  if e.name and not e.fake then
    local tg = A.GuidOf("target")
    if (tg and tg == e.guid) or (UnitExists("target") and A.Key(UnitName("target")) == A.Key(e.name)) then
      hl, kind = true, "target"
    else
      local fk = A:FocusKey()
      if fk and (fk == e.guid or A.Key(fk) == A.Key(e.name)) then hl, kind = true, "focus" end
    end
  end
  if hl then
    if kind == "target" then f.hl:SetBackdropBorderColor(1, 1, 1, 1) else f.hl:SetBackdropBorderColor(0.7, 0.35, 1, 1) end
    f.hl:Show()
  else
    f.hl:Hide()
  end
  if db.immuneGlow and e.immune then f.imm:Show() else f.imm:Hide() end
end

local function IconView(b, e, s, now)
  local v = b.v
  local left = A.Remaining(e, s.n, now)
  local c = e.cds[s.n]
  local fl = e.flash[s.n]
  if fl and now - fl > 3 then
    e.flash[s.n] = nil
    fl = nil
  end
  v.s, v.left, v.used, v.dur, v.start = s, left, c ~= nil and left > 0, c and c.dur or A.SpellCD(s), c and c.start
  v.unknown, v.flash, v.class = (s.tal and not e.seen[s.n]) and true or false, fl, e.class
  I.Paint(b, v, now)
  return v
end

-- Everything with a clock on it. Runs 10 times a second, every frame while something
-- on the frame is animating.
function F:PaintNumbers(f, e, db, now)
  local anim = false
  if not e.name then
    f.anim = false
    return
  end
  self:PaintBig(f, e, db, now)
  -- ready trinkets and racials stand out at full colour: they are what you ask about
  if db.trinket and A.TRINKET then
    local b = f.trinket
    b.v = b.v or { solid = true }
    if I.Animating(IconView(b, e, A.TRINKET, now), now) then anim = true end
  end
  local racial = db.racial and e.race and A.RACIAL[e.race]
  if racial then
    local b = f.racial
    b.v = b.v or { solid = true }
    if I.Animating(IconView(b, e, racial, now), now) then anim = true end
  end
  for k = 1, f.rowN or 0 do
    local b = f.cdIcons[k]
    local v = IconView(b, e, f.row[k], now)
    if I.Animating(v, now) then anim = true end
  end
  for k = 1, f.drN or 0 do
    local b = f.drIcons[k]
    local dr = e.dr[f.drKeys[k]]
    if dr then
      local v = b.v
      local left = dr.stop and (dr.stop - now) or 0
      if left < 0 then left = 0 end
      v.s, v.left, v.dur, v.start, v.used, v.solid, v.tex = nil, left, A.DR_WINDOW, dr.stop and (dr.stop - A.DR_WINDOW) or nil, true, true, dr.tex
      v.kind = "dr" .. math.min(dr.level, 3)
      I.Paint(b, v, now)
      -- the stage: what the next one would land at
      local word = dr.level >= 3 and "IMM" or (dr.level == 2 and "25%" or "50%")
      if b.lastTag ~= word then
        b.lastTag = word
        b.tag:SetText(word)
        local c = A.KIND_COLOR[v.kind]
        b.tag:SetTextColor(c[1], c[2], c[3])
      end
      b.tag:Show()
    end
  end
  for k = 1, f.stripN or 0 do
    local b = f.stripIcons[k]
    local a = e.strip[k]
    if a then
      local v = b.v
      local left = a.stop and (a.stop - now) or 0
      if left < 0 then left = 0 end
      v.s, v.left, v.dur, v.start, v.used, v.solid, v.tex, v.kind = nil, left, a.dur, a.start, true, true, a.tex, a.def.k
      I.Paint(b, v, now)
    end
  end
  f.anim = anim
end

-- Health, power and what state they are in.
function F:PaintUnit(f, e, db)
  if not e.name then return end
  local state
  if e.dead then state = "DEAD"
  elseif e.feign then state = "FEIGN"
  elseif e.stealth then state = "STEALTH"
  elseif not e.unit and not e.fake then state = "unseen"
  end
  local pct
  if e.hp and e.hpMax and e.hpMax > 0 then pct = math.ceil(e.hp / e.hpMax * 100) end
  if e.dead then pct = 0 end
  if pct ~= f.lastHp then
    f.lastHp = pct
    f.hp:SetValue(pct or 0)
  end
  local mp
  if e.mana and e.manaMax and e.manaMax > 0 then mp = e.mana / e.manaMax * 100 end
  if mp ~= f.lastMp then
    f.lastMp = mp
    f.mp:SetValue(mp or 0)
    local pc = POWER[e.power or 0] or POWER[0]
    f.mp:SetStatusBarColor(pc[1], pc[2], pc[3])
  end
  local stateKey = (state or "") .. tostring(pct) .. db.hpText
  if stateKey ~= f.lastState then
    f.lastState = stateKey
    if state and state ~= "unseen" then
      f.hpText:SetText(state)
    elseif db.hpText == "percent" and pct then
      f.hpText:SetText(pct .. "%")
    else
      f.hpText:SetText("")
    end
    local alpha = 1
    if state == "DEAD" then alpha = 0.45
    elseif state == "STEALTH" then alpha = 0.6
    elseif state == "unseen" then alpha = 0.55
    elseif e.far and db.dimFar then alpha = 0.7 end
    f.baseAlpha = alpha
    f:SetAlpha(alpha)
    if state == "FEIGN" then f.hpText:SetTextColor(1, 0.85, 0.2)
    elseif state == "DEAD" then f.hpText:SetTextColor(1, 0.3, 0.3)
    elseif state == "STEALTH" then f.hpText:SetTextColor(0.8, 0.6, 1)
    else f.hpText:SetTextColor(1, 1, 1) end
  end
  local want = 1
  if state == "DEAD" then want = 0.45 elseif state == "STEALTH" then want = 0.6 elseif state == "unseen" then want = 0.55
  elseif e.far and db.dimFar then want = 0.7 end
  if f.baseAlpha ~= want then
    f.baseAlpha = want
    f:SetAlpha(want)
  end
end

function F:PaintTarget(f, e, db)
  local text = ""
  if db.showEnemyTarget and e.targetName then
    if e.onMe then
      text = "|cffff3322> YOU|r"
    else
      local c = e.targetClass and A.CLASS_COLOR[e.targetClass]
      if c then
        text = string.format("|cff%02x%02x%02x> %s|r", c[1] * 255, c[2] * 255, c[3] * 255, e.targetName)
      else
        text = "> " .. e.targetName
      end
    end
  end
  if f.lastTgt ~= text then
    f.lastTgt = text
    f.tgt:SetText(text)
  end
end

-- The cast bar: fills while casting, empties while channelling; red for a moment when
-- kicked; a draining purple "locked" bar while a school is locked out. The small
-- square is YOUR interrupt: bright when you could kick this cast right now.
function F:PaintCast(f, e, db, now)
  local c = f.castF
  if not db.cast or not e.name then
    if f.castOn then c:Hide() f.castOn = nil end
    return
  end
  local cast = e.cast
  if cast and now >= cast.start + cast.dur + 0.25 then
    e.cast = nil
    cast = nil
  end
  local lock = e.lockout
  if lock and now >= lock.stop then
    e.lockout = nil
    lock = nil
  end
  local ended = e.castEnd
  if ended and now >= ended.stop then
    e.castEnd = nil
    ended = nil
  end
  if not cast and not ended and not lock then
    if f.castOn then c:Hide() f.castOn = nil end
    return
  end
  if not f.castOn then c:Show() f.castOn = true end
  local tex, text, time, r, g, b, value
  if cast then
    local left = cast.start + cast.dur - now
    if left < 0 then left = 0 end
    value = cast.channel and (left / cast.dur) or (1 - left / cast.dur)
    text, time, tex = cast.name, string.format("%.1f", left), cast.tex
    local col
    if cast.noint then col = NO_KICK
    elseif db.castSchool and cast.school and A.SCHOOL_COLOR[cast.school] then col = A.SCHOOL_COLOR[cast.school]
    else col = KICK_COLOR end
    r, g, b = col[1], col[2], col[3]
    if cast.noint then text = text .. " (no kick)" end
  elseif ended then
    value = 1
    text, time, tex = ended.text or ended.name or "", "", ended.tex
    r, g, b = ended.r or 0.3, ended.g or 1, ended.b or 0.4
  else
    local left = lock.stop - now
    lock.span = lock.span or math.max(left, 0.01)
    value = left / lock.span
    local school = lock.school and A.SCHOOL_LABEL[lock.school] or "Spells"
    text, time, tex = "LOCKED: " .. school, string.format("%.1f", left), lock.tex
    r, g, b = 0.7, 0.35, 1
  end
  c.bar:SetValue(value)
  c.bar:SetStatusBarColor(r, g, b)
  if f.lastCastText ~= text then
    f.lastCastText = text
    c.text:SetText(text)
  end
  if db.castTime then
    if f.lastCastTime ~= time then
      f.lastCastTime = time
      c.time:SetText(time)
    end
  elseif f.lastCastTime ~= "" then
    f.lastCastTime = ""
    c.time:SetText("")
  end
  if db.castIcon and tex then
    if f.lastCastTex ~= tex then
      f.lastCastTex = tex
      c.icon:SetTexture(tex)
    end
    c.icon:Show()
  else
    c.icon:Hide()
  end
  -- your interrupt
  if db.kickMark and not A.test then
    local name, ktex, left = A:MyKick(now)
    if name then
      if f.lastKick ~= ktex then
        f.lastKick = ktex
        c.kick:SetTexture(ktex)
      end
      c.kick:Show()
      c.kickEdge:Show()
      if left == 0 and cast and not cast.noint then
        c.kickEdge:SetVertexColor(0.2, 1, 0.3, 1)
        c.kick:SetAlpha(1)
        c.kickText:SetText("")
      elseif left == 0 then
        c.kickEdge:SetVertexColor(0, 0, 0, 1)
        c.kick:SetAlpha(0.6)
        c.kickText:SetText("")
      else
        c.kickEdge:SetVertexColor(0, 0, 0, 1)
        c.kick:SetAlpha(0.4)
        c.kickText:SetText(tostring(math.ceil(left)))
      end
    else
      c.kick:Hide()
      c.kickEdge:Hide()
      c.kickText:SetText("")
    end
  elseif db.kickMark then
    -- test mode: show what it looks like
    local s = A.BYNAME["Kick"]
    c.kick:SetTexture(s.texture)
    c.kick:Show()
    c.kickEdge:SetVertexColor(0.2, 1, 0.3, 1)
    c.kickEdge:Show()
  else
    c.kick:Hide()
    c.kickEdge:Hide()
  end
end

-- ---------------------------------------------------------------- the clock

function F:Each(fn, now)
  if not self.anchor or not self.anchor:IsShown() then return end
  local list, db = A:Enemies(), A.db
  for i = 1, A:Max() do
    local f, e = self.frames[i], list[i]
    if f and e and e.name then fn(self, f, e, db, now) end
  end
end

local function OnFrameOne(self, f, e, db, now)
  self:PaintCast(f, e, db, now)
  if f.anim then self:PaintNumbers(f, e, db, now) end
end

function F:OnFrame(now)
  if A.dirty then
    A.dirty = false
    self:Layout(now)
  end
  self:Each(OnFrameOne, now)
end

local function FastOne(self, f, e, db, now)
  if not e.fake then A:Read(e, now) end
  self:PaintUnit(f, e, db)
  if e.cast and not e.fake then A:RefineCast(e, now) end
end

function F:Fast(now)
  self:Each(FastOne, now)
end

local function NumbersOne(self, f, e, db, now)
  self:PaintNumbers(f, e, db, now)
end

function F:Numbers(now)
  self:Each(NumbersOne, now)
end

local function SlowOne(self, f, e, db, now)
  if not e.fake then A:ReadSlow(e, now) end
  self:PaintTarget(f, e, db)
  self:PaintMarks(f, e, db)
end

function F:Slow(now)
  self:Each(SlowOne, now)
end
