-- Options tab. the Game Menu entry is just a button that opens it.
local ADDON, ns = ...

local checks = {}

function ns.RefreshOptions()
    local db = ns.InitDB()
    if checks.tip then checks.tip:SetChecked(db.tooltip) end
    if checks.callout then checks.callout:SetChecked(db.callout) end
    if checks.share then checks.share:SetChecked(db.shareCount) end
    for key, cb in pairs(checks.chan or {}) do cb:SetChecked(db.announce[key]) end
    for key, b in pairs(checks.theme or {}) do b:SetEnabled(key ~= ns.GetThemeKey()) end
end

function ns.BuildOptions(page)
    checks.chan = {}

    local annLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    annLabel:SetPoint("TOPLEFT", 4, -8)
    annLabel:SetText("Announce in chat:")
    local prev
    for _, c in ipairs({ { "say", "/say" }, { "party", "/party" }, { "raid", "/raid" } }) do
        local key, text = c[1], c[2]
        local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        if prev then
            cb:SetPoint("LEFT", prev, "RIGHT", 52, 0)
        else
            cb:SetPoint("LEFT", annLabel, "RIGHT", 12, 0)
        end
        cb:SetScript("OnClick", function(self)
            ns.InitDB().announce[key] = self:GetChecked() and true or false
        end)
        local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        label:SetText(text)
        checks.chan[key] = cb
        prev = cb
    end

    checks.tip = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    checks.tip:SetSize(24, 24)
    checks.tip:SetPoint("TOPLEFT", 0, -34)
    checks.tip:SetScript("OnClick", function(self)
        ns.InitDB().tooltip = self:GetChecked() and true or false
    end)
    local tipLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tipLabel:SetPoint("LEFT", checks.tip, "RIGHT", 2, 0)
    tipLabel:SetText("Show reports in player tooltips (your own list only)")

    checks.callout = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    checks.callout:SetSize(24, 24)
    checks.callout:SetPoint("TOPLEFT", 0, -60)
    checks.callout:SetScript("OnClick", function(self)
        ns.InitDB().callout = self:GetChecked() and true or false
    end)
    checks.callout:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Call out reported players")
        GameTooltip:AddLine("When someone you reported is in your party or raid, posts a notice in party/raid chat (respects the /party and /raid switches above). Off by default. Imported lists are never used.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    checks.callout:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local calloutLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    calloutLabel:SetPoint("LEFT", checks.callout, "RIGHT", 2, 0)
    calloutLabel:SetText("Call out reported players who are in my group")

    checks.share = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    checks.share:SetSize(24, 24)
    checks.share:SetPoint("TOPLEFT", 0, -86)
    checks.share:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        ns.InitDB().shareCount = on
        if on and ns.BroadcastCount then ns.BroadcastCount(true) end
    end)
    checks.share:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Community tally")
        GameTooltip:AddLine("Sends only how many reports you have (a number, no names) to guild, group, channel and friend (character + Battle.net) contacts who also use the addon, and shows the combined total in Statistics. Off by default.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    checks.share:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local shareLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    shareLabel:SetPoint("LEFT", checks.share, "RIGHT", 2, 0)
    shareLabel:SetText("Share my report count with other addon users")

    -- theme
    local themeLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeLabel:SetPoint("TOPLEFT", 4, -128)
    themeLabel:SetText("Theme:")
    checks.theme = {}
    local prevBtn
    for _, th in ipairs(ns.THEME_LIST) do
        local key, text = th[1], th[2]
        local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        b:SetSize(100, 24)
        if prevBtn then b:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0) else b:SetPoint("LEFT", themeLabel, "RIGHT", 12, 0) end
        b:SetText(text)
        b:SetScript("OnClick", function()
            ns.SetTheme(key)
            ns.RefreshOptions()
        end)
        checks.theme[key] = b
        prevBtn = b
    end
end

---------------------------------------------------------------------------
-- Game Menu entry
---------------------------------------------------------------------------
local category

local function CreateStub()
    local panel = CreateFrame("Frame", "ReportAnnouncerOptionsPanel")
    panel.name = "Report Announcer"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Report Announcer")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    sub:SetText("All settings are in the Report Announcer window (Options tab).")

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(180, 24)
    open:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
    open:SetText("Open Report Announcer")
    open:SetScript("OnClick", function()
        pcall(function()
            if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
            if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        end)
        ns.OpenOptions()
    end)
    return panel
end

local function Register()
    local panel = CreateStub()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function ns.OpenOptions()
    if ns.ShowTab then ns.ShowTab("options") end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local ok, e = pcall(Register)
    if not ok then ns.Print("couldn't create the options panel: " .. tostring(e)) end
end)
