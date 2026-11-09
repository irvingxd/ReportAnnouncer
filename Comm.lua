-- opt-in community tally. only numbers (how many reports you have, and how often
-- each category / reason / zone, no names) go to addon users in your guild, group,
-- a channel and friends. counts are self reported, can't be checked.
--
-- kept quiet on purpose:
-- * we only say hello at login, when someone joins the group, and when our own
--   numbers changed (checked every 30s, at most once per 2 minutes)
-- * everything leaves through a slow queue, one message every 2 seconds
-- * only new people get an answer, and in a big guild only a few answer, late
local ADDON, ns = ...

local PREFIX = "RepAnn"
local EXPIRE = 30 * 86400 -- drop peers after 30 days
local MAX_PEERS = 500
local MAX_COUNT = 100000
local CHANGE_GAP = 120 -- numbers changed: wait at least this long between broadcasts
local MAX_FRIENDS = 60
local REPLY_TARGET = 8 -- in guild / channels about this many people answer a new hello
local GROUP_BUDGET = 70 -- characters for each of categories, reasons, zones

local Register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
local SendMsg = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage

local lastSent, lastGroup, lastSig = 0, 0, nil
local GROUP_GAP = 15 -- group changes can send again fairly quickly
local SEND_INTERVAL = 2 -- seconds between two outgoing messages
local MAX_QUEUE = 60

local function Enabled() return ns.InitDB().shareCount end

local function OwnCount() return #ns.InitDB().history end

-- random id so one person isn't counted twice
local function OwnId()
    local db = ns.InitDB()
    if not db.installId then
        db.installId = string.format("%06x%06x", math.random(0, 0xFFFFFF), math.random(0, 0xFFFFFF))
    end
    return db.installId
end

local function Message(kind)
    return kind .. "1:" .. OwnCount() .. ":" .. OwnId()
end

