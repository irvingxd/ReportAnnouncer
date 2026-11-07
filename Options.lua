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

    local LABELS = { category = "for", reasons = "the reason:", details = "Details:", zone = "Zone:", date = "Date:" }
    local DEFAULTS = { phrase = "was reported", category = true, reasons = true, details = true, zone = false, date = false }

    local function Clean(text)
        return ((text or ""):gsub("[%[%]{}]", ""):gsub("^%s+", ""):gsub("%s+$", ""))
    end

    -- every wording part is editable; the variables stay in place
    local function Generate(s)
        local phrase = Clean(s.phrase)
        local L = s.labels
        local function Part(sep, key, var)
            local label = Clean(L[key])
            return "[" .. sep .. (label ~= "" and (label .. " ") or "") .. "{" .. var .. "}]"
        end
        local t = "{name}" .. (phrase ~= "" and (" " .. phrase) or "")
        if s.category then t = t .. Part(" ", "category", "category") end
        if s.reasons then t = t .. Part(", ", "reasons", "reasons") end
        t = t .. "."
        if s.details then t = t .. Part(" ", "details", "details") end
        if s.zone then t = t .. Part(" ", "zone", "zone") end
        if s.date then t = t .. Part(" ", "date", "date") end
        return t
    end

    local function Cfg()
        local db = ns.InitDB()
        if not db.simple then
            db.simple = {}
            for k, v in pairs(DEFAULTS) do db.simple[k] = v end
            db.advanced = (db.template ~= ns.DEFAULT_TEMPLATE) -- keep an existing custom message
        end
        db.simple.labels = db.simple.labels or {}
        for k, v in pairs(LABELS) do
            if db.simple.labels[k] == nil then db.simple.labels[k] = v end
        end
        return db, db.simple
    end

    ---------------- simple mode ----------------
    local function Tag(parent, text)
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetText("|cff66ccff<" .. text .. ">|r")
        return fs
    end
    local function Input(parent, width, maxLetters)
        local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        e:SetSize(width, 24)
        e:SetAutoFocus(false)
        e:SetMaxLetters(maxLetters)
        e:SetScript("OnEscapePressed", e.ClearFocus)
        e:SetScript("OnEnterPressed", e.ClearFocus)
        return e
    end

    local ROW = 26
    -- row 1: <Player name> [was reported]
    local nameTag = Tag(simple, "Player name")
    nameTag:SetPoint("TOPLEFT", 4, -8)
    local phrase = Input(simple, 220, 60)
    phrase:SetPoint("LEFT", nameTag, "RIGHT", 14, 0)

    -- rows 2-6: [x] [wording] <Variable>
    local rows = {}
    for i, c in ipairs({ { "category", "Category" }, { "reasons", "Reasons" }, { "details", "Details you typed" },
        { "zone", "Zone" }, { "date", "Date" } }) do
        local key, tagText = c[1], c[2]
        local y = -8 - i * ROW
        local cb = CreateFrame("CheckButton", nil, simple, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", -2, y + 4)
        local input = Input(simple, 150, 40)
        input:SetPoint("TOPLEFT", 40, y + 2)
        local tag = Tag(simple, tagText)
        tag:SetPoint("LEFT", input, "RIGHT", 12, 0)
        rows[key] = { cb = cb, input = input }
    end

    local sPreviewTitle = simple:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sPreviewTitle:SetPoint("TOPLEFT", 4, -8 - 6 * ROW - 8)
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
        for key, r in pairs(rows) do
            s[key] = r.cb:GetChecked() and true or false
            s.labels[key] = r.input:GetText()
        end
        db.template = Generate(s)
        sPreview:SetText(ns.RenderTemplate(db.template, ns.SAMPLE_VARS()))
    end
    local function LoadSimple()
        local db, s = Cfg()
        phrase:SetText(s.phrase or "")
        phrase:SetCursorPosition(0)
        for key, r in pairs(rows) do
            r.cb:SetChecked(s[key])
            r.input:SetText(s.labels[key] or "")
            r.input:SetCursorPosition(0)
        end
        sPreview:SetText(ns.RenderTemplate(db.template, ns.SAMPLE_VARS()))
    end
    phrase:SetScript("OnTextChanged", function(_, user) if user then ApplySimple() end end)
    for _, r in pairs(rows) do
        r.cb:SetScript("OnClick", ApplySimple)
        r.input:SetScript("OnTextChanged", function(_, user) if user then ApplySimple() end end)
    end

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
    toSimple:SetSize(140, 24)
    toSimple:SetPoint("LEFT", save, "RIGHT", 8, 0)
    toSimple:SetText("Reset to default")

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
            LoadSimple()
        end
    end
    toAdv:SetScript("OnClick", function() ns.InitDB().advanced = true; Show() end)
    toSimple:SetScript("OnClick", function()
        local db, s = Cfg()
        for k, v in pairs(DEFAULTS) do s[k] = v end
        for k, v in pairs(LABELS) do s.labels[k] = v end
        db.advanced = false
        db.template = Generate(s)
        ns.Print("message reset to the default.")
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
