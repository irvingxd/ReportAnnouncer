-- share your list as a text string and import lists from others.
-- imported lists stay apart from yours, never used in tooltips or callouts.
--
-- format: RA1:<base64 payload>:<checksum>
-- this is encoding, not encryption. it only catches broken or edited strings.
local ADDON, ns = ...

local RS, FS = "\30", "\31" -- record / field separators
local MAX_ENTRIES = 500
local MAX_LISTS = 20
local MAX_FIELD = 200

---------------------------------------------------------------------------
-- base64 + checksum
---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, #B64 do B64_INDEX[B64:sub(i, i)] = i - 1 end

local function B64Encode(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local v = a * 65536 + (b or 0) * 256 + (c or 0)
        local i1, i2 = math.floor(v / 262144), math.floor(v / 4096) % 64
        local i3, i4 = math.floor(v / 64) % 64, v % 64
        out[#out + 1] = B64:sub(i1 + 1, i1 + 1) .. B64:sub(i2 + 1, i2 + 1)
            .. (b and B64:sub(i3 + 1, i3 + 1) or "=") .. (c and B64:sub(i4 + 1, i4 + 1) or "=")
    end
    return table.concat(out)
end

local function B64Decode(s)
    if #s % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #s, 4 do
        local c1, c2, c3, c4 = s:sub(i, i), s:sub(i + 1, i + 1), s:sub(i + 2, i + 2), s:sub(i + 3, i + 3)
        local v1, v2 = B64_INDEX[c1], B64_INDEX[c2]
        local v3, v4 = B64_INDEX[c3], B64_INDEX[c4]
        if not v1 or not v2 then return nil end
        if c3 == "=" then v3 = 0 elseif not v3 then return nil end
        if c4 == "=" then v4 = 0 elseif not v4 then return nil end
        local v = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
        out[#out + 1] = string.char(math.floor(v / 65536))
        if c3 ~= "=" then out[#out + 1] = string.char(math.floor(v / 256) % 256) end
        if c4 ~= "=" then out[#out + 1] = string.char(v % 256) end
    end
    return table.concat(out)
end

local function Checksum(s) -- Adler-32
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%04x%04x", b, a)
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function Split(s, sep)
    local t, pos = {}, 1
    while true do
        local i = s:find(sep, pos, true)
        if not i then
            t[#t + 1] = s:sub(pos)
            return t
        end
        t[#t + 1] = s:sub(pos, i - 1)
        pos = i + 1
    end
end

-- outgoing text: drop control characters
local function CleanOut(v)
    return (tostring(v or ""):gsub("%c", ""))
end

-- incoming text is untrusted: drop control characters, cap length,
-- double the pipes so |c |H |T codes do nothing
local function CleanIn(v)
    v = tostring(v or ""):gsub("%c", "")
    if #v > MAX_FIELD then v = v:sub(1, MAX_FIELD) end
    v = v:gsub("|", "||")
    return v
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------
-- returns the string and how many reports are in it
function ns.ExportPersonal(includeDetails)
    local db = ns.InitDB()
    local player = UnitName and UnitName("player") or "?"
    local records = { table.concat({ "RA", "1", CleanOut(player), tostring(time()) }, FS) }
    for _, e in ipairs(db.history) do
        records[#records + 1] = table.concat({
            CleanOut(e.name), CleanOut(e.guid), CleanOut(e.category), CleanOut(e.reasons),
            CleanOut(e.zone), tostring(e.t or 0), includeDetails and CleanOut(e.comment) or "",
        }, FS)
    end
    local payload = table.concat(records, RS)
    return "RA1:" .. B64Encode(payload) .. ":" .. Checksum(payload), #db.history
end

---------------------------------------------------------------------------
-- Import
---------------------------------------------------------------------------
-- returns { source, t, entries, skipped } or nil + error
function ns.ParseShareString(str)
    str = (str or ""):gsub("%s+", "")
    if str == "" then return nil, "" end
    local ver, body, sum = str:match("^RA(%d+):([A-Za-z0-9+/=]+):(%x+)$")
    if not ver then return nil, "That doesn't look like a Report Announcer string." end
    if ver ~= "1" then return nil, "This string is from a newer version of the addon." end
    local payload = B64Decode(body)
    if not payload then return nil, "The string is damaged." end
    if Checksum(payload) ~= sum then
        return nil, "The string is damaged or was edited (checksum doesn't match)."
    end

    local records = Split(payload, RS)
    local head = Split(records[1] or "", FS)
    if head[1] ~= "RA" or head[2] ~= "1" then return nil, "The string is damaged." end
    local source = CleanIn(head[3]):sub(1, 40)
    if source == "" then source = "Unknown" end

    local list = { source = source, t = tonumber(head[4]) or 0, entries = {}, skipped = 0 }
    for i = 2, #records do
        local f = Split(records[i], FS)
        if #f == 7 and f[1] ~= "" then
            if #list.entries >= MAX_ENTRIES then
                list.skipped = list.skipped + 1
            else
                local guid = f[2]
                if not guid:match("^Player%-%d+%-%x+$") then guid = nil end
                local t = tonumber(f[6]) or 0
                if t < 0 or t > time() + 86400 then t = 0 end
                list.entries[#list.entries + 1] = {
                    name = CleanIn(f[1]), guid = guid,
                    category = f[3] ~= "" and CleanIn(f[3]) or nil,
                    reasons = CleanIn(f[4]), zone = CleanIn(f[5]), t = t,
                    comment = f[7] ~= "" and CleanIn(f[7]) or nil,
                }
            end
        end
    end
    return list
end

-- same sender importing again replaces their old list
-- returns true + "added"/"updated", or false + message
function ns.ImportList(list)
    local imports = ns.InitDB().imports
    for i, existing in ipairs(imports) do
        if strlower(existing.source) == strlower(list.source) then
            imports[i] = { source = list.source, t = time(), entries = list.entries }
            return true, "updated"
        end
    end
    if #imports >= MAX_LISTS then
        return false, "You already have " .. MAX_LISTS .. " imported lists. Delete one first."
    end
    imports[#imports + 1] = { source = list.source, t = time(), entries = list.entries }
    return true, "added"
end

function ns.DeleteImportedList(list)
    local imports = ns.InitDB().imports
    for i, l in ipairs(imports) do
        if l == list then
            table.remove(imports, i)
            return
        end
    end
end

---------------------------------------------------------------------------
-- dialogs
---------------------------------------------------------------------------
local dialog

local function CreateDialog()
    local d = CreateFrame("Frame", "ReportAnnouncerShareDialog", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    d:SetSize(480, 230)
    d:SetPoint("CENTER", 0, 40)
    d:SetFrameStrata("DIALOG")
    d:EnableMouse(true)
    d:SetMovable(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", d.StartMoving)
    d:SetScript("OnDragStop", d.StopMovingOrSizing)
    ns.DialogBackdrop(d)

    d.title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.title:SetPoint("TOP", 0, -18)

    d.info = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.info:SetPoint("TOPLEFT", 24, -50)
    d.info:SetPoint("RIGHT", -24, 0)
    d.info:SetJustifyH("LEFT")

    d.edit = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    d.edit:SetPoint("TOPLEFT", 30, -92)
    d.edit:SetPoint("RIGHT", d, "RIGHT", -24, 0)
    d.edit:SetHeight(24)
    d.edit:SetAutoFocus(false)
    d.edit:SetMaxLetters(0)
    d.edit:SetMaxBytes(0)
    d.edit:SetScript("OnEscapePressed", function() d:Hide() end)

    d.status = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.status:SetPoint("TOPLEFT", d.edit, "BOTTOMLEFT", -6, -10)
    d.status:SetPoint("RIGHT", -24, 0)
    d.status:SetJustifyH("LEFT")

    d.check = CreateFrame("CheckButton", nil, d, "UICheckButtonTemplate")
    d.check:SetSize(24, 24)
    d.check:SetPoint("TOPLEFT", 22, -150)
    d.checkLabel = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.checkLabel:SetPoint("LEFT", d.check, "RIGHT", 2, 0)
    d.checkLabel:SetText("Include my details text")

    d.action = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.action:SetSize(100, 24)
    d.action:SetPoint("BOTTOMRIGHT", -126, 18)

    local close = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    close:SetSize(100, 24)
    close:SetPoint("BOTTOMRIGHT", -22, 18)
    close:SetText("Close")
    close:SetScript("OnClick", function() d:Hide() end)

    tinsert(UISpecialFrames, "ReportAnnouncerShareDialog")
    d:Hide()
    ns.ApplyTheme()
    return d
end

function ns.ShowExport()
    if InCombatLockdown() then
        ns.Print("sharing can't be opened during combat.")
        return
    end
    dialog = dialog or CreateDialog()
    local d = dialog
    d.mode = "export"
    d.title:SetText("Share my list")
    d.info:SetText("Copy this text (Ctrl+A, then Ctrl+C) and send it to someone. They paste it into Import.")
    d.check:Show(); d.checkLabel:Show()
    d.check:SetChecked(false)
    d.action:SetText("Select all")
    d.action:Enable()
    d.action:SetScript("OnClick", function()
        d.edit:SetFocus()
        d.edit:HighlightText()
    end)

    local function Build()
        local str, count = ns.ExportPersonal(d.check:GetChecked() and true or false)
        d.edit:SetScript("OnTextChanged", nil)
        d.edit:SetText(str)
        d.edit:SetCursorPosition(0)
        d.status:SetTextColor(1, 1, 1)
        d.status:SetText(count == 0 and "Your list is empty, there is nothing to share yet."
            or (count .. " report" .. (count == 1 and "" or "s") .. " in this string."))
        -- keep the string as is
        d.edit:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(str); self:HighlightText() end
        end)
    end
    d.check:SetScript("OnClick", Build)
    Build()
    d:Show()
    d.edit:SetFocus()
    d.edit:HighlightText()
end

function ns.ShowImport()
    if InCombatLockdown() then
        ns.Print("sharing can't be opened during combat.")
        return
    end
    dialog = dialog or CreateDialog()
    local d = dialog
    d.mode = "import"
    d.title:SetText("Import a list")
    d.info:SetText("Paste a string someone shared with you. It is added as a separate list and does not change your own reports or tooltips.")
    d.check:Hide(); d.checkLabel:Hide()
    d.edit:SetText("")
    d.status:SetText("")
    d.action:SetText("Import")
    d.action:Disable()

    local parsed
    d.edit:SetScript("OnTextChanged", function(self)
        local list, err = ns.ParseShareString(self:GetText())
        parsed = list
        if list then
            local n = #list.entries
            local extra = list.skipped > 0 and (" (" .. list.skipped .. " over the limit are skipped)") or ""
            d.status:SetTextColor(0.3, 1, 0.3)
            d.status:SetText("From " .. list.source .. ": " .. n .. " report" .. (n == 1 and "" or "s") .. extra)
            d.action:SetEnabled(n > 0)
        else
            d.status:SetTextColor(1, 0.3, 0.3)
            d.status:SetText(err or "")
            d.action:Disable()
        end
    end)
    d.action:SetScript("OnClick", function()
        if not parsed then return end
        local ok, how = ns.ImportList(parsed)
        if not ok then
            d.status:SetTextColor(1, 0.3, 0.3)
            d.status:SetText(how)
            return
        end
        ns.Print(how .. " list from " .. parsed.source .. " (" .. #parsed.entries .. " reports).")
        d:Hide()
        if ns.ShowTab then ns.ShowTab("imported") end
    end)
    d:Show()
    d.edit:SetFocus()
end

local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:SetScript("OnEvent", function()
    if dialog and dialog:IsShown() then dialog:Hide() end
end)
