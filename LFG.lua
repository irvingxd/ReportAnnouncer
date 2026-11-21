-- group finder: marks players you reported in the Looking For Group list,
-- adds them to the list's tooltip and warns you when you apply to their group.
-- the group finder API only gives names (no GUID), so this matches by name.
-- everything here only reads Blizzard's list; it never changes what it does.
local ADDON, ns = ...

local L = C_LFGList
local CACHE_SECS = 5
local TICK_SECS = 0.5
local MAX_DEPTH = 12

-- frames the group finder may live in, depending on the client
local ROOT_NAMES = { "LFGParentFrame", "LFGBrowseFrame", "LFGListFrame", "GroupFinderFrame", "PVEFrame" }

local function Enabled()
    return ns.InitDB().lfg ~= false
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function UsableName(n)
    return type(n) == "string" and n ~= "" and not Secret(n)
end

---------------------------------------------------------------------------
-- who is in a search result
---------------------------------------------------------------------------
-- everyone listed in one search result: { { name = , leader = }, ... }
local function Members(resultID)
    local out, seen = {}, {}
    local function add(name, leader)
        if UsableName(name) and not seen[name] then
            seen[name] = true
            out[#out + 1] = { name = name, leader = leader and true or false }
        end
    end
    if not L or type(resultID) ~= "number" then return out end

    local info
    if L.GetSearchResultInfo then
        local ok, res = pcall(L.GetSearchResultInfo, resultID)
        if ok and type(res) == "table" then info = res end
    end
    if L.GetSearchResultPlayerInfo then
        local count = info and tonumber(info.numMembers) or 40
        for i = 1, math.min(count, 40) do
            local ok, p = pcall(L.GetSearchResultPlayerInfo, resultID, i)
            if not ok or type(p) ~= "table" then break end
            add(p.name, p.isLeader)
        end
    end
    if #out == 0 and L.GetSearchResultLeaderInfo then
        local ok, p = pcall(L.GetSearchResultLeaderInfo, resultID)
        if ok and type(p) == "table" then add(p.name, true) end
    end
    if #out == 0 and info then add(info.leaderName, true) end
    return out
end

-- reported people in one result, cached for a few seconds:
-- { { name = , leader = , reports = { history entries } }, ... }
local hitCache = {}

local function Hits(resultID)
    local c = hitCache[resultID]
    local now = GetTime()
    if c and now - c.t < CACHE_SECS then return c.hits end
    local hits = {}
    for _, m in ipairs(Members(resultID)) do
        local found = ns.FindReports(nil, m.name)
        if #found > 0 then
            hits[#hits + 1] = { name = m.name, leader = m.leader, reports = found }
        end
    end
    hitCache[resultID] = { t = now, hits = hits }
    return hits
end

-- same, for a plain name shown somewhere in the list (fallback)
local nameCache = {}

local function NameReported(text)
    local c = nameCache[text]
    local now = GetTime()
    if c and now - c.t < CACHE_SECS then return c.reports end
    local found = ns.FindReports(nil, text)
    nameCache[text] = { t = now, reports = found }
    return found
end

local function LatestReport(reports)
    local best = reports[1]
    for _, e in ipairs(reports) do
        if (e.t or 0) > (best.t or 0) then best = e end
    end
    return best
end

---------------------------------------------------------------------------
-- marks on the list
---------------------------------------------------------------------------
local marks = {}    -- target (row frame or font string) -> our mark frame
local used = {}

local function RowMark(row)
    local m = marks[row]
    if m then return m end
    m = CreateFrame("Frame", nil, row)
    m:SetAllPoints(row)
    m:EnableMouse(false)
    m.tint = m:CreateTexture(nil, "BACKGROUND")
    m.tint:SetAllPoints()
    m.tint:SetColorTexture(1, 0.15, 0.15, 0.13)
    m.bar = m:CreateTexture(nil, "ARTWORK")
    m.bar:SetPoint("TOPLEFT", 0, 0)
    m.bar:SetPoint("BOTTOMLEFT", 0, 0)
    m.bar:SetWidth(3)
    m.bar:SetColorTexture(1, 0.25, 0.25, 0.9)
    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m.text:SetPoint("TOPRIGHT", -8, -6)
    m.text:SetJustifyH("RIGHT")
    m.text:SetTextColor(1, 0.35, 0.35)
    marks[row] = m
    return m
end

local function NameMark(fs)
    local m = marks[fs]
    if m then return m end
    local parent = fs:GetParent()
    m = CreateFrame("Frame", nil, parent)
    m:SetSize(80, 14)
    m:EnableMouse(false)
    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m.text:SetPoint("LEFT", 0, 0)
    m.text:SetTextColor(1, 0.35, 0.35)
    m.text:SetText("Reported")
    marks[fs] = m
    return m
end

local function ShowMark(target, m)
    local parent = m:GetParent()
    if parent and parent.GetFrameLevel then m:SetFrameLevel(parent:GetFrameLevel() + 10) end
    m:Show()
    used[target] = true
end

local function HideUnused()
    for target, m in pairs(marks) do
        if not used[target] then m:Hide() end
    end
end

local function HideAll()
    for _, m in pairs(marks) do m:Hide() end
end

local function StripText(text)
    if type(text) ~= "string" or Secret(text) then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = strtrim(text)
    if #text < 2 or #text > 40 or text:find("[%d:%(%)]") then return nil end
    return text
end

---------------------------------------------------------------------------
-- tooltip for a marked row
---------------------------------------------------------------------------
local ownTip
local TIP_NAMES = { "LFGBrowseSearchEntryTooltip", "LFGListSearchEntryTooltip" }

local function IsInside(frame, ancestor)
    local depth = 0
    while frame and depth < 20 do
        if frame == ancestor then return true end
        frame = frame.GetParent and frame:GetParent()
        depth = depth + 1
    end
    return false
end

local function AddHitLines(tt, hits)
    tt:AddLine(" ")
    tt:AddLine("|cffff5555Reported by you|r")
    for i = 1, math.min(#hits, 5) do
        local h = hits[i]
        local e = LatestReport(h.reports)
        local times = #h.reports > 1 and (" (" .. #h.reports .. "x)") or ""
        tt:AddLine(h.name .. (h.leader and " |cff999999(leader)|r" or "") .. times, 1, 1, 1)
        tt:AddLine("|cffffd100" .. ns.ReasonText(e) .. "|r", 1, 1, 1, true)
        tt:AddLine("|cff999999" .. (e.zone or "?") .. " - " .. ns.DateText(e) .. "|r", 1, 1, 1, true)
    end
end

local function ShowRowTip(row)
    if not Enabled() or not ns.InitDB().tooltip then return end
    local hits = Hits(row.resultID)
    if #hits == 0 then return end

    -- Blizzard's tooltip is GameTooltip: add to it
    if GameTooltip:IsShown() and IsInside(GameTooltip:GetOwner(), row) then
        AddHitLines(GameTooltip, hits)
        GameTooltip:Show()
        return
    end

    -- otherwise show our own tooltip under theirs (or under the row)
    if not ownTip then
        ownTip = CreateFrame("GameTooltip", "ReportAnnouncerLFGTooltip", UIParent, "GameTooltipTemplate")
    end
    local anchor
    for _, n in ipairs(TIP_NAMES) do
        local t = _G[n]
        if t and t.IsShown and t:IsShown() then anchor = t break end
    end
    ownTip:SetOwner(row, "ANCHOR_NONE")
    ownTip:ClearAllPoints()
    if anchor then
        ownTip:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    else
        ownTip:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -2)
    end
    ownTip:SetText("Report Announcer", 1, 0.82, 0)
    AddHitLines(ownTip, hits)
    ownTip:Show()
end

local hooked = {}

local function HookRow(row)
    if hooked[row] or not row.HookScript then return end
    hooked[row] = true
    row:HookScript("OnEnter", function(self)
        if type(self.resultID) ~= "number" then return end
        -- wait a frame so Blizzard's own tooltip is already up
        C_Timer.After(0, function()
            if self:IsMouseOver() then ShowRowTip(self) end
        end)
    end)
    row:HookScript("OnLeave", function()
        if ownTip then ownTip:Hide() end
    end)
end

---------------------------------------------------------------------------
-- finding the group finder window and its rows
---------------------------------------------------------------------------
local foundRoot -- found by searching when none of ROOT_NAMES is it

local function TopFrame(f)
    local depth = 0
    while f and f.GetParent and depth < 30 do
        local p = f:GetParent()
        if not p or p == UIParent then return f end
        f = p
        depth = depth + 1
    end
    return f
end

-- looks through all frames for a visible list row with a search result
local lastSearch = 0
local function DiscoverRoot()
    if not EnumerateFrames then return nil end
    local now = GetTime()
    if now - lastSearch < 2 then return nil end
    lastSearch = now
    local f = EnumerateFrames()
    while f do
        if not (f.IsForbidden and f:IsForbidden()) and type(rawget(f, "resultID")) == "number" and f:IsVisible() then
            return TopFrame(f)
        end
        f = EnumerateFrames(f)
    end
    return nil
end

local function ShownRoot()
    if foundRoot and foundRoot:IsVisible() then return foundRoot end
    for _, n in ipairs(ROOT_NAMES) do
        local f = _G[n]
        if type(f) == "table" and f.IsVisible and f:IsVisible() then return f end
    end
    return nil
end

local rows, names = {}, {}

local function Collect(frame, depth)
    if depth > MAX_DEPTH or (frame.IsForbidden and frame:IsForbidden()) then return end
    if type(rawget(frame, "resultID")) == "number" then
        rows[#rows + 1] = frame
        return -- a row: don't look inside it
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "FontString" and region:IsVisible() then
            names[#names + 1] = region
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsVisible() then Collect(child, depth + 1) end
    end
end

local function CollectRowText(row, depth, out)
    if depth > 4 then return end
    for _, region in ipairs({ row:GetRegions() }) do
        if region:GetObjectType() == "FontString" and region:IsVisible() then out[#out + 1] = region end
    end
    for _, child in ipairs({ row:GetChildren() }) do
        if child:IsVisible() then CollectRowText(child, depth + 1, out) end
    end
end

local function Scan(root)
    wipe(rows)
    wipe(names)
    wipe(used)
    Collect(root, 0)

    for _, row in ipairs(rows) do
        HookRow(row)
        local hits = Hits(row.resultID)
        if #hits > 0 then
            local m = RowMark(row)
            local solo = #hits == 1 and #Members(row.resultID) <= 1
            local label = solo and "Reported" or ("Reported: " .. hits[1].name)
            if #hits > 1 then label = label .. " +" .. (#hits - 1) end
            m.text:SetText(label)
            ShowMark(row, m)
        end
    end

    -- rows without a search result ID: mark the names we recognise
    if #rows == 0 then
        for _, fs in ipairs(names) do
            local text = StripText(fs:GetText())
            if text and #NameReported(text) > 0 then
                local m = NameMark(fs)
                m:ClearAllPoints()
                local w, fw = fs:GetStringWidth() or 0, fs:GetWidth() or 0
                if fw > 0 and fw < w then w = fw end
                m:SetPoint("LEFT", fs, "LEFT", w + 6, 0)
                ShowMark(fs, m)
            end
        end
    end
    HideUnused()
end

local function Tick()
    if not Enabled() then HideAll() return end
    local root = ShownRoot()
    if not root then HideAll() return end
    local ok, err = pcall(Scan, root)
    if not ok then
        HideAll()
        if not ns.lfgErrorShown then
            ns.lfgErrorShown = true
            ns.Print("group finder marks stopped working: " .. tostring(err))
        end
    end
end

---------------------------------------------------------------------------
-- chat notice when a search shows someone you reported, and on apply
---------------------------------------------------------------------------
local lastNotice = ""

local function AllResults()
    if not L or not L.GetSearchResults then return {} end
    local ok, a, b = pcall(L.GetSearchResults)
    if not ok then return {} end
    local list = type(b) == "table" and b or (type(a) == "table" and a) or nil
    return list or {}
end

local function GroupLabel(resultID, hit)
    if hit.leader then return hit.name end
    for _, m in ipairs(Members(resultID)) do
        if m.leader then return hit.name .. " (in " .. m.name .. "'s group)" end
    end
    return hit.name
end

local function NoticeSearch()
    if not Enabled() then return end
    local parts, seen = {}, {}
    for _, id in ipairs(AllResults()) do
        if type(id) == "number" then
            for _, h in ipairs(Hits(id)) do
                if not seen[h.name] then
                    seen[h.name] = true
                    parts[#parts + 1] = GroupLabel(id, h)
                end
            end
        end
    end
    table.sort(parts)
    local text = table.concat(parts, ", ")
    if text ~= "" and text ~= lastNotice then
        ns.Print("|cffff5555in the group finder:|r " .. text)
    end
    lastNotice = text
end

local function OnApply(resultID)
    if not Enabled() or type(resultID) ~= "number" then return end
    local hits = Hits(resultID)
    if #hits == 0 then return end
    local who = {}
    for _, h in ipairs(hits) do who[#who + 1] = h.name end
    local text = "You applied to a group with " .. table.concat(who, ", ") .. ", who you reported."
    ns.Print("|cffff5555" .. text .. "|r You can cancel the application in the group finder.")
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.3, 0.3) end
end

---------------------------------------------------------------------------
-- /reportannouncer lfg: what the addon can see
---------------------------------------------------------------------------
function ns.LFGDebug()
    local P = ns.Print
    P("group finder: " .. (Enabled() and "marks on" or "marks off (Options tab)") .. ".")
    if not L then P("no C_LFGList on this client.") return end
    P("functions: info " .. tostring(L.GetSearchResultInfo ~= nil)
        .. ", players " .. tostring(L.GetSearchResultPlayerInfo ~= nil)
        .. ", leader " .. tostring(L.GetSearchResultLeaderInfo ~= nil)
        .. ", apply " .. tostring(L.ApplyToGroup ~= nil) .. ".")
    local results = AllResults()
    local total = 0
    for _, id in ipairs(results) do total = total + #Hits(id) end
    P(#results .. " search result(s), " .. total .. " reported player(s) in them.")
    if not ShownRoot() then foundRoot = DiscoverRoot() or foundRoot end
    local root = ShownRoot()
    if not root then P("the group finder window isn't open (or wasn't found).") return end
    P("window: " .. tostring(root:GetName() or "(no name)") .. ".")
    wipe(rows)
    wipe(names)
    Collect(root, 0)
    P(#rows .. " list row(s) with a result ID, " .. #names .. " other text line(s).")
end

---------------------------------------------------------------------------
-- startup
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local function TryRegister(name) pcall(ev.RegisterEvent, ev, name) end
TryRegister("PLAYER_LOGIN")
TryRegister("LFG_LIST_SEARCH_RESULTS_RECEIVED")
TryRegister("LFG_LIST_SEARCH_RESULT_UPDATED")

ev:SetScript("OnEvent", function(_, event, id)
    if event == "PLAYER_LOGIN" then
        if L and L.ApplyToGroup then
            pcall(hooksecurefunc, L, "ApplyToGroup", function(resultID) pcall(OnApply, resultID) end)
        end
        C_Timer.NewTicker(TICK_SECS, Tick)
        return
    end
    if event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        if id then hitCache[id] = nil end
        return
    end
    -- new search results
    wipe(hitCache)
    if not ShownRoot() then foundRoot = DiscoverRoot() or foundRoot end
    C_Timer.After(0.2, function() pcall(NoticeSearch) end)
end)
