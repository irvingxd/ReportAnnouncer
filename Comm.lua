-- opt-in community tally. only a number (how many reports you have, no names) is
-- sent to addon users in your guild, group, a channel and friends.
-- counts are self reported, can't be checked.
local ADDON, ns = ...

local PREFIX = "RepAnn"
local EXPIRE = 30 * 86400 -- drop peers after 30 days
local MAX_PEERS = 500
local MAX_COUNT = 100000
local SEND_GAP = 60 -- seconds between broadcasts
local FRIEND_GAP = 600 -- seconds between friend broadcasts
local MAX_FRIENDS = 60

local Register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
local SendMsg = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage

local lastSent, lastFriends, lastGroup = 0, 0, 0
local GROUP_GAP = 5 -- group changes can send again quickly

local answered = {} -- when we last replied to each id

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

-- the count, plus how often each category / reason / zone was reported (no names).
-- one short message each, the top ones only (messages are limited to 255 bytes)
local KINDS = { "c", "r", "z" }
local function Messages(kind)
    local msgs = { Message(kind) }
    local counts = { ns.OwnCounts() }
    for i, k in ipairs(KINDS) do
        local parts, len = {}, 0
        for _, item in ipairs(ns.SortedTop(counts[i], 12)) do
            local name = (item.label:gsub("[;=:|%c]", "")):sub(1, 40)
            local piece = name .. "=" .. item.n
            if name ~= "" then
                if len + #piece + 1 > 200 then break end
                parts[#parts + 1] = piece
                len = len + #piece + 1
            end
        end
        if #parts > 0 then
            msgs[#msgs + 1] = "S1:" .. OwnId() .. ":" .. k .. ":" .. table.concat(parts, ";")
        end
    end
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

-- text can be one message or a list of them
local function Send(text, channel, target)
    if not SendMsg then return end
    for _, t in ipairs(type(text) == "table" and text or { text }) do
        sentCount = sentCount + 1
        Log("send " .. tostring(channel) .. (target and (" " .. tostring(target)) or "") .. " " .. #t .. "b " .. t:sub(1, 40))
        pcall(SendMsg, PREFIX, t, channel, target)
    end
end

local function SendBN(text, gameAccountID)
    if not (BNSendGameData and gameAccountID) then return end
    for _, t in ipairs(type(text) == "table" and text or { text }) do
        sentCount = sentCount + 1
        Log("send BNET " .. #t .. "b " .. t:sub(1, 40))
        pcall(BNSendGameData, gameAccountID, PREFIX, t)
    end
end

-- /ra debug [on|off|show [n]|clear|status]
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
    elseif arg == "status" then
        ns.Print("sent " .. sentCount .. ", received " .. recvCount .. " addon messages this session. log is "
            .. (db.debug and "on" or "off") .. ", " .. #(db.debugLog or {}) .. " lines.")
    else
        db.debug = true
        ns.Print("debug log on. /ra debug show  |  status  |  clear  |  off")
    end
end

local function EachFriend(fnWoW, fnBN)
    if C_FriendList and C_FriendList.GetNumFriends then
        local n = math.min(C_FriendList.GetNumFriends() or 0, MAX_FRIENDS)
        for i = 1, n do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected and info.name then fnWoW(info.name) end
        end
    end
    if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
        local n = math.min((BNGetNumFriends()) or 0, MAX_FRIENDS)
        for i = 1, n do
            local acc = C_BattleNet.GetFriendAccountInfo(i)
            local g = acc and acc.gameAccountInfo
            if g and g.isOnline and g.clientProgram == "WoW" and g.gameAccountID then fnBN(g.gameAccountID) end
        end
    end
end

-- someone joined or left: say hello to the group again (short wait, not 60s)
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

-- tell guild, group, channel and friends we're here
function ns.BroadcastCount(force)
    if not Enabled() or not SendMsg then return end
    local now = time()
    if not force and now - lastSent < SEND_GAP then return end
    lastSent = now
    local msg = Messages("H")

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

    if force or now - lastFriends >= FRIEND_GAP then
        lastFriends = now
        EachFriend(function(name) Send(msg, "WHISPER", name) end,
                   function(gid) SendBN(msg, gid) end)
    end
end

local function Prune(peers)
    local now, n = time(), 0
    for id, p in pairs(peers) do
        if now - (p.t or 0) > EXPIRE then peers[id] = nil else n = n + 1 end
    end
    return n
end

-- how often a peer reported each category / reason / zone
local function OnStats(id, kind, body)
    if #id > 16 or id == OwnId() then return end
    local peer = ns.InitDB().peers[id]
    if not peer then return end -- their hello comes first
    local t, n = {}, 0
    for item in body:gmatch("[^;]+") do
        local name, v = item:match("^([^=]+)=(%d+)$")
        v = tonumber(v)
        if name and v and v <= MAX_COUNT and #name <= 40 and n < 12 then
            t[(name:gsub("%c", ""):gsub("|", "||"))] = v
            n = n + 1
        end
    end
    peer.s = peer.s or {}
    peer.s[kind] = t
    peer.t = time()
    if ns.RefreshHistory then ns.RefreshHistory() end
end

-- reply goes back the same way the message came
local function OnMessage(text, reply)
    if not Enabled() then return end
    local sid, skind, sbody = text:match("^S1:(%x+):([crz]):(.+)$")
    if sid then OnStats(sid, skind, sbody) return end
    local kind, count, id = text:match("^([HR])1:(%d+):(%x+)$")
    count = tonumber(count)
    if not kind or not count or count > MAX_COUNT or #id > 16 then return end
    if id == OwnId() then return end

    local peers = ns.InitDB().peers
    if not peers[id] and Prune(peers) >= MAX_PEERS then return end
    local isNew = peers[id] == nil
    peers[id] = { n = count, t = time(), s = peers[id] and peers[id].s }

    -- answer a hello we haven't answered lately (replies never get answered, no loops)
    local now = time()
    if kind == "H" and reply and (isNew or now - (answered[id] or 0) > 30) then
        answered[id] = now
        reply(Messages("R"))
    end
    if ns.RefreshHistory then ns.RefreshHistory() end
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
        ns.BroadcastCount(true)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("BN_CHAT_MSG_ADDON")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "PLAYER_LOGIN" then
        if Register then pcall(Register, PREFIX) end
        if C_Timer then C_Timer.After(10, function() ns.BroadcastCount(true) end) end
    elseif event == "CHAT_MSG_ADDON" then
        -- prefix, text, channel, sender
        if a1 == PREFIX and a4 then
            recvCount = recvCount + 1
            Log("recv " .. tostring(a3) .. " from " .. tostring(a4) .. " " .. (a2 or ""):sub(1, 40))
            OnMessage(a2 or "", function(t) Send(t, "WHISPER", a4) end)
        end
    elseif event == "BN_CHAT_MSG_ADDON" then
        -- prefix, text, channel, senderID (a Battle.net game account)
        if a1 == PREFIX and a4 then
            recvCount = recvCount + 1
            Log("recv BNET " .. (a2 or ""):sub(1, 40))
            OnMessage(a2 or "", function(t) SendBN(t, a4) end)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        Log("event GROUP_ROSTER_UPDATE")
        -- wait a moment, the new member needs to be in the group first
        if C_Timer then C_Timer.After(2, BroadcastGroup) else BroadcastGroup() end
    else
        ns.BroadcastCount(false)
    end
end)
