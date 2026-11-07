-- Options page. It lives in the "Options" tab of the main window (ns.BuildOptions);
-- the Game Menu > Options > AddOns entry is a small stub that opens that tab.
local ADDON, ns = ...

local checks = {}

function ns.RefreshOptions()
    local db = ns.InitDB()
    if checks.tip then checks.tip:SetChecked(db.tooltip) end
    if checks.callout then checks.callout:SetChecked(db.callout) end
    if checks.share then checks.share:SetChecked(db.shareCount) end
    for key, cb in pairs(checks.chan or {}) do cb:SetChecked(db.announce[key]) end
end

function ns.BuildOptions(page)
    checks.chan = {}

    -- chat announcing switches
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

    -- tooltip switch
    checks.tip = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    checks.tip:SetSize(24, 24)
    checks.tip:SetPoint("TOPLEFT", 0, -34)
    checks.tip:SetScript("OnClick", function(self)
        ns.InitDB().tooltip = self:GetChecked() and true or false
    end)
    local tipLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tipLabel:SetPoint("LEFT", checks.tip, "RIGHT", 2, 0)
    tipLabel:SetText("Show reports in player tooltips (your own list only)")

    -- group callout switch (opt-in)
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

    -- community tally switch (opt-in)
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

    -- message: simple mode (default) or advanced raw template
    local sub = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sub:SetPoint("TOPLEFT", 4, -126)
    sub:SetText("Message sent to chat when you report a player")

    local simple = CreateFrame("Frame", nil, page)
    simple:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -150)
    simple:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    local adv = CreateFrame("Frame", nil, page)
    adv:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -150)
    adv:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)

    local DEFAULTS = { phrase = "was reported", category = true, reasons = true, details = true, zone = false, date = false }

    local function Generate(s)
        local phrase = (s.phrase or ""):gsub("[%[%]{}]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        local t = "{name}" .. (phrase ~= "" and (" " .. phrase) or "")
        if s.category then t = t .. "[ for {category}]" end
        if s.reasons then t = t .. "[, the reason: {reasons}]" end
        t = t .. "."
        if s.details then t = t .. "[ Details: {details}]" end
        if s.zone then t = t .. "[ Zone: {zone}]" end
        if s.date then t = t .. "[ ({date})]" end
        return t
    end

    local function Cfg()
        local db = ns.InitDB()
        if not db.simple then
            db.simple = {}
            for k, v in pairs(DEFAULTS) do db.simple[k] = v end
            db.advanced = (db.template ~= ns.DEFAULT_TEMPLATE) -- keep an existing custom message
        end
        return db, db.simple
    end

    ---------------- simple mode ----------------
    local nameLabel = simple:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 4, -12)
    nameLabel:SetText("|cff66ccffPlayer name|r")

    local phrase = CreateFrame("EditBox", nil, simple, "InputBoxTemplate")
    phrase:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
    phrase:SetSize(240, 24)
    phrase:SetAutoFocus(false)
    phrase:SetMaxLetters(60)
    phrase:SetScript("OnEscapePressed", phrase.ClearFocus)
    phrase:SetScript("OnEnterPressed", phrase.ClearFocus)

    local incLabel = simple:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    incLabel:SetPoint("TOPLEFT", 4, -48)
    incLabel:SetText("Include:")
    local incChecks = {}
    local prev
    for _, c in ipairs({ { "category", "Category" }, { "reasons", "Reasons" }, { "details", "Details" },
        { "zone", "Zone" }, { "date", "Date" } }) do
        local key, text = c[1], c[2]
        local cb = CreateFrame("CheckButton", nil, simple, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        if prev then cb:SetPoint("LEFT", prev, "RIGHT", 62, 0) else cb:SetPoint("LEFT", incLabel, "RIGHT", 6, 0) end
        local label = simple:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        label:SetText(text)
        incChecks[key] = cb
        prev = cb
    end

    local sPreviewTitle = simple:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sPreviewTitle:SetPoint("TOPLEFT", 4, -84)
    sPreviewTitle:SetText("Preview")
    local sPreview = simple:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sPreview:SetPoint("TOPLEFT", sPreviewTitle, "BOTTOMLEFT", 0, -4)
    sPreview:SetWidth(456)
    sPreview:SetJustifyH("LEFT")

    local toAdv = CreateFrame("Button", nil, simple, "UIPanelButtonTemplate")
    toAdv:SetSize(200, 24)
    toAdv:SetPoint("BOTTOMLEFT", 0, 0)
    toAdv:SetText("Advanced: custom template")

    local function ApplySimple()
        local db, s = Cfg()
        s.phrase = phrase:GetText()
        for key, cb in pairs(incChecks) do s[key] = cb:GetChecked() and true or false end
        db.template = Generate(s)
        sPreview:SetText(ns.RenderTemplate(db.template, ns.SAMPLE_VARS()))
    end
    phrase:SetScript("OnTextChanged", function(_, user) if user then ApplySimple() end end)
    for _, cb in pairs(incChecks) do cb:SetScript("OnClick", ApplySimple) end

    ---------------- advanced mode ----------------
    local aTitle = adv:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    aTitle:SetPoint("TOPLEFT", 4, -4)
    aTitle:SetText("Use {name} (required), {category}, {reasons}, {details}, {zone}, {date}. Put optional parts in [ ].")

    local box = CreateFrame("Frame", nil, adv, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetPoint("TOPLEFT", aTitle, "BOTTOMLEFT", 0, -8)
    box:SetPoint("RIGHT", page, "RIGHT", -8, 0)
    box:SetHeight(66)
    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.6)
        box:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    end
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", 8, -7)
    edit:SetPoint("BOTTOMRIGHT", -8, 7)
    edit:SetMultiLine(true)
    edit:SetFontObject("GameFontHighlight")
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(220)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnEnterPressed", edit.ClearFocus)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)

    local previewTitle = adv:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewTitle:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
    previewTitle:SetText("Preview")
    local preview = adv:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    preview:SetPoint("TOPLEFT", previewTitle, "BOTTOMLEFT", 0, -4)
    preview:SetWidth(456)
    preview:SetJustifyH("LEFT")
    local err = adv:CreateFontString(nil, "OVERLAY", "GameFontRed")
    err:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -8)
    err:SetWidth(456)
    err:SetJustifyH("LEFT")

    local save = CreateFrame("Button", nil, adv, "UIPanelButtonTemplate")
    save:SetSize(80, 24)
    save:SetPoint("BOTTOMLEFT", 0, 0)
    save:SetText("Save")
    local toSimple = CreateFrame("Button", nil, adv, "UIPanelButtonTemplate")
    toSimple:SetSize(190, 24)
    toSimple:SetPoint("LEFT", save, "RIGHT", 8, 0)
    toSimple:SetText("Back to simple (resets)")

    local function RefreshAdv()
        local text = edit:GetText()
        local ok, why = ns.ValidateTemplate(text)
        if ok then
            preview:SetText(ns.RenderTemplate(text, ns.SAMPLE_VARS()))
            err:SetText("")
            save:SetEnabled(text ~= ns.InitDB().template)
        else
            preview:SetText("")
            err:SetText(why)
            save:Disable()
        end
    end
    edit:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text:find("[\r\n]") then -- single-line message: drop line breaks
            self:SetText((text:gsub("[\r\n]", "")))
            return
        end
        RefreshAdv()
    end)
    save:SetScript("OnClick", function()
        local text = edit:GetText()
        if ns.ValidateTemplate(text) then
            ns.InitDB().template = text
            ns.Print("message saved.")
            edit:ClearFocus()
            RefreshAdv()
        end
    end)

    ---------------- switching ----------------
    local function Show()
        local db, s = Cfg()
        simple:SetShown(not db.advanced)
        adv:SetShown(db.advanced and true or false)
        if db.advanced then
            edit:SetText(db.template)
            edit:SetCursorPosition(0)
            RefreshAdv()
        else
            phrase:SetText(s.phrase or "")
            for key, cb in pairs(incChecks) do cb:SetChecked(s[key]) end
            sPreview:SetText(ns.RenderTemplate(db.template, ns.SAMPLE_VARS()))
        end
    end
    toAdv:SetScript("OnClick", function() ns.InitDB().advanced = true; Show() end)
    toSimple:SetScript("OnClick", function()
        local db, s = Cfg()
        for k, v in pairs(DEFAULTS) do s[k] = v end
        db.advanced = false
        db.template = Generate(s)
        ns.Print("message reset to the simple default.")
        Show()
    end)

    page:SetScript("OnShow", Show)
end

---------------------------------------------------------------------------
-- Game Menu > Options > AddOns stub
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
