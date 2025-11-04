
-- System administracji TervaRPG: backend autoryzacji i danych panelu

local db = exports.tr_databaseConnector

local function log(msg, ...)
    outputServerLog(("[tr_admins] " .. msg):format(...))
end

-- Pobierz dane admina z bazy
local function getAdminData(player)
    if not isElement(player) then return nil end

    local serial = getPlayerSerial(player)
    local tid = getElementData(player, "player:tid") or 0

    local row = db:fetchOne("SELECT * FROM admins WHERE serial=? OR tid=? LIMIT 1", {serial, tid})
    return row
end

-- Log otwarcia panelu
local function logAdminAction(player, action)
    local serial = getPlayerSerial(player)
    local tid = getElementData(player, "player:tid") or 0
    db:exec("INSERT INTO admin_logs (serial, tid, action, timestamp) VALUES (?, ?, ?, NOW())", {serial, tid, action})
end

-- Event otwarcia panelu
addEvent("admin:requestOpen", true)
addEventHandler("admin:requestOpen", root, function()
    local player = client
    local data = getAdminData(player)

    if not data then
        triggerClientEvent(player, "admin:clientShowPanel", player, false, "Brak uprawnień administracyjnych.")
        return
    end

    local rank = data.rank or "Brak"
    if rank == "Brak" then
        triggerClientEvent(player, "admin:clientShowPanel", player, false, "Nie jesteś administratorem.")
        return
    end

    logAdminAction(player, "Otworzenie panelu")
    triggerClientEvent(player, "admin:clientShowPanel", player, true, {
        rank = rank,
        username = data.username or getPlayerName(player),
        lastLogin = data.lastLogin or "Brak danych",
    })
    log("Panel administracyjny otwarty przez %s [%s]", getPlayerName(player), rank)
end)

-- Dla testu: komenda ręczna /adminpanel
addCommandHandler("adminpanel", function(player)
    triggerEvent("admin:requestOpen", player)
end)
