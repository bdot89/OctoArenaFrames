-- OctoArenaFrames :: the icon (OctoKicks' high-definition painter, made cheap)
-- Icons sit on whole screen pixels so borders stay sharp at any UI scale. Everything
-- about an icon is remembered so a repaint only touches what changed: a full arena
-- costs next to nothing when nobody is doing anything.

local A = OctoArenaFrames
local I = {}
A.Icons = I

local WHITE = "Interface\\Buttons\\WHITE8X8"
local POP = 0.25       -- seconds the pop-in takes

-- One physical screen pixel in this frame's units.
function I.Pixel(frame)
  local h = 768
  local res = GetCVar and GetCVar("gxResolution")
  local _, _, hh = string.find(res or "", "%d+x(%d+)")
  if tonumber(hh) then h = tonumber(hh) end
  local scale = frame:GetEffectiveScale()
  if not scale or scale <= 0 then scale = 1 end
  return 768 / h / scale
end

local function Snap(v, px) return math.floor(v / px + 0.5) * px end
I.Snap = Snap

function I.New(parent)
  local b = CreateFrame("Frame", nil, parent)
  b.shadow = b:CreateTexture(nil, "BACKGROUND")
  b.shadow:SetTexture(WHITE)
  b.shadow:SetVertexColor(0, 0, 0, 0.6)
  b.edge = b:CreateTexture(nil, "BORDER")
  b.edge:SetTexture(WHITE)
  b.edge:SetAllPoints(b)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.fill = b:CreateTexture(nil, "OVERLAY")
  b.fill:SetTexture(WHITE)
  b.fill:SetVertexColor(0, 0, 0, 0.62)
  local cd = CreateFrame("Model", nil, b, "CooldownFrameTemplate")
  cd:SetAllPoints(b.tex)
  cd.noCooldownCount = true      -- pfUI / OmniCC: no second countdown on top of ours
  b.cd = cd
  local over = CreateFrame("Frame", nil, b)   -- text and glow above the sweep
  over:SetAllPoints(b)
  over:SetFrameLevel(cd:GetFrameLevel() + 2)
  b.over = over
  -- 1.12: a FontString needs a font before its first SetText ("Font not set")
  b.text = over:CreateFontString(nil, "OVERLAY")
  b.text:SetFont(A.UI_FONT, 12, "OUTLINE")
  b.q = over:CreateFontString(nil, "OVERLAY")
  b.q:SetFont(A.UI_FONT, 10, "OUTLINE")
  b.q:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -1)
  b.q:SetText("?")
  b.q:Hide()
  b.tag = over:CreateFontString(nil, "OVERLAY")
  b.tag:SetFont(A.UI_FONT, 9, "OUTLINE")
  b.tag:SetPoint("BOTTOM", b, "BOTTOM", 0, 1)
  b.tag:Hide()
  b.label = over:CreateFontString(nil, "OVERLAY")
  b.label:SetFont(A.UI_FONT, 10, "OUTLINE")
  b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
  b.label:Hide()
  b.glow = over:CreateTexture(nil, "OVERLAY")
  b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  b.glow:SetBlendMode("ADD")
  b.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.glow:Hide()
  return b
end

-- Where the icon sits and how big, in the owner's units. Only redone when it moved.
function I.Place(b, owner, cx, cy, size, px)
  cx, cy = Snap(cx, px), Snap(cy, px)
  if b.cx ~= cx or b.cy ~= cy or b.owner ~= owner then
    b:ClearAllPoints()
    b:SetPoint("CENTER", owner, "TOPLEFT", cx, cy)
    b.cx, b.cy, b.owner = cx, cy, owner
  end
  b.base, b.px = size, px
  I.FitSweep(b.cd, size, b)
end

