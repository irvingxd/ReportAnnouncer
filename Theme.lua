-- themes for the addon windows (looks only).
-- classic = the normal WoW look, vibecoded is a flat one.
local ADDON, ns = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"

local THEMES = {
    classic = {
        flat = false,
        accent = { 1, 0.82, 0 },
        sel = { 1, 0.82, 0, 0.2 },
        bar = { 0, 0, 0, 0 },
        boxBg = { 0, 0, 0, 0.6 }, boxBorder = { 0.7, 0.7, 0.7, 1 },
    },
    vibecoded = {
        flat = true,
        bg = { 0.078, 0.086, 0.102, 0.97 }, border = { 0.79, 0.635, 0.29, 1 },
        accent = { 0.91, 0.77, 0.416 },
        sel = { 0.79, 0.635, 0.29, 0.18 }, bar = { 0.79, 0.635, 0.29, 1 },
        btnBg = { 0.118, 0.125, 0.149, 1 }, btnBorder = { 0.42, 0.353, 0.18, 1 },
        btnHover = { 0.79, 0.635, 0.29, 1 }, btnText = { 0.91, 0.77, 0.416 },
        boxBg = { 0.055, 0.063, 0.075, 1 }, boxBorder = { 0.227, 0.235, 0.267, 1 },
    },
}

ns.THEME_LIST = { { "classic", "Classic" }, { "vibecoded", "Vibecoded" } }

local function Key()
    local k = ns.InitDB().theme
    return THEMES[k] and k or "classic"
end
local function Cur() return THEMES[Key()] end

local windows = setmetatable({}, { __mode = "k" })
local boxes = setmetatable({}, { __mode = "k" })
local tabs = setmetatable({}, { __mode = "k" })

local function Unpack(c, a) return c[1], c[2], c[3], c[4] or a or 1 end

local function ApplyWindow(f, t)
    if not f.SetBackdrop then return end
    if t.flat then
        f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        f:SetBackdropColor(Unpack(t.bg))
        f:SetBackdropBorderColor(Unpack(t.border))
    else
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        f:SetBackdropColor(1, 1, 1, 1)
        f:SetBackdropBorderColor(1, 1, 1, 1)
    end
end

local function ApplyBox(f, t)
    if not f.SetBackdrop then return end
    if t.flat then
        f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    else
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end
    f:SetBackdropColor(Unpack(t.boxBg))
    f:SetBackdropBorderColor(Unpack(t.boxBorder))
end

local function ApplyTab(b, t)
    b.selected:SetColorTexture(Unpack(t.sel))
    b.bar:SetColorTexture(Unpack(t.bar))
end

local function ButtonText(b)
    local fs = b:GetFontString()
    if not fs then return end
    local t = Cur()
    if not b:IsEnabled() then
        fs:SetTextColor(0.5, 0.5, 0.5)
    elseif t.flat then
        fs:SetTextColor(Unpack(t.btnText))
    else
        fs:SetTextColor(1, 0.82, 0)
    end
end

local function SkinButton(b, t)
    if not b.raSkin then
        local s = CreateFrame("Frame", nil, b, BackdropTemplateMixin and "BackdropTemplate" or nil)
        s:SetAllPoints(b)
        s:SetFrameLevel(math.max(b:GetFrameLevel() - 1, 0))
        s.raSkinFrame = true
        b.raSkin = s
        b:HookScript("OnEnter", function(self)
            local c = Cur()
            if c.flat and self.raSkin.SetBackdropBorderColor then self.raSkin:SetBackdropBorderColor(Unpack(c.btnHover)) end
        end)
        b:HookScript("OnLeave", function(self)
            local c = Cur()
            if c.flat and self.raSkin.SetBackdropBorderColor then self.raSkin:SetBackdropBorderColor(Unpack(c.btnBorder)) end
        end)
        for _, m in ipairs({ "Enable", "Disable", "SetEnabled" }) do
            hooksecurefunc(b, m, function(self) ButtonText(self) end)
        end
    end
    if b.raTheme ~= Key() then
        b.raTheme = Key()
        for _, r in ipairs({ b:GetRegions() }) do
            if r:GetObjectType() == "Texture" then r:SetAlpha(t.flat and 0 or 1) end
        end
        local fs = b:GetFontString()
        if fs then
            fs:ClearAllPoints()
            if t.flat then fs:SetPoint("CENTER", b, "CENTER", 2, -1) else fs:SetAllPoints(b) end
        end
        local s = b.raSkin
        s:SetShown(t.flat)
        if t.flat and s.SetBackdrop then
            s:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
            s:SetBackdropColor(Unpack(t.btnBg))
            s:SetBackdropBorderColor(Unpack(t.btnBorder))
        end
    end
    ButtonText(b)
