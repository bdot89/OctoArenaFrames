-- OctoArenaFrames :: the two strips from OctoKicks
-- BG / World: no frames and no names; a row of icons per enemy who used something,
-- your target's row first, rows of enemies out of sight dimmed; icons pop in and
-- shrink away when ready.
-- Interrupt bar (optional, for arenas): every enemy's interrupts in one strip, soonest
-- back first, with the enemy's name under each.

local A = OctoArenaFrames
local I = A.Icons
local B = { icons = {}, rows = {}, strips = {}, barIcons = {} }
A.Bars = B

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Mover(name, posKey)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:SetWidth(120)
  f:SetHeight(40)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() if not A.db.locked or A.test then this:StartMoving() end end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    if this.SetUserPlaced then this:SetUserPlaced(false) end   -- see F:SavePos
    local s = this:GetEffectiveScale() / UIParent:GetEffectiveScale()
    A.db[posKey] = { left = this:GetLeft() * s, top = this:GetTop() * s, bottom = this:GetBottom() * s }
    B:Place()
  end)
  f:SetScript("OnMouseUp", function() if arg1 == "RightButton" then A.Options:Toggle() end end)
  f:Hide()
  return f
end

function B:Build()
  if self.bg then return end
  self.bg = Mover("OctoArenaBGFrame", "bgPos")
  self.int = Mover("OctoArenaInterruptBar", "intPos")
  self.hint = self.bg:CreateFontString(nil, "OVERLAY")
  self.hint:SetFont(A.UI_FONT, 10, "")
  self.hint:SetTextColor(0.8, 0.8, 0.8)
  self.hint:SetJustifyH("LEFT")
  self.hint:SetPoint("TOPLEFT", self.bg, "TOPLEFT", 4, -4)
  self.intHint = self.int:CreateFontString(nil, "OVERLAY")
  self.intHint:SetFont(A.UI_FONT, 10, "")
  self.intHint:SetTextColor(0.8, 0.8, 0.8)
  self.intHint:SetPoint("TOPLEFT", self.int, "TOPLEFT", 4, -4)
  self:Place()
end

local function PlaceOne(f, p, x, y)
  if f.SetUserPlaced then f:SetUserPlaced(false) end   -- see F:SavePos
  f:SetScale(A.db.scale)
  f:ClearAllPoints()
  if not p then
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
    return
  end
  local s = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.left * s, p.top * s)
end

function B:Place()
  if not self.bg then return end
  PlaceOne(self.bg, A.db.bgPos, 0, -120)
  PlaceOne(self.int, A.db.intPos, 0, 160)
end

function B:Refresh() self.dirty = true end

local function Skin(f, unlocked)
  if unlocked then
    f:EnableMouse(true)
    f:SetBackdropColor(0.05, 0.1, 0.2, 0.45)
    f:SetBackdropBorderColor(0.2, 0.6, 1, 0.9)
  else
    f:EnableMouse(false)
    f:SetBackdropColor(0, 0, 0, 0)
    f:SetBackdropBorderColor(0, 0, 0, 0)
  end
end

-- ---------------------------------------------------------------- BG / World

function B:Order()
  local units = A:BGUnits()
  local tguid = A.GuidOf("target")
  local tname = UnitExists("target") and UnitName("target") or nil
  local list = {}
  for _, u in pairs(units) do
    u.isTarget = (tguid and u.guid == tguid) or (not u.guid and tname and u.name == tname) or false
    table.insert(list, u)
  end
  table.sort(list, function(a, b)
    if a.isTarget ~= b.isTarget then return a.isTarget end
    return (a.last or 0) > (b.last or 0)
  end)
  local keep = {}
  for i = 1, math.min(A.db.bgRows, table.getn(list)) do keep[i] = list[i] end
  table.sort(keep, function(a, b)
    if a.isTarget ~= b.isTarget then return a.isTarget end
    if a.first ~= b.first then return a.first < b.first end
    return a.key < b.key
  end)
  return keep
end

function B:Icon(n)
  local b = self.icons[n]
  if not b then
    b = I.New(self.bg)
    b.v = {}
    self.icons[n] = b
  end
  return b
end