-- The 1.12 sweep is a model drawn for a 36 px button: it needs scaling to the icon,
-- or it comes out the wrong size (pfUI's cooldown module does the same).
function I.FitSweep(cd, size, holder)
  holder = holder or cd
  if holder.sweepSize ~= size and size > 0 then
    holder.sweepSize = size
    cd:SetScale(size / 36)
  end
end

local function Resize(b, sz, px)
  sz = Snap(sz, px)
  if b.sz == sz then return end
  b.sz = sz
  b:SetWidth(sz)
  b:SetHeight(sz)
end

local NUM_POINTS = {
  CENTER = { "CENTER", 0, 0 }, BOTTOM = { "BOTTOM", 0, 2 }, TOP = { "TOP", 0, -2 }, BOTTOMRIGHT = { "BOTTOMRIGHT", -1, 2 },
}

local function Frame(b, r, g, bl, a, px, borderPx)
  local key = r .. "," .. g .. "," .. bl .. "," .. a .. "," .. px .. "," .. borderPx
  if b.frameKey == key then return end
  b.frameKey = key
  local bpx = borderPx * px
  b.edge:SetVertexColor(r, g, bl, a)
  b.tex:ClearAllPoints()
  b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", bpx, -bpx)
  b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -bpx, bpx)
  b.shadow:ClearAllPoints()
  b.shadow:SetPoint("TOPLEFT", b, "TOPLEFT", -2 * px, 2 * px)
  b.shadow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2 * px, -2 * px)
end

local function Countdown(b, left, size)
  local db = A.db
  local fs = math.max(8, math.floor(size * db.numSize / 100))
  local key = db.numFont .. fs .. db.numOutline .. db.numPos
  if b.fontKey ~= key then
    b.text:SetFont(A.FontFile(db.numFont), fs, db.numOutline ~= "NONE" and db.numOutline or "")
    if db.numOutline == "NONE" then
      b.text:SetShadowColor(0, 0, 0, 1)
      b.text:SetShadowOffset(1, -1)
    else
      b.text:SetShadowOffset(0, 0)
    end
    local p = NUM_POINTS[db.numPos] or NUM_POINTS.CENTER
    b.text:ClearAllPoints()
    b.text:SetPoint(p[1], b, p[1], p[2], p[3])
    b.fontKey = key
    b.lastText = nil
  end
  local t = A.FormatTime(left)
  if b.lastText ~= t then
    b.text:SetText(t)
    b.lastText = t
  end
  local soon = db.soonAt > 0 and left < db.soonAt
  if b.lastSoon ~= soon or b.colorKey ~= db.numColor .. db.soonColor then
    local c = soon and A.Color(db.soonColor) or A.Color(db.numColor)
    b.text:SetTextColor(c[1], c[2], c[3])
    b.lastSoon = soon
    b.colorKey = db.numColor .. db.soonColor
  end
  if not b.textOn then
    b.text:Show()
    b.textOn = true
  end
end

local function NoCountdown(b)
  if b.textOn ~= false then
    b.text:Hide()
    b.textOn = false
    b.lastText = nil
  end
end