end

-- the red close X in the corner
local function SkinClose(b, t)
    if not b.raSkin then
        local s = CreateFrame("Frame", nil, b, BackdropTemplateMixin and "BackdropTemplate" or nil)
        s:SetPoint("TOPLEFT", 6, -6)
        s:SetPoint("BOTTOMRIGHT", -6, 6)
        s:SetFrameLevel(math.max(b:GetFrameLevel() - 1, 0))
        s.raSkinFrame = true
        b.raSkin = s
        b.raX = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.raX:SetPoint("CENTER", 2, -1)
        b.raX:SetText("X")
        b:HookScript("OnEnter", function(self)
            local c = Cur()
            if c.flat and self.raSkin.SetBackdropBorderColor then self.raSkin:SetBackdropBorderColor(Unpack(c.btnHover)) end
        end)
        b:HookScript("OnLeave", function(self)
            local c = Cur()
            if c.flat and self.raSkin.SetBackdropBorderColor then self.raSkin:SetBackdropBorderColor(Unpack(c.btnBorder)) end
        end)
    end
    if b.raTheme ~= Key() then
        b.raTheme = Key()
        local a = t.flat and 0 or 1
        for _, r in ipairs({ b:GetRegions() }) do
            if r ~= b.raX and r:GetObjectType() == "Texture" then r:SetAlpha(a) end
        end
        for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local tx = b[g] and b[g](b)
            if tx then tx:SetAlpha(a) end
        end
        b.raSkin:SetShown(t.flat)
        b.raX:SetShown(t.flat)
        if t.flat and b.raSkin.SetBackdrop then
            b.raSkin:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
            b.raSkin:SetBackdropColor(Unpack(t.btnBg))
            b.raSkin:SetBackdropBorderColor(Unpack(t.btnBorder))
        end
    end
end

-- scrollbars: flat thumb, no arrow buttons. only shown when there is something to scroll
local function ScrollVis(sf, bar)
    local on = sf:GetVerticalScrollRange() > 0
    local thumb = bar:GetThumbTexture()
    if thumb then thumb:SetShown(on) end
    if bar.raTrack then bar.raTrack:SetShown(on and Cur().flat) end
end

local function SkinScroll(sf, t)
    local bar = sf.ScrollBar or (sf:GetName() and _G[sf:GetName() .. "ScrollBar"])
    if not bar or not bar.GetThumbTexture then return end
    if sf.raTheme == Key() then return end
    sf.raTheme = Key()
    local thumb = bar:GetThumbTexture()
    local up = sf.ScrollUpButton or bar.ScrollUpButton or (bar:GetName() and _G[bar:GetName() .. "ScrollUpButton"])
    local down = sf.ScrollDownButton or bar.ScrollDownButton or (bar:GetName() and _G[bar:GetName() .. "ScrollDownButton"])
    for _, btn in ipairs({ up or false, down or false }) do
        if btn then
            btn:SetAlpha(t.flat and 0 or 1)
            btn:EnableMouse(not t.flat)
        end
    end
    for _, r in ipairs({ bar:GetRegions() }) do
        if r ~= thumb and r:GetObjectType() == "Texture" then r:SetAlpha(t.flat and 0 or 1) end
    end
    if not bar.raTrack then
        bar.raTrack = bar:CreateTexture(nil, "BACKGROUND")
        bar.raTrack:SetWidth(6)
        bar.raTrack:SetPoint("TOP", 0, 18)
        bar.raTrack:SetPoint("BOTTOM", 0, -18)
    end
    if t.flat then
        bar.raTrack:SetColorTexture(Unpack(t.boxBg))
        bar.raTrack:Show()
        bar:SetThumbTexture(FLAT)
        thumb = bar:GetThumbTexture()
        thumb:SetTexCoord(0, 1, 0, 1)
        thumb:SetSize(6, 36)
        thumb:SetVertexColor(Unpack(t.btnBorder))
    else
        bar.raTrack:Hide()
        bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
        thumb = bar:GetThumbTexture()
        thumb:SetTexCoord(0.20, 0.80, 0.125, 0.875)
        thumb:SetSize(18, 24)
        thumb:SetVertexColor(1, 1, 1)
    end
    if not sf.raHooked then
        sf.raHooked = true
        sf:HookScript("OnScrollRangeChanged", function(self) ScrollVis(self, bar) end)
    end
    ScrollVis(sf, bar)
