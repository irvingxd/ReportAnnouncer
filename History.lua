-- ReportAnnouncer: minimap button + history window
local ADDON, ns = ...

local FRAME_W, FRAME_H = 580, 460
local ROW_H = 48
local RIGHT_W = 40 -- space reserved for the delete button on each row

local win
local rows = {}

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

---------------------------------------------------------------------------
-- History window
---------------------------------------------------------------------------
local function RemoveEntry(entry)
    local hist = ns.InitDB().history
    for i, e in ipairs(hist) do
        if e == entry then
            table.remove(hist, i)
            return
        end
    end
end

local function GetRow(i, content)
    local r = rows[i]
    if r then return r end

    local textW = content:GetWidth() - RIGHT_W
    r = CreateFrame("Frame", nil, content)
    r:SetSize(content:GetWidth(), ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:EnableMouse(true)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.06 or 0)

    r.line1 = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.line1:SetPoint("TOPLEFT", 6, -5)
    r.line1:SetWidth(textW)
    r.line1:SetJustifyH("LEFT")
    r.line1:SetWordWrap(false)

    r.line2 = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.line2:SetPoint("TOPLEFT", 6, -20)
    r.line2:SetWidth(textW)
    r.line2:SetJustifyH("LEFT")
    r.line2:SetWordWrap(false)

    r.line3 = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.line3:SetPoint("TOPLEFT", 6, -34)
    r.line3:SetWidth(textW)
    r.line3:SetJustifyH("LEFT")
    r.line3:SetWordWrap(false)

    -- delete button
    r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
    r.del:SetSize(24, 22)
    r.del:SetPoint("RIGHT", -4, 0)
    r.del:SetText("X")
    r.del:SetScript("OnClick", function()
        RemoveEntry(r.entry)
        ns.RefreshHistory()
    end)
    r.del:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Delete this report from the history")
        GameTooltip:Show()
    end)
    r.del:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- hover: full details (the lines above are truncated)
    r:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(e.name or "?", 1, 0.82, 0)
        GameTooltip:AddLine(ns.ReasonText(e), 1, 1, 1, true)
        GameTooltip:AddLine("Zone: " .. (e.zone or "?"), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Date: " .. ns.DateText(e), 0.8, 0.8, 0.8, true)
        if e.comment then
            GameTooltip:AddLine("Details: " .. e.comment, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)

    rows[i] = r
    return r
end

function ns.RefreshHistory()
    if not win or not win:IsShown() then return end
    local db = ns.InitDB()
    local hist = db.history

    win.tipCheck:SetChecked(db.tooltip)
    win.calloutCheck:SetChecked(db.callout)
    for key, cb in pairs(win.chanChecks) do cb:SetChecked(db.announce[key]) end

    for i, e in ipairs(hist) do
        local r = GetRow(i, win.content)
        r.entry = e
        r.line1:SetText("|cffffd100" .. (e.name or "?") .. "|r   |cff888888" .. ns.DateText(e) .. "|r")
        r.line2:SetText(ns.ReasonText(e))
        local line3 = e.zone or "?"
        if e.comment then line3 = line3 .. "  -  Details: " .. e.comment end
        r.line3:SetText(line3)
        r:Show()
    end
    for i = #hist + 1, #rows do rows[i]:Hide() end

    win.content:SetHeight(math.max(1, #hist * ROW_H))
    win.empty:SetShown(#hist == 0)
    win.count:SetText(#hist .. " report" .. (#hist == 1 and "" or "s"))
end

StaticPopupDialogs["REPORTANNOUNCER_CLEAR"] = {
    text = "Are you sure?\n\nThis deletes your entire report history and cannot be undone.",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        wipe(ns.InitDB().history)
        ns.RefreshHistory()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function CreateWindow()
    local f = CreateFrame("Frame", "ReportAnnouncerHistoryFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH") -- below the DIALOG strata used by confirmation popups
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Reported Players")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    -- global tooltip switch
    f.tipCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.tipCheck:SetSize(24, 24)
    f.tipCheck:SetPoint("TOPLEFT", 20, -42)
    f.tipCheck:SetScript("OnClick", function(self)
        ns.InitDB().tooltip = self:GetChecked() and true or false
    end)
    local tipLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tipLabel:SetPoint("LEFT", f.tipCheck, "RIGHT", 2, 0)
    tipLabel:SetText("Show reports in player tooltips")

    -- group callout switch (opt-in)
    f.calloutCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.calloutCheck:SetSize(24, 24)
    f.calloutCheck:SetPoint("TOPLEFT", 20, -98)
    f.calloutCheck:SetScript("OnClick", function(self)
        ns.InitDB().callout = self:GetChecked() and true or false
    end)
    f.calloutCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Call out reported players")
        GameTooltip:AddLine("When someone you reported is in your party or raid, posts a notice in party/raid chat (respects the /party and /raid switches above). Off by default.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.calloutCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local calloutLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    calloutLabel:SetPoint("LEFT", f.calloutCheck, "RIGHT", 2, 0)
    calloutLabel:SetText("Call out reported players who are in my group")

    -- chat announcing switches
    local annLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    annLabel:SetPoint("TOPLEFT", 26, -74)
    annLabel:SetText("Announce in chat:")
    f.chanChecks = {}
    local prev
    for _, c in ipairs({ { "say", "/say" }, { "party", "/party" }, { "raid", "/raid" } }) do
        local key, text = c[1], c[2]
        local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        if prev then
            cb:SetPoint("LEFT", prev, "RIGHT", 52, 0)
        else
            cb:SetPoint("LEFT", annLabel, "RIGHT", 8, 0)
        end
        cb:SetScript("OnClick", function(self)
            ns.InitDB().announce[key] = self:GetChecked() and true or false
        end)
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        label:SetText(text)
        f.chanChecks[key] = cb
        prev = cb
    end

    -- scrolling list
    local scroll = CreateFrame("ScrollFrame", "ReportAnnouncerHistoryScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -130)
    scroll:SetPoint("BOTTOMRIGHT", -40, 46)
    f.content = CreateFrame("Frame", nil, scroll)
    f.content:SetSize(FRAME_W - 72, 1)
    scroll:SetScrollChild(f.content)

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.empty:SetPoint("CENTER", scroll, "CENTER")
    f.empty:SetText("No reports yet.")

    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.count:SetPoint("BOTTOMLEFT", 22, 20)

    local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clear:SetSize(100, 24)
    clear:SetPoint("BOTTOMRIGHT", -22, 16)
    clear:SetText("Clear all")
    clear:SetScript("OnClick", function() StaticPopup_Show("REPORTANNOUNCER_CLEAR") end)

    f:SetScript("OnShow", ns.RefreshHistory)
    tinsert(UISpecialFrames, "ReportAnnouncerHistoryFrame") -- Esc closes it
    f:Hide()
    return f
end

function ns.ToggleHistory()
    if win and win:IsShown() then
        win:Hide()
        return
    end
    if InCombatLockdown() then
        ns.Print("the history can't be opened during combat.")
        return
    end
    if not win then win = CreateWindow() end
    win:Show()
end

-- Hide the window (and its confirmation popup) as soon as combat starts.
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:SetScript("OnEvent", function()
    if win and win:IsShown() then win:Hide() end
    StaticPopup_Hide("REPORTANNOUNCER_CLEAR")
end)

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local button

local function PositionButton()
    local angle = math.rad(ns.InitDB().minimap.angle or 215)
    local radius = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    ns.InitDB().minimap.angle = math.deg(atan2(cy - my, cx - mx))
    PositionButton()
end

function ns.UpdateMinimapButton()
    if not button then return end
    if ns.InitDB().minimap.hide then
        button:Hide()
    else
        PositionButton()
        button:Show()
    end
end

function ns.CreateMinimapButton()
    if button then return end
    button = CreateFrame("Button", "ReportAnnouncerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477) -- minimap button highlight

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture(136430) -- minimap button border
    overlay:SetPoint("TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture(136467)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", 7, -6)

    button:SetScript("OnClick", function() ns.ToggleHistory() end)
    button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Report Announcer")
        GameTooltip:AddLine("Click: open your report history", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.UpdateMinimapButton()
end