-- Paints icon b. v = { s (spell), left, dur, start, used, unknown, flash, gone (0..1),
-- class, dim, tex (a picture of its own), kind (border colour of its own) }.
function I.Paint(b, v, now)
  local db = A.db
  local s = v.s
  local size, px = b.base, b.px
  -- size: pop in on a fresh use, shrink when gone
  local mult, alpha = 1, 1
  local age = v.start and (now - v.start) or 99
  if db.pop and v.left > 0 and age < POP then
    local t = 1 - age / POP
    mult = 1 + 0.45 * t * t
  end
  if v.gone then
    mult = 1 - 0.6 * v.gone
    alpha = 1 - v.gone
  end
  Resize(b, size * mult, px)
  -- border and shadow, on whole pixels
  local r, g, bl = 0, 0, 0
  local kind = v.kind or (s and s.k)
  if db.border == "kind" and kind then
    local c = A.KIND_COLOR[kind] or A.KIND_COLOR.utility
    r, g, bl = c[1], c[2], c[3]
  elseif db.border == "class" and v.class then
    local c = A.CLASS_COLOR[v.class]
    if c then r, g, bl = c[1], c[2], c[3] end
  end
  if db.borderPx > 0 and db.border ~= "none" then
    Frame(b, r, g, bl, 1, px, db.borderPx)
  else
    Frame(b, 0, 0, 0, 1, px, 1)
  end
  if db.shadow then
    if not b.shadowOn then b.shadow:Show() b.shadowOn = true end
  elseif b.shadowOn ~= false then
    b.shadow:Hide()
    b.shadowOn = false
  end
  local tex = v.tex or (s and s.texture)
  if b.texture ~= tex then
    b.tex:SetTexture(tex)
    b.texture = tex
  end
  local cooling = v.left > 0
  -- sweep: the game's clock, or a dark fill that drains
  if cooling and db.sweep == "clock" and v.start then
    if b.cdStart ~= v.start or b.cdDur ~= v.dur then
      CooldownFrame_SetTimer(b.cd, v.start, v.dur, 1)
      b.cdStart, b.cdDur = v.start, v.dur
      b.cd:Show()
    end
  elseif b.cdStart then
    b.cd:Hide()
    b.cdStart, b.cdDur = nil, nil
  end
  if cooling and db.sweep == "fill" and v.dur and v.dur > 0 then
    local inner = b.sz - 2 * db.borderPx * px
    b.fill:ClearAllPoints()
    b.fill:SetPoint("TOPLEFT", b.tex, "TOPLEFT", 0, 0)
    b.fill:SetPoint("TOPRIGHT", b.tex, "TOPRIGHT", 0, 0)
    b.fill:SetHeight(math.max(px, Snap(inner * v.left / v.dur, px)))
    b.fill:Show()
    b.fillOn = true
  elseif b.fillOn ~= false then
    b.fill:Hide()
    b.fillOn = false
  end
  local desat = cooling and db.desat and true or false
  if b.desat ~= desat then
    b.tex:SetDesaturated(desat)
    b.desat = desat
  end
  -- countdown
  if cooling and db.showText and not v.noNumber then Countdown(b, v.left, size) else NoCountdown(b) end
  -- talent / pet spell not seen yet
  local unknown = v.unknown and true or false
  if b.unknownOn ~= unknown then
    b.unknownOn = unknown
    if unknown then
      b.q:Show()
      b.tex:SetVertexColor(0.55, 0.55, 0.55)
    else
      b.q:Hide()
      b.tex:SetVertexColor(1, 1, 1)
    end
  end
  if not cooling and not v.used and not v.gone and not v.solid then alpha = alpha * db.unusedAlpha end
  if v.dim then alpha = alpha * 0.45 end
  if b.alpha ~= alpha then
    b:SetAlpha(alpha)
    b.alpha = alpha
  end
  -- came back: glow for a moment (longer and brighter for priority spells)
  local prio = s and A.SpellPrio(s)
  local span = prio and 3 or 1.2
  if v.flash and now - v.flash < span then
    local kc = A.KIND_COLOR[kind or "utility"] or A.KIND_COLOR.utility
    b.glow:SetWidth(b.sz * 1.8)
    b.glow:SetHeight(b.sz * 1.8)
    b.glow:SetVertexColor(kc[1], kc[2], kc[3])
    local pulse = 0.5 + 0.5 * math.abs(math.sin((now - v.flash) * 5))
    b.glow:SetAlpha(prio and pulse or pulse * 0.7)
    b.glow:Show()
    b.glowOn = true
  elseif b.glowOn then
    b.glow:Hide()
    b.glowOn = nil
  end
  b:Show()
end

-- Is something on this icon still moving by itself? (decides how often to repaint)
function I.Animating(v, now)
  if v.gone then return true end
  if v.flash and now - v.flash < 3 then return true end
  if A.db.pop and v.start and v.left > 0 and now - v.start < POP then return true end
  return false
end

-- Sample icons for the options (Numbers): the same painter.
local PREVIEW = { { "Counterspell", 24 }, { "Kick", 7 }, { "Silence", 1.6 }, { "Spell Lock", 0 } }

function I.NewPreview(parent)
  local p = { frame = parent, icons = {} }
  for i = 1, table.getn(PREVIEW) do p.icons[i] = I.New(parent) end
  return p
end

function I.PaintPreview(p, x, y)
  local db = A.db
  local size = db.cdSize + 8
  local px = I.Pixel(p.frame)
  local now = GetTime()
  for i = 1, table.getn(PREVIEW) do
    local s = A.BYNAME[PREVIEW[i][1]]
    local left = PREVIEW[i][2]
    local dur = A.SpellCD(s)
    local v = { s = s, left = left, dur = dur, start = now - (dur - left) - 1, used = left > 0, class = s.c }
    I.Place(p.icons[i], p.frame, x + (i - 1) * (size + db.cdSpacing + 2) + size / 2, y - size / 2, size, px)
    I.Paint(p.icons[i], v, now)
  end
  return table.getn(PREVIEW) * (size + db.cdSpacing + 2)
end
