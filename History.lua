-- main window with the side tabs, and the minimap button
local ADDON, ns = ...

local FRAME_W, FRAME_H = 660, 500
local CONTENT_X = 156
local LIST_W = FRAME_W - CONTENT_X - 22 - 24
local ROW_H = 48
local RIGHT_W = 64 -- room for the delete button

local TABS = {
    { key = "personal", label = "Personal List", icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { key = "imported", label = "Imported Lists", icon = "Interface\\Icons\\INV_Letter_02" },
    { key = "messages", label = "Messages", icon = "Interface\\Icons\\INV_Scroll_03" },
    { key = "stats", label = "Statistics", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "options", label = "Options", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

local win

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

---------------------------------------------------------------------------
-- list pages (personal and imported use the same rows)
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

local function GetRow(page, i)
    local r = page.rows[i]
    if r then return r end
    local content = page.content
    local textW = LIST_W - RIGHT_W

    r = CreateFrame("Frame", nil, content)
    r:SetSize(LIST_W, ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:EnableMouse(true)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()

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

    r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
    r.del:SetHeight(22)
    r.del:SetPoint("RIGHT", -4, 0)
    r.del:SetScript("OnClick", function()
        local item = r.item
        if not item then return end
        if item.kind == "header" then
            ns.DeleteImportedList(item.list)
        else
            RemoveEntry(item.entry)
        end
        ns.RefreshHistory()
    end)
    r.del:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local item = r.item
        GameTooltip:SetText(item and item.kind == "header" and "Delete this imported list"
            or "Delete this report from the history")
        GameTooltip:Show()
    end)
    r.del:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- hover shows everything (lines are cut short)
    r:SetScript("OnEnter", function(self)
        local item = self.item
        if not item or item.kind ~= "entry" then return end
        local e = item.entry
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(e.name or "?", 1, 0.82, 0)
        GameTooltip:AddLine(ns.ReasonText(e), 1, 1, 1, true)
        GameTooltip:AddLine("Zone: " .. (e.zone ~= "" and e.zone or "?"), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Date: " .. ns.DateText(e), 0.8, 0.8, 0.8, true)
        if e.comment then
            GameTooltip:AddLine("Details: " .. e.comment, 0.8, 0.8, 0.8, true)
        end
        if item.source then
            GameTooltip:AddLine("Imported from " .. item.source, 0.4, 0.8, 1, true)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)

    page.rows[i] = r
    return r
end

local function ConfigureRow(r, item, i)
    r.item = item
    if item.kind == "header" then
        local l = item.list
        r.bg:SetColorTexture(0.2, 0.5, 0.8, 0.2)
        r.line1:SetText("|cff66ccffShared by " .. l.source .. "|r")
        r.line2:SetText(#l.entries .. " report" .. (#l.entries == 1 and "" or "s")
            .. "  -  imported " .. date("%Y-%m-%d", l.t or 0))
        r.line3:SetText("")
        r.del:SetText("Delete")
        r.del:SetWidth(54)
        r.del:Show()
    else
        local e = item.entry
        r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.06 or 0)
        r.line1:SetText("|cffffd100" .. (e.name or "?") .. "|r   |cff888888" .. ns.DateText(e) .. "|r")
        r.line2:SetText(ns.ReasonText(e))
        local line3 = (e.zone and e.zone ~= "") and e.zone or "?"
        if e.comment then line3 = line3 .. "  -  Details: " .. e.comment end
        r.line3:SetText(line3)
        if item.deletable then
            r.del:SetText("X")
            r.del:SetWidth(24)
            r.del:Show()
        else
            r.del:Hide()
        end
    end
    r:Show()
end

local function MakeListPage(f, key, emptyText)
    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -50)
    page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 52)
    page.rows = {}

    local scroll = CreateFrame("ScrollFrame", "ReportAnnouncerScroll" .. key, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    page.content = CreateFrame("Frame", nil, scroll)
    page.content:SetSize(LIST_W, 1)
    scroll:SetScrollChild(page.content)

    page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    page.empty:SetPoint("CENTER", scroll, "CENTER")
    page.empty:SetWidth(LIST_W - 40)
    page.empty:SetText(emptyText)

    function page.SetItems(items)
        for i, item in ipairs(items) do
            ConfigureRow(GetRow(page, i), item, i)
        end
        for i = #items + 1, #page.rows do page.rows[i]:Hide() end
        page.content:SetHeight(math.max(1, #items * ROW_H))
        page.empty:SetShown(#items == 0)
    end
    return page
end

---------------------------------------------------------------------------
-- Statistics page
---------------------------------------------------------------------------
local BAR_X, BAR_MAX, VALUE_X = 156, 230, 392

local function MakeStatsPage(f)
    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -50)
    page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 52)
    page.lines = {}

    page.inc = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    page.inc:SetSize(24, 24)
    page.inc:SetPoint("TOPLEFT", -4, 0)
    page.inc:SetScript("OnClick", function(self)
        ns.InitDB().statsImports = self:GetChecked() and true or false
        ns.RefreshHistory()
    end)
    local incLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    incLabel:SetPoint("LEFT", page.inc, "RIGHT", 2, 0)
    incLabel:SetText("Include imported lists")

    local scroll = CreateFrame("ScrollFrame", "ReportAnnouncerScrollstats", page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -30)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    page.content = CreateFrame("Frame", nil, scroll)
    page.content:SetSize(LIST_W, 1)
    scroll:SetScrollChild(page.content)
    return page
end

local function GetStatLine(page, i)
    local l = page.lines[i]
    if l then return l end
    l = {}
    l.label = page.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    l.label:SetJustifyH("LEFT")
    l.label:SetWordWrap(false)
    l.bar = page.content:CreateTexture(nil, "ARTWORK")
    l.bar:SetColorTexture(0.2, 0.6, 1, 0.8)
    l.value = page.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.value:SetJustifyH("LEFT")
    page.lines[i] = l
    return l
end

local function RefreshStats()
    local page = win.pages.stats
    local db = ns.InitDB()
    page.inc:SetChecked(db.statsImports)
    local s = ns.ComputeStats(db.statsImports)

    local n, y = 0, 0
    local function Line() n = n + 1; return GetStatLine(page, n) end
    local function Text(font, text, gap)
        y = y + (gap or 0)
        local l = Line()
        l.label:SetFontObject(font)
        l.label:ClearAllPoints()
        l.label:SetPoint("TOPLEFT", page.content, "TOPLEFT", 4, -y)
        l.label:SetWidth(LIST_W - 8)
        l.label:SetText(text)
        l.label:Show(); l.bar:Hide(); l.value:Hide()
        y = y + 20
    end
    local function Section(title, list, asCount)
        if #list == 0 then return end
        Text("GameFontNormal", title, 10)
        for _, item in ipairs(list) do
            local l = Line()
            l.label:SetFontObject("GameFontHighlight")
            l.label:ClearAllPoints()
            l.label:SetPoint("TOPLEFT", page.content, "TOPLEFT", 10, -y)
            l.label:SetWidth(BAR_X - 16)
            l.label:SetText(item.label)
            l.bar:ClearAllPoints()
            l.bar:SetPoint("TOPLEFT", page.content, "TOPLEFT", BAR_X, -(y + 2))
            l.bar:SetSize(math.max(2, math.floor(BAR_MAX * item.n / list[1].n)), 12)
            l.value:ClearAllPoints()
            l.value:SetPoint("TOPLEFT", page.content, "TOPLEFT", VALUE_X, -(y + 2))
            l.value:SetText(asCount and ("x" .. item.n)
                or string.format("%d (%d%%)", item.n, math.floor(item.n * 100 / s.total + 0.5)))
            l.label:Show(); l.bar:Show(); l.value:Show()
            y = y + 18
        end
    end

    if db.shareCount and ns.CommunityTally then
        local users, total = ns.CommunityTally()
        Text("GameFontNormal", "Community")
        y = y - 4
        Text("GameFontHighlight", users .. " addon user" .. (users == 1 and "" or "s")
            .. " seen (guild/groups), " .. total .. " reports in total")
    else
        Text("GameFontDisable", "Community tally is off. Turn it on in Options to count reports with other addon users.")
    end
    if s.total == 0 then
        Text("GameFontDisable", "No reports to analyse yet.", 10)
    else
        Text("GameFontHighlight", s.total .. " report" .. (s.total == 1 and "" or "s")
            .. " on " .. s.players .. " player" .. (s.players == 1 and "" or "s"))
        Section("What people get reported for", s.categories)
        Section("Reasons", s.reasons)
        Section("Where it happens", s.zones)
        Section("Reported more than once", s.repeats, true)
    end
    for i = n + 1, #page.lines do
        local l = page.lines[i]
        l.label:Hide(); l.bar:Hide(); l.value:Hide()
    end
    page.content:SetHeight(math.max(1, y + 10))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function ImportedItems()
    local items = {}
    for _, list in ipairs(ns.InitDB().imports) do
        items[#items + 1] = { kind = "header", list = list }
        for _, e in ipairs(list.entries) do
            items[#items + 1] = { kind = "entry", entry = e, source = list.source }
        end
    end
    return items
end

function ns.RefreshHistory()
    if not win or not win:IsShown() then return end
    local db = ns.InitDB()
    local tab = win.tab

    for key, b in pairs(win.tabButtons) do
        b.selected:SetShown(key == tab)
        win.pages[key]:SetShown(key == tab)
    end

    win.clear:SetShown(tab == "personal")
    win.export:SetShown(tab == "personal")
    win.import:SetShown(tab == "personal" or tab == "imported")
    win.import:ClearAllPoints()
    if tab == "personal" then
        win.import:SetPoint("LEFT", win.export, "RIGHT", 6, 0)
    else
        win.import:SetPoint("BOTTOMLEFT", 22, 16)
    end

    local countText = ""
    if tab == "personal" then
        local items = {}
        for _, e in ipairs(db.history) do items[#items + 1] = { kind = "entry", entry = e, deletable = true } end
        win.pages.personal.SetItems(items)
        countText = #items .. " report" .. (#items == 1 and "" or "s")
    elseif tab == "imported" then
        local items = ImportedItems()
        win.pages.imported.SetItems(items)
        local reports = #items - #db.imports
        countText = #db.imports .. " list" .. (#db.imports == 1 and "" or "s") .. ", "
            .. reports .. " report" .. (reports == 1 and "" or "s")
    elseif tab == "stats" then
        RefreshStats()
    elseif tab == "messages" then
        if ns.RefreshMessages then ns.RefreshMessages() end
    elseif tab == "options" then
        if ns.RefreshOptions then ns.RefreshOptions() end
    end
    win.count:SetText(countText)
end

local function SelectTab(key)
    win.tab = key
    ns.RefreshHistory()
end

StaticPopupDialogs["REPORTANNOUNCER_CLEAR"] = {
    text = "Are you sure?\n\nThis deletes your entire personal report history and cannot be undone. Imported lists are not affected.",
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

local function MakeTabButton(f, index, tab)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(124, 38)
    b:SetPoint("TOPLEFT", 22, -52 - (index - 1) * 42)

    b.selected = b:CreateTexture(nil, "BACKGROUND")
    b.selected:SetAllPoints()
    b.selected:SetColorTexture(1, 0.82, 0, 0.2)
    b.selected:Hide()

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.1)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(28, 28)
    b.icon:SetPoint("LEFT", 5, 0)
    b.icon:SetTexture(tab.icon)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text:SetPoint("RIGHT", -2, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetText(tab.label)

    b:SetScript("OnClick", function() SelectTab(tab.key) end)
    return b
end

local function CreateWindow()
    local f = CreateFrame("Frame", "ReportAnnouncerHistoryFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH") -- below the popups
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    ns.DialogBackdrop(f)
    f.tab = "personal"

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Report Announcer")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    -- side tabs
    f.tabButtons = {}
    for i, tab in ipairs(TABS) do
        f.tabButtons[tab.key] = MakeTabButton(f, i, tab)
    end
    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.15)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", CONTENT_X - 6, -50)
    divider:SetPoint("BOTTOMLEFT", CONTENT_X - 6, 52)

    -- pages
    f.pages = {
        personal = MakeListPage(f, "personal", "No reports yet."),
        imported = MakeListPage(f, "imported",
            "No imported lists.\nUse Import to add a list someone shared with you."),
        stats = MakeStatsPage(f),
    }
    local options = CreateFrame("Frame", nil, f)
    options:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -50)
    options:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 52)
    if ns.BuildOptions then ns.BuildOptions(options) end
    f.pages.options = options

    local messages = CreateFrame("Frame", nil, f)
    messages:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -50)
    messages:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 52)
    if ns.BuildMessages then ns.BuildMessages(messages) end
    f.pages.messages = messages

    -- bottom bar
    f.clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.clear:SetSize(100, 24)
    f.clear:SetPoint("BOTTOMLEFT", 22, 16)
    f.clear:SetText("Clear all")
    f.clear:SetScript("OnClick", function() StaticPopup_Show("REPORTANNOUNCER_CLEAR") end)

    f.export = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.export:SetSize(100, 24)
    f.export:SetPoint("LEFT", f.clear, "RIGHT", 6, 0)
    f.export:SetText("Export")
    f.export:SetScript("OnClick", function() ns.ShowExport() end)

    f.import = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.import:SetSize(100, 24)
    f.import:SetText("Import")
    f.import:SetScript("OnClick", function() ns.ShowImport() end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", -22, 16)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.count:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)

    f:SetScript("OnShow", ns.RefreshHistory)
    tinsert(UISpecialFrames, "ReportAnnouncerHistoryFrame") -- esc closes it
    f:Hide()
    return f
end

-- open the window on a tab, not in combat
function ns.ShowTab(key)
    if InCombatLockdown() then
        ns.Print("the window can't be opened during combat.")
        return
    end
    if not win then win = CreateWindow() end
    win.tab = key or win.tab
    if win:IsShown() then ns.RefreshHistory() else win:Show() end
end

function ns.ToggleHistory()
    if win and win:IsShown() then
        win:Hide()
        return
    end
    ns.ShowTab()
end

-- hide it when combat starts
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
    button:SetHighlightTexture(136477)

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture(136430)
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
