-- themes for the addon windows (looks only).
-- classic = the normal WoW look, forever and midnight are flat.
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
    forever = {
        flat = true,
        bg = { 0.078, 0.086, 0.102, 0.97 }, border = { 0.79, 0.635, 0.29, 1 },
        accent = { 0.91, 0.77, 0.416 },
        sel = { 0.79, 0.635, 0.29, 0.18 }, bar = { 0.79, 0.635, 0.29, 1 },
        btnBg = { 0.118, 0.125, 0.149, 1 }, btnBorder = { 0.42, 0.353, 0.18, 1 },
        btnHover = { 0.79, 0.635, 0.29, 1 }, btnText = { 0.91, 0.77, 0.416 },
        boxBg = { 0.055, 0.063, 0.075, 1 }, boxBorder = { 0.227, 0.235, 0.267, 1 },
    },
    midnight = {
        flat = true,
        bg = { 0.055, 0.071, 0.149, 0.97 }, border = { 0.227, 0.29, 0.541, 1 },
        accent = { 0.56, 0.706, 1 },
        sel = { 0.1, 0.137, 0.314, 1 }, bar = { 0.435, 0.659, 1, 1 },
        btnBg = { 0.094, 0.125, 0.29, 1 }, btnBorder = { 0.29, 0.357, 0.69, 1 },
        btnHover = { 0.435, 0.659, 1, 1 }, btnText = { 0.81, 0.878, 1 },
        boxBg = { 0.035, 0.047, 0.11, 1 }, boxBorder = { 0.173, 0.22, 0.439, 1 },
    },
}

ns.THEME_LIST = { { "classic", "Classic" }, { "forever", "Forever" }, { "midnight", "Midnight" } }

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
