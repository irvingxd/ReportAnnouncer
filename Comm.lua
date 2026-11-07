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

local lastSent, lastFriends = 0, 0

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

local function Send(text, channel, target)
    if not SendMsg then return end
    pcall(SendMsg, PREFIX, text, channel, target)
end

local function SendBN(text, gameAccountID)
    if BNSendGameData and gameAccountID then pcall(BNSendGameData, gameAccountID, PREFIX, text) end
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

-- tell guild, group, channel and friends we're here
function ns.BroadcastCount(force)
    if not Enabled() or not SendMsg then return end
    local now = time()
    if not force and now - lastSent < SEND_GAP then return end
    lastSent = now
    local msg = Message("H")

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

-- reply goes back the same way the message came
local function OnMessage(text, reply)
    if not Enabled() then return end
    local kind, count, id = text:match("^([HR])1:(%d+):(%x+)$")
    count = tonumber(count)
    if not kind or not count or count > MAX_COUNT or #id > 16 then return end
    if id == OwnId() then return end

    local peers = ns.InitDB().peers
    if not peers[id] and Prune(peers) >= MAX_PEERS then return end
    local isNew = peers[id] == nil
    peers[id] = { n = count, t = time() }

    -- answer a new hello once (replies never get answered, no loops)
    if kind == "H" and isNew and reply then reply(Message("R")) end
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
            OnMessage(a2 or "", function(t) Send(t, "WHISPER", a4) end)
        end
    elseif event == "BN_CHAT_MSG_ADDON" then
        -- prefix, text, channel, senderID (a Battle.net game account)
        if a1 == PREFIX and a4 then
            OnMessage(a2 or "", function(t) SendBN(t, a4) end)
        end
    else
        ns.BroadcastCount(false)
    end
end)