-- two messages: the count, and how often each category / reason / zone was
-- reported (top ones only, a message is limited to 255 bytes)
-- S2:<id>:c=Name=5;Name=2|r=Name=3|z=Name=4
local KINDS = { "c", "r", "z" }
local function Messages(kind)
    local msgs = { Message(kind) }
    local counts = { ns.OwnCounts() }
    local groups = {}
    for i, k in ipairs(KINDS) do
        local parts, len = {}, 0
        for _, item in ipairs(ns.SortedTop(counts[i], 12)) do
            local name = (item.label:gsub("[;=:|,%c]", "")):sub(1, 40)
            local piece = name .. "=" .. item.n
            if name ~= "" and len + #piece + 1 <= GROUP_BUDGET then
                parts[#parts + 1] = piece
                len = len + #piece + 1
            end
        end
        if #parts > 0 then groups[#groups + 1] = k .. "=" .. table.concat(parts, ";") end
    end
    if #groups > 0 then msgs[#msgs + 1] = "S2:" .. OwnId() .. ":" .. table.concat(groups, "|") end
    return msgs
end

-- debug log (/ra debug). keeps the last lines, saved with the other settings.
-- counters always run, the log only when it is switched on
local sentCount, recvCount = 0, 0
local LOG_MAX = 300

local function Log(line)
    local db = ns.InitDB()
    if not db.debug then return end
    local log = db.debugLog
    if not log then log = {}; db.debugLog = log end
    log[#log + 1] = date("%H:%M:%S") .. " " .. line
    if #log > LOG_MAX then table.remove(log, 1) end
end

-- nothing goes out right away: messages wait in a line and one is sent every
-- SEND_INTERVAL seconds, so there is never a burst
local queue = {}

local function Enqueue(item)
    for _, q in ipairs(queue) do
        if q.t == item.t and q.ch == item.ch and q.tg == item.tg and q.bn == item.bn then return end
    end
    if #queue >= MAX_QUEUE then return end
    queue[#queue + 1] = item
end

-- text can be one message or a list of them
local function Send(text, channel, target)
    if not SendMsg then return end
    for _, t in ipairs(type(text) == "table" and text or { text }) do
        Enqueue({ t = t, ch = channel, tg = target })
    end
end

local function SendBN(text, gameAccountID)
    if not (BNSendGameData and gameAccountID) then return end
    for _, t in ipairs(type(text) == "table" and text or { text }) do
        Enqueue({ t = t, bn = gameAccountID })
    end
end

local function SendNext()
    local item = table.remove(queue, 1)
    if not item then return end
    sentCount = sentCount + 1
    if item.bn then
        Log("send BNET " .. #item.t .. "b " .. item.t:sub(1, 40))
        pcall(BNSendGameData, item.bn, PREFIX, item.t)
    else
        Log("send " .. tostring(item.ch) .. (item.tg and (" " .. tostring(item.tg)) or "")
            .. " " .. #item.t .. "b " .. item.t:sub(1, 40))
        pcall(SendMsg, PREFIX, item.t, item.ch, item.tg)
    end
end

local waited = SEND_INTERVAL
local pump = CreateFrame("Frame")
pump:SetScript("OnUpdate", function(_, dt)
    waited = math.min(waited + dt, SEND_INTERVAL)
    if #queue == 0 then return end
    if not ns.InitDB().shareCount then queue = {}; return end -- switched off, drop the rest
    if waited >= SEND_INTERVAL then
        waited = 0
        SendNext()
    end
end)

-- all the debug info as one text, to copy and paste
function ns.DebugText(n)
    local db = ns.InitDB()
    local log = db.debugLog or {}
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ver = meta and meta(ADDON, "Version") or "?"
    local lines = {
        "ReportAnnouncer " .. tostring(ver) .. " debug, " .. date("%Y-%m-%d %H:%M:%S"),
        "tally " .. (db.shareCount and "on" or "off") .. ", log " .. (db.debug and "on" or "off")
            .. ", sent " .. sentCount .. ", received " .. recvCount .. ", waiting " .. #queue,
        "guild " .. ((IsInGuild and IsInGuild()) and "yes" or "no")
            .. ", group " .. ((IsInGroup and IsInGroup()) and (GetNumGroupMembers and GetNumGroupMembers() or "?") or "no")
            .. ", peers " .. (function() local c = 0 for _ in pairs(db.peers or {}) do c = c + 1 end return c end)(),
        "last " .. math.min(n, #log) .. " of " .. #log .. " log lines:",
    }
    for i = math.max(1, #log - n + 1), #log do lines[#lines + 1] = log[i] end
    return table.concat(lines, "\n")
end

-- a window with the text, Ctrl+A then Ctrl+C
local debugWin
function ns.ShowDebugCopy()
    if not debugWin then
        local d = CreateFrame("Frame", "ReportAnnouncerDebugDialog", UIParent,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        d:SetSize(560, 360)
        d:SetPoint("CENTER")
        d:SetFrameStrata("DIALOG")
        d:EnableMouse(true)
        d:SetMovable(true)
        d:RegisterForDrag("LeftButton")
        d:SetScript("OnDragStart", d.StartMoving)
        d:SetScript("OnDragStop", d.StopMovingOrSizing)
        if ns.DialogBackdrop then ns.DialogBackdrop(d) end

        d.title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        d.title:SetPoint("TOP", 0, -16)
        d.title:SetText("Debug info")

        local scroll = CreateFrame("ScrollFrame", "ReportAnnouncerDebugScroll", d, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 22, -46)
        scroll:SetPoint("BOTTOMRIGHT", -40, 52)
        d.edit = CreateFrame("EditBox", nil, scroll)
        d.edit:SetMultiLine(true)
        d.edit:SetFontObject(ChatFontNormal)
        d.edit:SetWidth(490)
        d.edit:SetAutoFocus(false)
        d.edit:SetMaxLetters(0)
        d.edit:SetScript("OnEscapePressed", function() d:Hide() end)
        scroll:SetScrollChild(d.edit)

        local sel = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
        sel:SetSize(100, 24)
        sel:SetPoint("BOTTOMRIGHT", -126, 18)
        sel:SetText("Select all")
        sel:SetScript("OnClick", function() d.edit:SetFocus(); d.edit:HighlightText() end)
        local close = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
        close:SetSize(100, 24)
        close:SetPoint("BOTTOMRIGHT", -22, 18)
        close:SetText("Close")
        close:SetScript("OnClick", function() d:Hide() end)

        tinsert(UISpecialFrames, "ReportAnnouncerDebugDialog")
        debugWin = d
        if ns.ApplyTheme then ns.ApplyTheme() end
    end
    debugWin.edit:SetText(ns.DebugText(100))
    debugWin:Show()
    debugWin.edit:SetFocus()
    debugWin.edit:HighlightText()
end

-- /ra debug [on|off|show [n]|copy|clear|status]
function ns.DebugCommand(arg)
    local db = ns.InitDB()
    arg = strlower(strtrim(arg or ""))
    if arg == "off" then
        db.debug = nil
        ns.Print("debug log off.")
    elseif arg == "clear" then
        db.debugLog = nil
        ns.Print("debug log cleared.")
    elseif arg:match("^show") or arg:match("^log") then
        local log = db.debugLog or {}
        local n = tonumber(arg:match("(%d+)")) or 25
        ns.Print("last " .. math.min(n, #log) .. " of " .. #log .. " lines:")
        for i = math.max(1, #log - n + 1), #log do print(log[i]) end
    elseif arg == "copy" then
        ns.ShowDebugCopy()
    elseif arg == "status" then
        ns.Print("sent " .. sentCount .. ", received " .. recvCount .. ", waiting to send " .. #queue .. " (addon messages, this session). log is "
            .. (db.debug and "on" or "off") .. ", " .. #(db.debugLog or {}) .. " lines.")
    else
        db.debug = true
        ns.Print("debug log on. /ra debug copy  |  show  |  status  |  clear  |  off")
    end
end

-- only friends we already know have the addon (they answered us before).
-- asking everyone on the friends list would be a lot of useless whispers.
-- to find a new friend: /reportannouncer hello <name>
local function BaseName(name)
    return strlower((name:match("^[^-]+")) or name)
end

local function EachFriend(fnWoW, fnBN)
    local names, bns = {}, {}
    for _, p in pairs(ns.InitDB().peers) do
        if p.w then names[BaseName(p.w)] = true end
        if p.bn then bns[p.bn] = true end
    end
    if next(names) == nil and next(bns) == nil then return end
    if C_FriendList and C_FriendList.GetNumFriends then
        local n = math.min(C_FriendList.GetNumFriends() or 0, MAX_FRIENDS)
        for i = 1, n do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected and info.name and names[BaseName(info.name)] then fnWoW(info.name) end
        end
    end
    if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
        local n = math.min((BNGetNumFriends()) or 0, MAX_FRIENDS)
        for i = 1, n do
            local acc = C_BattleNet.GetFriendAccountInfo(i)
            local g = acc and acc.gameAccountInfo
            if g and g.isOnline and g.clientProgram == "WoW" and g.gameAccountID and bns[g.gameAccountID] then
                fnBN(g.gameAccountID)
            end
        end
    end
end

-- someone joined or left: say hello to the group again
local function BroadcastGroup()
    if not Enabled() or not SendMsg then return end
    local now = time()
    if now - lastGroup < GROUP_GAP then return end
    lastGroup = now
    local msg = Messages("H")
    if IsInRaid and IsInRaid() then
        Send(msg, "RAID")
    elseif IsInGroup and IsInGroup() then
        Send(msg, (IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) and "INSTANCE_CHAT") or "PARTY")
    end
end

-- tell guild, group, channel and friends we're here (login, or our numbers changed)
function ns.BroadcastCount()
    if not Enabled() or not SendMsg then return end
    lastSent = time()
    local msg = Messages("H")
    lastSig = table.concat(msg, "\n")

    if IsInGuild and IsInGuild() then Send(msg, "GUILD") end
    if IsInRaid and IsInRaid() then
        Send(msg, "RAID")
    elseif IsInGroup and IsInGroup() then
        Send(msg, (IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) and "INSTANCE_CHAT") or "PARTY")
    end

    local chan = ns.InitDB().shareChannel
    if chan and chan ~= "" and GetChannelName then
        local id = GetChannelName(chan)
        if id and id > 0 then Send(msg, "CHANNEL", id) end
    end

    EachFriend(function(name) Send(msg, "WHISPER", name) end,
               function(gid) SendBN(msg, gid) end)
end

-- /reportannouncer hello <name>: ask one player if they have the addon
function ns.SayHello(name)
    name = strtrim(name or "")
    if name == "" then
        ns.Print("usage: /reportannouncer hello <player name>")
        return
    end
    if not Enabled() then
        ns.Print("turn the community tally on first (Options).")
        return
    end
    Send(Messages("H"), "WHISPER", name)
    ns.Print("hello sent to " .. name .. ". if they have the addon, they answer in a few seconds.")
end

-- did our numbers change since the last broadcast? (called every 30 seconds)
local function CheckChanged()
    if not Enabled() or not SendMsg then return end
    if table.concat(Messages("H"), "\n") == lastSig then return end
    if time() - lastSent < CHANGE_GAP then return end -- try again next time
    ns.BroadcastCount()
end

local function Prune(peers)
    local now, n = time(), 0
    for id, p in pairs(peers) do
        if now - (p.t or 0) > EXPIRE then peers[id] = nil else n = n + 1 end
    end
    return n
end

-- "Name=5;Name=2" -> { Name = 5, Name = 2 }, anything odd is dropped
local function ParseItems(body)
    local t, n = {}, 0
    for item in body:gmatch("[^;]+") do
        local name, v = item:match("^(.+)=(%d+)$")
        v = tonumber(v)
        if name and v and v <= MAX_COUNT and #name <= 40 and n < 12 then
            t[(name:gsub("%c", ""):gsub("|", "||"))] = v
            n = n + 1
        end
    end
    return t
end

-- how often a peer reported each category / reason / zone
-- (old S1 messages, one kind each, are still understood)
local function OnStats(id, kind, body)
    if #id > 16 or id == OwnId() then return end
    local peer = ns.InitDB().peers[id]
    if not peer then return end -- their hello comes first
    peer.s = peer.s or {}
    peer.s[kind] = ParseItems(body)
    peer.t = time()
    if ns.RefreshHistory then ns.RefreshHistory() end
end

local function OnStats2(id, body)
    if #id > 16 or id == OwnId() then return end
    local peer = ns.InitDB().peers[id]
    if not peer then return end
    local s = {}
    for group in body:gmatch("[^|]+") do
        local kind, items = group:match("^([crz])=(.*)$")
        if kind then s[kind] = ParseItems(items) end
    end
    peer.s = s
    peer.t = time()
    if ns.RefreshHistory then ns.RefreshHistory() end
end

-- reply goes back the same way the message came. big = guild or channel:
-- there only a few people answer, and a bit later
local function OnMessage(text, reply, big, contact)
    if not Enabled() then return end
    local sid2, sbody2 = text:match("^S2:(%x+):(.+)$")
    if sid2 then OnStats2(sid2, sbody2) return end
    local sid, skind, sbody = text:match("^S1:(%x+):([crz]):(.+)$")
    if sid then OnStats(sid, skind, sbody) return end
    local kind, count, id = text:match("^([HR])1:(%d+):(%x+)$")
    count = tonumber(count)
    if not kind or not count or count > MAX_COUNT or #id > 16 then return end
    if id == OwnId() then return end

    local peers = ns.InitDB().peers
    local known = Prune(peers)
    if not peers[id] and known >= MAX_PEERS then return end
    local isNew = peers[id] == nil
    local old = peers[id]
    peers[id] = {
        n = count, t = time(), s = old and old.s,
        w = (contact and contact.w) or (old and old.w), -- how to reach them again
        bn = (contact and contact.bn) or (old and old.bn),
    }

    -- answer a new person's hello (replies never get answered, no loops)
    if kind == "H" and reply and isNew then
        local chance = big and math.min(1, REPLY_TARGET / math.max(1, known)) or 1
        if math.random() <= chance then
            local function Answer() if Enabled() then reply(Messages("R")) end end
            if big and C_Timer then C_Timer.After(math.random(1, 20), Answer) else Answer() end
        end
    end
    if ns.RefreshHistory then ns.RefreshHistory() end
end

-- how many reports does this player have? (nil if they are not a known addon user)
-- used for the mouseover tooltip
-- second value: their most common categories (top 3), if we know them
function ns.PeerReportCount(name, isSelf)
    if isSelf then
        return OwnCount(), ns.SortedTop((ns.OwnCounts()), 3)
    end
    if not Enabled() or not name or name == "" then return nil end
    local want = BaseName(name)
    for _, p in pairs(ns.InitDB().peers) do
        if p.w and BaseName(p.w) == want then
            return p.n, (p.s and p.s.c) and ns.SortedTop(p.s.c, 3) or {}
        end
    end
end

-- returns users seen and total reports (yours included)
function ns.CommunityTally()
    local peers = ns.InitDB().peers
    Prune(peers)
    local users, total = 1, OwnCount()
    for _, p in pairs(peers) do
        users = users + 1
        total = total + p.n
    end
    return users, total
end

-- total reports the others have and what they were for: n, categories, reasons, zones
function ns.CommunityData()
    local peers = ns.InitDB().peers
    Prune(peers)
    local n, c, r, z = 0, {}, {}, {}
    local function Add(into, from)
        for k, v in pairs(from or {}) do into[k] = (into[k] or 0) + v end
    end
    for _, p in pairs(peers) do
        n = n + p.n
        if p.s then Add(c, p.s.c); Add(r, p.s.r); Add(z, p.s.z) end
    end
    return n, c, r, z
end

-- /reportannouncer channel <name>   (empty clears it)
function ns.SetShareChannel(name)
    name = strtrim(name or "")
    ns.InitDB().shareChannel = name ~= "" and name or nil
    if name == "" then
        ns.Print("community channel cleared.")
    else
        ns.Print("community tally will also use the channel \"" .. name .. "\" (you must be in it).")
        ns.BroadcastCount()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("BN_CHAT_MSG_ADDON")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "PLAYER_LOGIN" then
        if Register then pcall(Register, PREFIX) end
        if C_Timer then
            C_Timer.After(10, function() ns.BroadcastCount() end)
            if C_Timer.NewTicker then C_Timer.NewTicker(30, CheckChanged) end
        end
    elseif event == "CHAT_MSG_ADDON" then
        -- prefix, text, channel, sender
        if a1 == PREFIX and a4 then
            recvCount = recvCount + 1
            Log("recv " .. tostring(a3) .. " from " .. tostring(a4) .. " " .. (a2 or ""):sub(1, 40))
            OnMessage(a2 or "", function(t) Send(t, "WHISPER", a4) end, a3 == "GUILD" or a3 == "CHANNEL", { w = a4 })
        end
    elseif event == "BN_CHAT_MSG_ADDON" then
        -- prefix, text, channel, senderID (a Battle.net game account)
        if a1 == PREFIX and a4 then
            recvCount = recvCount + 1
            Log("recv BNET " .. (a2 or ""):sub(1, 40))
            OnMessage(a2 or "", function(t) SendBN(t, a4) end, false, { bn = a4 })
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        Log("event GROUP_ROSTER_UPDATE")
        -- wait a moment, the new member needs to be in the group first
        if C_Timer then C_Timer.After(2, BroadcastGroup) else BroadcastGroup() end
    end
end)
