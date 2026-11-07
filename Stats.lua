-- stats over your reports (imported lists optional)
local ADDON, ns = ...

local function SortedTop(counts, limit)
    local list = {}
    for label, n in pairs(counts) do list[#list + 1] = { label = label, n = n } end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.label < b.label
    end)
    for i = #list, limit + 1, -1 do list[i] = nil end
    return list
end

local function Bump(counts, key)
    if key and key ~= "" then counts[key] = (counts[key] or 0) + 1 end
end

local function Tally(entries, categories, reasons, zones, perPlayer, labels)
    for _, e in ipairs(entries) do
        Bump(categories, e.category or "Other")
        if e.reasons and e.reasons ~= "" then
            for reason in e.reasons:gmatch("[^,]+") do
                Bump(reasons, strtrim(reason))
            end
        end
        if e.zone and e.zone ~= "" then
            Bump(zones, strtrim(e.zone:match("([^,]+)$") or e.zone))
        end
        local key = e.guid or strlower(e.name or "?")
        perPlayer[key] = (perPlayer[key] or 0) + 1
        labels[key] = e.name or "?"
    end
end

-- Returns { total, players, categories = {{label,n}}, reasons, zones, repeats }
function ns.ComputeStats(includeImports)
    local db = ns.InitDB()
    local categories, reasons, zones = {}, {}, {}
    local perPlayer, labels = {}, {}
    local total = #db.history

    Tally(db.history, categories, reasons, zones, perPlayer, labels)
    if includeImports then
        for _, list in ipairs(db.imports) do
            total = total + #list.entries
            Tally(list.entries, categories, reasons, zones, perPlayer, labels)
        end
    end

    local players, repeatCounts = 0, {}
    for key, n in pairs(perPlayer) do
        players = players + 1
        if n > 1 then repeatCounts[labels[key]] = n end
    end

    return {
        total = total,
        players = players,
        categories = SortedTop(categories, 6),
        reasons = SortedTop(reasons, 8),
        zones = SortedTop(zones, 5),
        repeats = SortedTop(repeatCounts, 5),
    }
end
