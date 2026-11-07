-- Messages tab: edit the report message and the group callout.
-- each can have several variants, one is picked at random.
local ADDON, ns = ...

local MAX_VARIANTS = 10
local VROW_H = 84
local msgState = { kind = "report" }

function ns.BuildMessages(page)
    local rows = {}
    local focused

    local function Cur()
        local db = ns.InitDB()
        return msgState.kind == "callout" and db.calloutMessages or db.messages
    end
    local function Defaults()
        return msgState.kind == "callout" and ns.DEFAULT_CALLOUTS or { ns.DEFAULT_MESSAGE }
    end

    local sections = {}
    local function MakeSection(key, text, x)
        local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        b:SetSize(236, 24)
        b:SetPoint("TOPLEFT", x, 0)
        b:SetText(text)
        b:SetScript("OnClick", function()
            msgState.kind = key
            ns.RefreshMessages()
        end)
        sections[key] = b
    end
    MakeSection("report", "When I report a player", 0)
    MakeSection("callout", "When a reported player joins", 242)

    local info = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 4, -32)
    info:SetWidth(456)
    info:SetJustifyH("LEFT")

    -- variable buttons type into the box you clicked last
    local prev
    for _, v in ipairs({ "name", "category", "reason", "details", "zone", "date" }) do
        local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        b:SetSize(72, 20)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 0, -72) end
        b:SetText(v)
        b:SetScript("OnClick", function()
            if focused and focused:IsVisible() then
                focused:SetFocus()
                focused:Insert("{" .. v .. "}")
            end
        end)
        prev = b
    end

    local scroll = CreateFrame("ScrollFrame", "ReportAnnouncerScrollmessages", page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -98)
    scroll:SetPoint("BOTTOMRIGHT", -24, 34)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(456, 1)
    scroll:SetScrollChild(content)

    local function GetRow(i)
        local r = rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, content)
        r:SetSize(456, VROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * VROW_H)

        r.box = CreateFrame("Frame", nil, r, BackdropTemplateMixin and "BackdropTemplate" or nil)
        r.box:SetPoint("TOPLEFT", 0, -2)
        r.box:SetSize(404, 46)
        ns.SkinBox(r.box)
        r.edit = CreateFrame("EditBox", nil, r.box)
        r.edit:SetPoint("TOPLEFT", 8, -6)
        r.edit:SetPoint("BOTTOMRIGHT", -8, 6)
        r.edit:SetMultiLine(true)
        r.edit:SetFontObject("GameFontHighlight")
        r.edit:SetAutoFocus(false)
        r.edit:SetMaxLetters(220)
        r.edit:SetScript("OnEscapePressed", r.edit.ClearFocus)
        r.edit:SetScript("OnEnterPressed", r.edit.ClearFocus)
        r.edit:SetScript("OnEditFocusGained", function(self) focused = self end)
        r.box:EnableMouse(true)
        r.box:SetScript("OnMouseDown", function() r.edit:SetFocus() end)

        r.num = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        r.num:SetPoint("TOPLEFT", r.box, "BOTTOMLEFT", 2, -4)

        r.preview = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.preview:SetPoint("TOPLEFT", r.box, "BOTTOMLEFT", 2, -4)
        r.preview:SetWidth(400)
        r.preview:SetJustifyH("LEFT")
        r.preview:SetWordWrap(false)

        r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.del:SetSize(30, 24)
        r.del:SetPoint("TOPLEFT", r.box, "TOPRIGHT", 6, -10)
        r.del:SetText("X")
        r.del:SetScript("OnClick", function()
            local list = Cur()
            if #list > 1 then
                table.remove(list, r.index)
                ns.RefreshMessages()
            end
        end)
        r.del:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Remove this message")
            GameTooltip:Show()
        end)
        r.del:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local function Preview()
            local text = r.edit:GetText()
            local ok, why = ns.ValidateTemplate(text)
            if ok then
                r.preview:SetTextColor(0.8, 0.8, 0.8)
                local vars = ns.SAMPLE_VARS()
                r.preview:SetText(ns.RenderTemplate(ns.CompileMessage(text), vars))
            else
                r.preview:SetTextColor(1, 0.3, 0.3)
                r.preview:SetText(why .. " (not used until fixed)")
            end
        end
        r.Preview = Preview
        r.edit:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            if text:find("[\r\n]") then -- one line only
                self:SetText((text:gsub("[\r\n]", "")))
                return
            end
            local list = Cur()
            if r.index and list[r.index] ~= nil and list[r.index] ~= text then list[r.index] = text end
            Preview()
        end)

        rows[i] = r
        return r
    end

    local add = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    add:SetSize(130, 24)
    add:SetPoint("BOTTOMLEFT", 0, 0)
    add:SetText("+ Add message")
    add:SetScript("OnClick", function()
        local list = Cur()
        if #list >= MAX_VARIANTS then return end
        list[#list + 1] = Defaults()[1]
        ns.RefreshMessages()
        C_Timer.After(0.05, function() scroll:SetVerticalScroll(scroll:GetVerticalScrollRange()) end)
    end)

    local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reset:SetSize(140, 24)
    reset:SetPoint("LEFT", add, "RIGHT", 8, 0)
    reset:SetText("Reset to default")
    reset:SetScript("OnClick", function()
        local list = Cur()
        wipe(list)
        for _, text in ipairs(Defaults()) do list[#list + 1] = text end
        ns.Print("messages reset to the default.")
        ns.RefreshMessages()
    end)

    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)

    function ns.RefreshMessages()
        local list = Cur()
        local isCallout = msgState.kind == "callout"
        for key, b in pairs(sections) do b:SetEnabled(key ~= msgState.kind) end
        info:SetText(isCallout
            and "Posted in party/raid chat when someone you reported is in your group (turn it on in Options). If you add several, one is picked at random. Empty variables drop their own words."
            or "Sent to chat when you report a player. If you add several, one is picked at random each time. {name} is required. Empty variables drop their own words.")
        for i, text in ipairs(list) do
            local r = GetRow(i)
            r.index = i
            r.edit:SetText(text)
            r.edit:SetCursorPosition(0)
            r.num:SetText("")
            r.del:SetEnabled(#list > 1)
            r.Preview()
            r:Show()
        end
        for i = #list + 1, #rows do rows[i]:Hide(); rows[i].index = nil end
        content:SetHeight(math.max(1, #list * VROW_H))
        add:SetEnabled(#list < MAX_VARIANTS)
        hint:SetText(#list .. " / " .. MAX_VARIANTS)
        ns.ApplyTheme()
    end

    page:SetScript("OnShow", ns.RefreshMessages)
end
