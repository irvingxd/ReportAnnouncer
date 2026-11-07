-- Options panel (Game Menu > Options > AddOns > Report Announcer): customise the
-- message that is sent when you report a player.
local ADDON, ns = ...

local category

local function CreatePanel()
    local panel = CreateFrame("Frame", "ReportAnnouncerOptionsPanel")
    panel.name = "Report Announcer"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Report Announcer")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    sub:SetText("Message sent to chat when you report a player")

    local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    edit:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 6, -14)
    edit:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    edit:SetHeight(24)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(220)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnEnterPressed", edit.ClearFocus)

    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -6, -10)
    help:SetWidth(520)
    help:SetJustifyH("LEFT")
    help:SetText("Variables: {name} (required)  {category}  {reasons}  {details}  {zone}  {date}\n"
        .. "Optional parts go in [ ]. They are left out when a variable inside is empty,\n"
        .. "e.g. [ Details: {details}] only appears if you typed details.")

    local previewTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewTitle:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -16)
    previewTitle:SetText("Preview")

    local preview = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    preview:SetPoint("TOPLEFT", previewTitle, "BOTTOMLEFT", 0, -6)
    preview:SetWidth(520)
    preview:SetJustifyH("LEFT")

    local err = panel:CreateFontString(nil, "ARTWORK", "GameFontRed")
    err:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -10)
    err:SetWidth(520)
    err:SetJustifyH("LEFT")

    local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    save:SetSize(100, 24)
    save:SetPoint("TOPLEFT", err, "BOTTOMLEFT", 0, -12)
    save:SetText("Save")

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(140, 24)
    reset:SetPoint("LEFT", save, "RIGHT", 8, 0)
    reset:SetText("Reset to default")

    local function Refresh()
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
    edit:SetScript("OnTextChanged", Refresh)

    save:SetScript("OnClick", function()
        local text = edit:GetText()
        if ns.ValidateTemplate(text) then
            ns.InitDB().template = text
            ns.Print("message saved.")
            edit:ClearFocus()
            Refresh()
        end
    end)

    reset:SetScript("OnClick", function()
        ns.InitDB().template = ns.DEFAULT_TEMPLATE
        edit:SetText(ns.DEFAULT_TEMPLATE)
        ns.Print("message reset to the default.")
        Refresh()
    end)

    panel:SetScript("OnShow", function()
        edit:SetText(ns.InitDB().template)
        edit:SetCursorPosition(0)
        Refresh()
    end)

    return panel
end

local function Register()
    local panel = CreatePanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        ns.optionsPanel = panel
    end
end

function ns.OpenOptions()
    if InCombatLockdown() then
        ns.Print("the options can't be opened during combat.")
        return
    end
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif ns.optionsPanel and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel) -- needs two calls on old clients
        InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
    else
        ns.Print("couldn't find the options window on this client.")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local ok, e = pcall(Register)
    if not ok then ns.Print("couldn't create the options panel: " .. tostring(e)) end
end)
