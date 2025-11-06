local function mapRankFromUserRow(user)
    if not user then return "player" end
    -- try several common fields, be tolerant
    if user.root and tonumber(user.root) == 1 then return "root" end
    if user.admin and tonumber(user.admin) == 2 then return "opiekun administracji" end
    if user.admin and tonumber(user.admin) == 3 then return "starszy administrator" end
    if user.admin and tonumber(user.admin) == 1 then return "administrator" end
    if user.moderator and tonumber(user.moderator) == 1 then return "moderator" end
    if user.helper and tonumber(user.helper) == 1 then return "helper" end
    if user.test_helper and tonumber(user.test_helper) == 1 then return "test helper" end
    return "player"
end

local function collectPlayerData(player)
    if not isElement(player) or getElementType(player) ~= "player" then return nil end

    local tid = getElementData(player, "core:tid") or 0
    local user = getElementData(player, "core:user") or {}
    local name = tostring(getPlayerName(player) or "Nieznany")
    local faction = tostring(user.faction or "Brak")
    local org = tostring(user.organization or user.faction or "-")
    local playTimeSeconds = tonumber(user.playtime) or tonumber(user.playTime) or 0
    local playTimeFormatted = string.format("%dh %dm", math.floor(playTimeSeconds / 3600), math.floor((playTimeSeconds % 3600) / 60))

    local rank = mapRankFromUserRow(user)

    return {
        id = tonumber(tid) or 0,
        name = name,
        faction = faction,
        organization = org,
        playTime = playTimeFormatted,
        rawPlaySeconds = playTimeSeconds,
        rank = rank
    }
end

local function getAllPlayersData()
    local t = {}
    for _, p in ipairs(getElementsByType("player")) do
        local row = collectPlayerData(p)
        if row then table.insert(t, row) end
    end
    -- optional: sort by id or playtime
    table.sort(t, function(a,b) return (a.id or 0) < (b.id or 0) end)
    return t
end

addEvent("scoreboard:requestData", true)
addEventHandler("scoreboard:requestData", resourceRoot,
    function()
        local requester = client or source -- client is the player who triggered the event
        if not requester or not isElement(requester) then return end
        local data = getAllPlayersData()
        triggerClientEvent(requester, "scoreboard:receiveData", resourceRoot, data)
    end
)

-- optional: push updates periodically to everyone (or on player join/quit)
local function broadcastUpdate()
    local data = getAllPlayersData()
    for _, p in ipairs(getElementsByType("player")) do
        triggerClientEvent(p, "scoreboard:receiveData", resourceRoot, data)
    end
end

-- update on join/quit
addEventHandler("onPlayerJoin", root, function() setTimer(broadcastUpdate, 500, 1) end)
addEventHandler("onPlayerQuit", root, function() setTimer(broadcastUpdate, 500, 1) end)
