-- ReportAnnouncer 1.5
-- When you press "Report" in Blizzard's report dialog:
--   * announces in chat: <name> was reported for <category>, the reason: <reasons>. Details: <text>
--     (RAID if you're in a raid, PARTY if in a party, otherwise SAY)
--   * saves it to a history (name, reasons, details, zone, date) shown by the minimap button
--   * shows a "Reported by you" summary in that player's mouseover tooltip (can be turned off)
-- Sent on the button's PreClick so the click's "hardware event" is still valid
-- (Blizzard blocks addon /say otherwise).
--
-- Commands: /reportannouncer            toggle chat announcing on/off
--           /reportannouncer history     open the history window
--           /reportannouncer minimap     show/hide the minimap button
--           /reportannouncer test        send a sample message
--           /reportannouncer options     open the options (message template)

local ADDON, ns = ...
local MAX_LEN = 250
local MAX_HISTORY = 500

local function Print(msg)
    print("|cff33ff99ReportAnnouncer:|r " .. msg)
end
ns.Print = Print

---------------------------------------------------------------------------
-- Message template
--   {name} {category} {reasons} {details} {zone} {date}
--   [ ... ]  optional block: left out when a variable inside it is empty
---------------------------------------------------------------------------
ns.DEFAULT_TEMPLATE = "{name} was reported[ for {category}][, the reason: {reasons}].[ Details: {details}]"
ns.TEMPLATE_VARS = { name = true, category = true, reasons = true, details = true, zone = true, date = true }
local MAX_TEMPLATE = 220

-- Replace {vars} in text. Second result is true if a variable in it was empty.
local function Fill(text, vars)
    local empty = false
    local out = text:gsub("{(%a+)}", function(key)
        local value = vars[key]
        if value == nil then return nil end -- unknown: leave as typed
        if value == "" then empty = true end
        return value
    end)
    return out, empty
end

function ns.RenderTemplate(tpl, vars)
    local out, pos = {}, 1
    while true do
        local s, e, inner = tpl:find("%[([^%[%]]*)%]", pos)
        if not s then
            out[#out + 1] = (Fill(tpl:sub(pos), vars))
            break
        end
        out[#out + 1] = (Fill(tpl:sub(pos, s - 1), vars))
        local text, empty = Fill(inner, vars)
        if not empty then out[#out + 1] = text end
        pos = e + 1
    end
    return strtrim(table.concat(out))
end

function ns.SAMPLE_VARS()
    return {
        name = "Test Player", category = "Gameplay Sabotage", reasons = "AFK/Non-Participation",
        details = "test", zone = "Silverpine Forest", date = date("%Y-%m-%d"),
    }
end

-- true, or false + the reason it can't be used
function ns.ValidateTemplate(tpl)
    if type(tpl) ~= "string" or strtrim(tpl) == "" then return false, "The message can't be empty." end
    if #tpl > MAX_TEMPLATE then return false, "Too long (max " .. MAX_TEMPLATE .. " characters)." end
    local hasName = false
    for key in tpl:gmatch("{(%a+)}") do
        if not ns.TEMPLATE_VARS[key] then return false, "Unknown variable {" .. key .. "}." end
        if key == "name" then hasName = true end
    end
    if not hasName then return false, "{name} is required, so everyone knows who was reported." end
    local rest = tpl:gsub("%[[^%[%]]*%]", "")
    if rest:find("[%[%]]") then return false, "Unbalanced or nested [ ] optional block." end
    return true
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local function InitDB()
    ReportAnnouncerDB = ReportAnnouncerDB or {}
    local db = ReportAnnouncerDB
    db.history = db.history or {}
    db.imports = db.imports or {} -- lists shared by other people, kept apart from db.history
    if db.tooltip == nil then db.tooltip = true end
    if db.callout == nil then db.callout = false end -- opt-in
    if not ns.ValidateTemplate(db.template) then db.template = ns.DEFAULT_TEMPLATE end
    db.minimap = db.minimap or { angle = 215 }
    db.announce = db.announce or { say = true, party = true, raid = true }
    if db.disabled then -- migrate the old single on/off switch
        db.announce.say, db.announce.party, db.announce.raid = false, false, false
        db.disabled = nil
    end
    return db
end
ns.InitDB = InitDB

-- Is announcing allowed in this chat channel? (instance chat follows "party")
local function ChannelAllowed(channel)
    local a = InitDB().announce
    if channel == "RAID" then return a.raid end
    if channel == "PARTY" or channel == "INSTANCE_CHAT" then return a.party end
    return a.say
end

local function ShortName(n)
    return n and n:match("^([^%-]+)") or n
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- Names can differ between the report dialog ("Pepe Peepo") and unit APIs ("Pepe"),
-- so: ignore the realm, and let a name match another that starts with it + a space.
local function NamesMatch(a, b)
    a, b = ShortName(a), ShortName(b)
    if not a or not b or a == "" or b == "" then return false end
    if a == b then return true end
    return a:sub(1, #b + 1) == b .. " " or b:sub(1, #a + 1) == a .. " "
end

local function ZoneText()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local sub = GetSubZoneText and GetSubZoneText() or ""
    if sub ~= "" and sub ~= zone then
        return zone ~= "" and (sub .. ", " .. zone) or sub
    end
    return zone ~= "" and zone or "Unknown"
end

function ns.ReasonText(e)
    local text = e.category or "Report"
    if e.reasons and e.reasons ~= "" then text = text .. ": " .. e.reasons end
    return text
end

function ns.DateText(e)
    return date("%Y-%m-%d %H:%M", e.t or 0)
end

-- All history entries for one player (match by GUID when both have one, else by name).
function ns.FindReports(guid, name)
    local found = {}
    for _, e in ipairs(InitDB().history) do
        local match
        if guid and e.guid then
            match = (e.guid == guid) -- both have an ID: only the ID counts, never the name
        else
            match = NamesMatch(name, e.name) -- old entry without an ID: best-effort name match
        end
        if match then found[#found + 1] = e end
    end
    return found
end

-- Finds a player's GUID by name among the units we can currently see.
function ns.FindGuidByName(name)
    local units = { "target", "mouseover", "focus", "targettarget", "focustarget" }
    for i = 1, 4 do units[#units + 1] = "party" .. i end
    for i = 1, 40 do units[#units + 1] = "raid" .. i end
    for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
    for _, u in ipairs(units) do
        if UnitExists(u) and UnitIsPlayer(u) then
            local n = UnitName(u)
            if n and not IsSecret(n) and NamesMatch(n, name) then
                local g = UnitGUID(u)
                if g and not IsSecret(g) then return g end
            end
        end
    end
end

-- Saves a newly learned GUID on name-matched entries that had none.
function ns.LearnGuid(entries, guid)
    for _, e in ipairs(entries) do
        if not e.guid then e.guid = guid end
    end
end

function ns.SetPersonTip(entry, value)
    for _, e in ipairs(ns.FindReports(entry.guid, entry.name)) do
        e.tip = value and true or false
    end
    entry.tip = value and true or false
end

function ns.Record(entry)
    local db = InitDB()
    entry.t = time()
    entry.zone = ZoneText()
    local previous = ns.FindReports(entry.guid, entry.name)[1]
    entry.tip = not (previous and previous.tip == false)
    table.insert(db.history, 1, entry)
    while #db.history > MAX_HISTORY do table.remove(db.history) end
    if ns.RefreshHistory then ns.RefreshHistory() end
end

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------
local function PickChannel()
    local home = LE_PARTY_CATEGORY_HOME or 1
    local instance = LE_PARTY_CATEGORY_INSTANCE or 2
    if IsInRaid and IsInRaid(home) then return "RAID" end
    if IsInGroup and IsInGroup(home) then return "PARTY" end
    if IsInGroup and IsInGroup(instance) then return "INSTANCE_CHAT" end
    return "SAY"
end

-- Is this player (GUID if known, else name) one of the people in my party/raid?
local function IsInMyGroup(guid, name)
    local units = {}
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do units[#units + 1] = "raid" .. i end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local ug = UnitGUID(unit)
            if guid and ug and not IsSecret(ug) then
                if ug == guid then return true end
            else
                local un = UnitName(unit)
                if un and not IsSecret(un) and NamesMatch(name, un) then return true end
            end
        end
    end
    return false
end

local function Send(text, channel)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    while #text > MAX_LEN do
        local cut = text:sub(1, MAX_LEN):match("^.*()%s") or MAX_LEN
        send(text:sub(1, cut - 1), channel)
        text = text:sub(cut + 1)
    end
    if #text > 0 then send(text, channel) end
end

---------------------------------------------------------------------------
-- Reading Blizzard's report dialog
---------------------------------------------------------------------------
local function MajorName(major)
    if not major or not (C_ReportSystem and C_ReportSystem.GetMajorCategoryString) then return nil end
    local key = C_ReportSystem.GetMajorCategoryString(major)
    return key and _G[key] or nil
end

local function MinorNames(flags)
    local list = {}
    if not flags or flags == 0 or not Enum or not Enum.ReportMinorCategory
        or not (C_ReportSystem and C_ReportSystem.GetMinorCategoryString) then
        return list
    end
    for _, value in pairs(Enum.ReportMinorCategory) do
        if type(value) == "number" and value > 0 and bit.band(flags, value) ~= 0 then
            local key = C_ReportSystem.GetMinorCategoryString(value)
            local name = key and _G[key]
            if name then list[#list + 1] = { value = value, name = name } end
        end
    end
    table.sort(list, function(a, b) return a.value < b.value end)
    for i, entry in ipairs(list) do list[i] = entry.name end
    return list
end

local function Announce()
    local f = ReportFrame
    if not f then return end

    local name = f.playerName
    if (not name or name == "") and f.reportPlayerLocation and C_PlayerInfo and C_PlayerInfo.GetName then
        name = C_PlayerInfo.GetName(f.reportPlayerLocation)
    end
    if not name or name == "" then
        Print("couldn't find the reported player's name.")
        return
    end

    local flags = f.minorCategoryFlags and f.minorCategoryFlags.GetFlags and f.minorCategoryFlags:GetFlags()
    local comment = f.Comment and f.Comment.EditBox and f.Comment.EditBox:GetText()
    if comment then comment = strtrim(comment) end

    local category = MajorName(f.selectedMajorType)
    local reasons = MinorNames(flags)

    -- save to history (always, even if chat announcing is switched off)
    local okGuid, guid = pcall(function()
        local loc = f.reportPlayerLocation
        return loc and loc.GetGUID and loc:GetGUID() or nil
    end)
    if not okGuid then guid = nil end
    if not guid then -- the dialog gave no ID: look for the player among units we can see
        local okFind, found = pcall(ns.FindGuidByName, name)
        if okFind then guid = found end
    end
    okGuid = guid ~= nil
    pcall(ns.Record, {
        name = name,
        guid = okGuid and guid or nil,
        category = category,
        reasons = table.concat(reasons, ", "),
        comment = (comment and comment ~= "") and comment or nil,
    })

    -- Group chat is only for reports of someone in the group; anyone else goes to /say
    local channel = PickChannel()
    if channel ~= "SAY" then
        local okIn, inGroup = pcall(IsInMyGroup, okGuid and guid or nil, name)
        if okIn and not inGroup then channel = "SAY" end
    end
    if not ChannelAllowed(channel) then return end

    local msg = ns.RenderTemplate(InitDB().template, {
        name = name,
        category = category or "",
        reasons = table.concat(reasons, ", "),
        details = comment or "",
        zone = ZoneText(),
        date = date("%Y-%m-%d"),
    })

    local ok, err = pcall(Send, msg, channel)
    if not ok then
        Print("couldn't send to chat (" .. tostring(err) .. "): " .. msg)
    end
end

local hooked = false
local function TryHook()
    if hooked then return true end
    if ReportFrame and ReportFrame.ReportButton then
        ReportFrame.ReportButton:HookScript("PreClick", function(btn)
            if btn:IsEnabled() then Announce() end
        end)
        hooked = true
    end
    return hooked
end

---------------------------------------------------------------------------
-- Mouseover tooltip
---------------------------------------------------------------------------
local function AddReportLines(tt, guid, name)
    if not InitDB().tooltip then return end

    local shown = ns.FindReports(guid, name)
    if #shown == 0 then return end
    if guid then ns.LearnGuid(shown, guid) end

    tt:AddLine(" ")
    tt:AddLine("|cffff5555Reported by you|r" .. (#shown > 1 and (" (" .. #shown .. "x)") or ""))
    for i = 1, math.min(#shown, 3) do
        local e = shown[i]
        tt:AddLine("|cffffd100" .. ns.ReasonText(e) .. "|r", 1, 1, 1, true)
        tt:AddLine("|cff999999" .. (e.zone or "?") .. " - " .. ns.DateText(e) .. "|r", 1, 1, 1, true)
    end
    if #shown > 3 then
        tt:AddLine("|cff999999+" .. (#shown - 3) .. " older (see history)|r")
    end
    tt:Show() -- resize to fit the new lines
end

local function OnUnitTooltip(tt, dataGuid)
    if tt ~= GameTooltip then return end
    local ok, name, unit = pcall(tt.GetUnit, tt)
    if not ok then name, unit = nil, nil end

    local guid = dataGuid
    if not guid and unit then guid = UnitGUID(unit) end
    if type(guid) ~= "string" or IsSecret(guid) then return end
    if not guid:find("^Player%-") then return end
    if IsSecret(name) then name = nil end

    AddReportLines(tt, guid, name)
end

local function HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt, data)
            OnUnitTooltip(tt, data and data.guid)
        end)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", function(tt) OnUnitTooltip(tt, nil) end)
    end
end

---------------------------------------------------------------------------
-- Call out reported players who are in your group (opt-in)
---------------------------------------------------------------------------
local calledOut = {}      -- GUIDs already announced during this group
local checkPending = false

local function BuildCallout(name, e, channel)
    local category = e.category or "misconduct"
    local reasons = (e.reasons and e.reasons ~= "") and e.reasons or nil
    local msg
    if channel == "RAID" then
        msg = "Raid notice: " .. name .. " was previously reported by me for " .. category
            .. (reasons and (": " .. reasons) or "") .. "."
    elseif math.random(2) == 1 then
        msg = "Heads up: " .. name .. " was previously reported by me for " .. category
            .. (reasons and (" (" .. reasons .. ")") or "") .. "."
    else
        msg = "FYI, I reported " .. name .. " before for " .. category
            .. (reasons and (": " .. reasons) or "") .. ". Let's keep an eye out."
    end
    if e.comment then msg = msg .. " Details: " .. e.comment end
    return msg
end

local function CheckGroup(verbose)
    checkPending = false
    verbose = (verbose == true)
    local function say(text) if verbose then Print("check: " .. text) end end

    local db = InitDB()
    if not IsInGroup() then
        wipe(calledOut)
        say("you are not in a group.")
        return
    end
    if not db.callout then
        say("the callout checkbox is off.")
        return
    end

    local channel = PickChannel()
    if channel == "SAY" or not ChannelAllowed(channel) then
        say("channel " .. channel .. " is switched off (or not a group channel).")
        return
    end

    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    say("channel " .. channel .. ", looking at " .. #units .. " other member(s).")

    for _, unit in ipairs(units) do
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local guid, name = UnitGUID(unit), UnitName(unit)
            if not guid or not name or IsSecret(guid) or IsSecret(name) then
                say(unit .. ": no name/GUID available yet.")
            elseif calledOut[guid] then
                say(name .. ": already called out in this group.")
            else
                local reports = ns.FindReports(guid, name)
                say(name .. ": " .. #reports .. " matching report(s) in history.")
                if #reports > 0 then
                    calledOut[guid] = true
                    ns.LearnGuid(reports, guid) -- remember the ID for exact matching next time
                    local shownName = reports[1].name or name
                    local ok, err = pcall(Send, BuildCallout(shownName, reports[1], channel), channel)
                    if not ok then Print("couldn't send callout (" .. tostring(err) .. ")") end
                end
            end
        else
            say(unit .. ": doesn't exist.")
        end
    end
end

local function ScheduleGroupCheck()
    if checkPending then return end
    checkPending = true
    C_Timer.After(1.5, function() CheckGroup(false) end) -- let the roster finish loading
end

-- /reportannouncer check : run the group check now and explain what it finds
function ns.CheckGroupNow()
    wipe(calledOut)
    CheckGroup(true)
end

---------------------------------------------------------------------------
-- Startup + slash command
---------------------------------------------------------------------------
local tooltipHooked = false

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event, addon)
    if event == "GROUP_ROSTER_UPDATE" then
        ScheduleGroupCheck()
        return
    end
    if event == "ADDON_LOADED" and addon ~= ADDON then
        TryHook()
        return
    end
    InitDB()
    local ok = TryHook()
    if not tooltipHooked then
        tooltipHooked = true
        local hookOk, err = pcall(HookTooltips)
        if not hookOk then Print("tooltip hook failed: " .. tostring(err)) end
    end
    if event == "PLAYER_LOGIN" then
        if ns.CreateMinimapButton then ns.CreateMinimapButton() end
        Print(ok and "loaded. Click the minimap button for your report history (/reportannouncer for options)."
                  or "loaded, but could not find the report dialog to hook.")
    end
end)

SLASH_REPORTANNOUNCER1 = "/reportannouncer"
SLASH_REPORTANNOUNCER2 = "/reportannounce"
SlashCmdList["REPORTANNOUNCER"] = function(arg)
    local db = InitDB()
    arg = strlower(strtrim(arg or ""))
    if arg == "test" then
        local ch = PickChannel()
        Print("sending a test message to " .. ch .. ".")
        Send(ns.RenderTemplate(db.template, ns.SAMPLE_VARS()), ch)
    elseif arg == "options" or arg == "config" or arg == "template" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif arg == "history" or arg == "show" or arg == "list" then
        if ns.ToggleHistory then ns.ToggleHistory() end
    elseif arg == "stats" or arg == "statistics" then
        if ns.ShowTab then ns.ShowTab("stats") end
    elseif arg == "export" or arg == "share" then
        if ns.ShowExport then ns.ShowExport() end
    elseif arg == "import" then
        if ns.ShowImport then ns.ShowImport() end
    elseif arg == "check" then
        ns.CheckGroupNow()
    elseif arg == "minimap" then
        db.minimap.hide = not db.minimap.hide
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        Print("minimap button " .. (db.minimap.hide and "hidden." or "shown."))
    else
        local a = db.announce
        local on = not (a.say or a.party or a.raid) -- all off -> turn all on, otherwise all off
        a.say, a.party, a.raid = on, on, on
        if ns.RefreshHistory then ns.RefreshHistory() end
        Print("chat announcing " .. (on and "enabled." or "disabled (history is still recorded)."))
    end
end