end

-- checkboxes: small flat box with a filled square when checked
local function CheckFill(b)
    if b.raFill then b.raFill:SetShown(b:GetChecked() and true or false) end
end

local function SkinCheck(b, t)
    if not b.raSkin then
        local s = CreateFrame("Frame", nil, b, BackdropTemplateMixin and "BackdropTemplate" or nil)
        s:SetSize(16, 16)
        s:SetPoint("CENTER")
        s:SetFrameLevel(math.max(b:GetFrameLevel() - 1, 0))
        s.raSkinFrame = true
        b.raSkin = s
        b.raFill = s:CreateTexture(nil, "OVERLAY")
        b.raFill:SetPoint("TOPLEFT", 3, -3)
        b.raFill:SetPoint("BOTTOMRIGHT", -3, 3)
        hooksecurefunc(b, "SetChecked", CheckFill)
        b:HookScript("OnClick", CheckFill)
        b:HookScript("OnEnter", function(self)
            local c = Cur()
            if c.flat and self.raSkin.SetBackdropBorderColor then self.raSkin:SetBackdropBorderColor(Unpack(c.btnHover)) end
        end)
        b:HookScript("OnLeave", function(self)
            local c = Cur()
            if c.flat and self.raSkin.SetBackdropBorderColor then self.raSkin:SetBackdropBorderColor(Unpack(c.btnBorder)) end
        end)
    end
    if b.raTheme ~= Key() then
        b.raTheme = Key()
        local a = t.flat and 0 or 1
        for _, r in ipairs({ b:GetRegions() }) do
            if r:GetObjectType() == "Texture" then r:SetAlpha(a) end
        end
        for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture",
            "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
            local tx = b[g] and b[g](b)
            if tx then tx:SetAlpha(a) end
        end
        b.raSkin:SetShown(t.flat)
        if t.flat and b.raSkin.SetBackdrop then
            b.raSkin:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
            b.raSkin:SetBackdropColor(Unpack(t.boxBg))
            b.raSkin:SetBackdropBorderColor(Unpack(t.btnBorder))
            b.raFill:SetColorTexture(Unpack(t.accent))
        end
    end
    CheckFill(b)
end

local ACCENT_FONTS = { "GameFontNormal", "GameFontNormalLarge", "GameFontNormalSmall" }

local function Walk(frame, t)
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "FontString" then
            local fo = r:GetFontObject()
            if fo then
                for _, name in ipairs(ACCENT_FONTS) do
                    if fo == _G[name] then r:SetTextColor(Unpack(t.accent)); break end
                end
            end
        end
    end
    for _, c in ipairs({ frame:GetChildren() }) do
        if not c.raSkinFrame then
            Walk(c, t)
            if c.raClose then SkinClose(c, t) end
            if c:GetObjectType() == "ScrollFrame" then SkinScroll(c, t) end
            if c:GetObjectType() == "CheckButton" then SkinCheck(c, t) end
            if c:GetObjectType() == "Button" and c:GetFontString() and not c.raNoSkin then SkinButton(c, t) end
        end
    end
end

function ns.ApplyTheme()
    local t = Cur()
    for f in pairs(windows) do
        ApplyWindow(f, t)
        Walk(f, t)
    end
    for f in pairs(boxes) do ApplyBox(f, t) end
    for b in pairs(tabs) do ApplyTab(b, t) end
end

-- frames register here once, ApplyTheme does the rest
function ns.DialogBackdrop(frame)
    windows[frame] = true
    ApplyWindow(frame, Cur())
end
function ns.SkinBox(frame)
    boxes[frame] = true
    ApplyBox(frame, Cur())
end
function ns.SkinTab(b)
    tabs[b] = true
    ApplyTab(b, Cur())
end

function ns.SetTheme(key)
    if not THEMES[key] then return end
    ns.InitDB().theme = key
    ns.ApplyTheme()
end

function ns.GetThemeKey() return Key() end