function B:UpdateBG(now)
  local db, f = A.db, self.bg
  if not A:IsBG() and not (A.test and A:IsBG()) then
    f:Hide()
    return
  end
  f:Show()
  f:SetAlpha(db.alpha)
  Skin(f, not db.locked or A.test)
  local px = I.Pixel(f)
  local size, sp = db.bgIconSize, db.cdSpacing + 2
  local strip = math.max(2 * px, I.Snap(3, px))
  local nameW = db.bgNames and 70 or 0
  local rows = self:Order()
  local used, maxW = 0, 0
  local nrows = table.getn(rows)
  local rowGap = 6
  for r = 1, nrows do
    local u = rows[r]
    local y = -(r - 1) * (size + rowGap)
    local c = A.CLASS_COLOR[u.class or ""] or { 0.7, 0.7, 0.7 }
    local st = self.strips[r]
    if not st then
      st = f:CreateTexture(nil, "ARTWORK")
      st:SetTexture(WHITE)
      self.strips[r] = st
    end
    st:SetVertexColor(c[1], c[2], c[3], 1)
    st:SetWidth(u.isTarget and strip * 2 or strip)
    st:SetHeight(size)
    st:ClearAllPoints()
    st:SetPoint("TOPLEFT", f, "TOPLEFT", 0, I.Snap(y, px))
    st:Show()
    local dim = db.bgDim and u.guid and A.UseSW() and not UnitExists(u.guid)
    st:SetAlpha(dim and 0.45 or 1)
    local label = self.rows[r]
    if not label then
      label = f:CreateFontString(nil, "OVERLAY")
      label:SetFont(A.UI_FONT, 12, "OUTLINE")
      self.rows[r] = label
    end
    if nameW > 0 then
      label:SetFont(A.FontFile(db.nameFont), math.max(9, db.fontSize - 2), "OUTLINE")
      label:SetWidth(nameW)
      label:SetHeight(size)
      label:SetJustifyH("LEFT")
      label:SetText(u.name)
      label:SetTextColor(c[1], c[2], c[3])
      label:ClearAllPoints()
      label:SetPoint("TOPLEFT", f, "TOPLEFT", strip * 2 + 4, y)
      label:Show()
    else
      label:Hide()
    end
    local list = {}
    for name, cd in pairs(u.cds) do table.insert(list, { s = A.BYNAME[name], c = cd }) end
    table.sort(list, function(a, b) return a.c.slot < b.c.slot end)
    local x0 = strip * 2 + 4 + (nameW > 0 and nameW + 4 or 0)
    for k = 1, table.getn(list) do
      local e = list[k]
      used = used + 1
      local b = self:Icon(used)
      local left = e.c.start + e.c.dur - now
      if left < 0 then left = 0 end
      local v = b.v
      v.s, v.left, v.dur, v.start, v.used, v.class = e.s, left, e.c.dur, e.c.start, true, u.class
      v.gone = e.c.done and math.min(1, (now - e.c.done) / A.GONE) or nil
      v.dim = dim
      I.Place(b, f, x0 + (k - 1) * (size + sp) + size / 2, y - size / 2, size, px)
      I.Paint(b, v, now)
    end
    local w = x0 + table.getn(list) * (size + sp)
    if w > maxW then maxW = w end
  end
  for n = used + 1, table.getn(self.icons) do self.icons[n]:Hide() end
  for r = nrows + 1, table.getn(self.rows) do self.rows[r]:Hide() end
  for r = nrows + 1, table.getn(self.strips) do self.strips[r]:Hide() end
  local h = nrows * size + math.max(0, nrows - 1) * rowGap
  if used == 0 and (not db.locked or A.test) then
    self.hint:SetText("Enemy cooldowns pop up here")
    self.hint:Show()
    maxW, h = math.max(maxW, 170), math.max(h, 20)
  else
    self.hint:Hide()
  end
  f:SetWidth(math.max(maxW, 60))
  f:SetHeight(math.max(h, 4))
end

-- ---------------------------------------------------------------- interrupt bar

function B:UpdateBar(now)
  local db, f = A.db, self.int
  if not db.intBar or A:IsBG() or not A.Frames:ShouldShow() then
    f:Hide()
    return
  end
  f:Show()
  f:SetAlpha(db.alpha)
  Skin(f, not db.locked or A.test)
  local px = I.Pixel(f)
  local all = A:Enemies()
  local list = {}
  for i = 1, A:Max() do
    local e = all[i]
    if e and e.name and e.class and A.BYCLASS[e.class] then
      local spells = A.BYCLASS[e.class]
      for k = 1, table.getn(spells) do
        local s = spells[k]
        local kind = s.k == "interrupt" or s.k == "silence" or (db.intAll and A.SpellTier(s) == 1)
        if kind and A.SpellOn(s) and (s.t == 1 or A.Remaining(e, s.n, now) > 0) then
          table.insert(list, { e = e, s = s, left = A.Remaining(e, s.n, now), i = i })
        end
      end
    end
  end
  table.sort(list, function(a, b)
    if (a.left > 0) ~= (b.left > 0) then return a.left > 0 end
    if a.left > 0 and a.left ~= b.left then return a.left < b.left end
    if a.i ~= b.i then return a.i < b.i end
    return a.s.n < b.s.n
  end)
  local size, sp = db.intSize, db.cdSpacing + 2
  local per = math.max(1, db.intPerRow)
  local labelH = db.intNames and (db.fontSize + 3) or 0
  local n = table.getn(list)
  local cols = math.min(per, n)
  local lines = math.ceil(n / per)
  for k = 1, n do
    local x = list[k]
    local b = self.barIcons[k]
    if not b then
      b = I.New(f)
      b.v = {}
      self.barIcons[k] = b
    end
    local col = math.mod(k - 1, per)
    local line = math.floor((k - 1) / per)
    local v = b.v
    local c = x.e.cds[x.s.n]
    v.s, v.left, v.dur, v.start, v.used, v.class = x.s, x.left, c and c.dur or A.SpellCD(x.s), c and c.start, c ~= nil and x.left > 0, x.e.class
    v.unknown = x.s.tal and not x.e.seen[x.s.n]
    v.flash = x.e.flash[x.s.n]
    I.Place(b, f, col * (size + sp) + size / 2, -line * (size + labelH + 6) - size / 2, size, px)
    I.Paint(b, v, now)
    if labelH > 0 then
      b.label:SetFont(A.FontFile(db.nameFont), db.fontSize - 1, "OUTLINE")
      b.label:SetText(string.sub(x.e.name, 1, 7))
      local cc = A.CLASS_COLOR[x.e.class] or { 0.8, 0.8, 0.8 }
      b.label:SetTextColor(cc[1], cc[2], cc[3])
      b.label:Show()
    else
      b.label:Hide()
    end
  end
  for k = n + 1, table.getn(self.barIcons) do self.barIcons[k]:Hide() end
  if n == 0 and not db.locked then
    self.intHint:SetText("Interrupt bar")
    self.intHint:Show()
  else
    self.intHint:Hide()
  end
  f:SetWidth(math.max(cols * (size + sp), 90))
  f:SetHeight(math.max(lines * (size + labelH) + math.max(0, lines - 1) * 6, 20))
end

function B:Update(now)
  if not self.bg then return end
  self:UpdateBG(now)
  self:UpdateBar(now)
end
