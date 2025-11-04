-- tr_admins/admin_server.lua
-- Backend administracji: handshake, players list, punishments (ban/mute/unban/warn) + logging

local db = exports.tr_databaseConnector
local function logf(fmt, ...) outputServerLog(("[tr_admins] " .. fmt):format(...)) end

-- Helper: pobierz wpis admina z tabeli admins (aktywni)
local function getAdminDataByPlayer(player)
    if not isElement(player) then return nil end
    local serial = getPlayerSerial(player) or ""
    local tid = tostring(getElementData(player, "player:tid") or "")
    -- najpierw po serial, potem po tid
    local row = db:fetchOne("SELECT * FROM admins WHERE (serial=? OR tid=?) AND active=1 LIMIT 1", {serial, tid})
    return row
end

-- Helper: log admin action
local function adminLog(adminName, action, targetSerial, targetTid, extra)
    db:exec("INSERT INTO admin_logs (admin, action, target_serial, target_tid, extra, created_at) VALUES (?, ?, ?, ?, ?, NOW())",
        { tostring(adminName or ""), tostring(action or ""), tostring(targetSerial or ""), tostring(targetTid or ""), tostring(extra or "") })
end

-- Helper: push punishments into DB
local function addPunishment(serial, tid, ptype, until_ts, reason, adminName)
    return db:exec("INSERT INTO punishments (serial, tid, type, until_ts, reason, admin, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())",
        { tostring(serial or ""), tostring(tid or ""), tostring(ptype or "warn"), tonumber(until_ts) or 0, tostring(reason or ""), tostring(adminName or "") })
end

-- Handshake: klient prosi o otwarcie panelu
addEvent("admin:requestOpen", true)
addEventHandler("admin:requestOpen", root, function()
    local ply = client
    if not isElement(ply) then return end
    local adminRow = getAdminDataByPlayer(ply)
    if not adminRow then
        triggerClientEvent(ply, "admin:clientShowPanel", ply, false, "Brak uprawnień administracyjnych.")
        return
    end
    -- success: send admin info
    local payload = {
        rank = adminRow.rank or "Brak",
        username = adminRow.username or getPlayerName(ply),
        lastLogin = adminRow.lastLogin or tostring(adminRow.addedDate or "")
    }
    adminLog(payload.username, "OPEN_PANEL", getPlayerSerial(ply), tostring(getElementData(ply,"player:tid") or ""), "")
    triggerClientEvent(ply, "admin:clientShowPanel", ply, true, payload)
end)

-- Provide players list
addEvent("admin:requestPlayers", true)
addEventHandler("admin:requestPlayers", root, function()
    local ply = client
    if not isElement(ply) then return end
    -- Validate admin
    local adminRow = getAdminDataByPlayer(ply)
    if not adminRow then
        triggerClientEvent(ply, "admin:notify", ply, "Brak uprawnień.")
        return
    end

    local players = {}
    for _, p in ipairs(getElementsByType("player")) do
        table.insert(players, {
            name = getPlayerName(p),
            tid = tostring(getElementData(p, "player:tid") or ""),
            serial = getPlayerSerial(p),
            ping = getPlayerPing(p)
        })
    end
    triggerClientEvent(ply, "admin:receivePlayers", ply, players)
end)

-- Admin actions: action (string), payload (table)
addEvent("admin:action", true)
addEventHandler("admin:action", root, function(action, payload)
    local admin = client
    if not isElement(admin) then return end
    -- validate admin rights
    local adminRow = getAdminDataByPlayer(admin)
    if not adminRow then
        triggerClientEvent(admin, "admin:notify", admin, "Brak uprawnień.")
        return
    end
    local adminName = adminRow.username or getPlayerName(admin)
    action = tostring(action or "")

    -- validate payload
    payload = type(payload) == "table" and payload or {}

    -- resolve target - by tid or name or serial
    local target = nil
    if payload.tid and payload.tid ~= "" then
        -- try find element by tid (element data mapping)
        for _, p in ipairs(getElementsByType("player")) do
            if tostring(getElementData(p, "player:tid") or "") == tostring(payload.tid) then target = p; break end
        end
    elseif payload.name and payload.name ~= "" then
        target = getPlayerFromName(payload.name)
    elseif payload.serial and payload.serial ~= "" then
        for _, p in ipairs(getElementsByType("player")) do
            if getPlayerSerial(p) == payload.serial then target = p; break end
        end
    end

    -- Helper: respond to admin
    local function notifyAdmin(msg)
        triggerClientEvent(admin, "admin:notify", admin, msg)
    end

    -- Actions handling
    if action == "tpTo" then
        if not target then notifyAdmin("Nie znaleziono gracza."); return end
        local x,y,z = getElementPosition(target)
        setElementPosition(admin, x, y, z)
        notifyAdmin("Teleportowano do gracza "..getPlayerName(target))
        adminLog(adminName, "TP_TO", getPlayerSerial(target), tostring(getElementData(target,"player:tid") or ""), "")
        return
    end

    if action == "tpHere" then
        if not target then notifyAdmin("Nie znaleziono gracza."); return end
        local x,y,z = getElementPosition(admin)
        setElementPosition(target, x, y, z)
        notifyAdmin("Gracz "..getPlayerName(target).." został przeteleportowany do ciebie.")
        adminLog(adminName, "TP_HERE", getPlayerSerial(target), tostring(getElementData(target,"player:tid") or ""), "")
        return
    end

    if action == "kick" then
        if not target then notifyAdmin("Nie znaleziono gracza."); return end
        local reason = tostring(payload.reason or "Wyrzucony przez administrację")
        kickPlayer(target, reason)
        notifyAdmin("Wyrzucono gracza "..getPlayerName(target))
        adminLog(adminName, "KICK", getPlayerSerial(target), tostring(getElementData(target,"player:tid") or ""), reason)
        return
    end

    if action == "warn" then
        local tSerial, tTid = "", ""
        if target then tSerial = getPlayerSerial(target); tTid = tostring(getElementData(target,"player:tid") or "") end
        local reason = tostring(payload.reason or "Ostrzeżenie")
        addPunishment(tSerial, tTid, "warn", 0, reason, adminName)
        notifyAdmin("Dodano warn dla "..(target and getPlayerName(target) or payload.name or "nieznany"))
        adminLog(adminName, "WARN", tSerial, tTid, reason)
        return
    end

    if action == "mute" then
        if not target then notifyAdmin("Nie znaleziono gracza."); return end
        local minutes = tonumber(payload.minutes) or 0
        local until_ts = 0
        if minutes > 0 then until_ts = os.time() + (minutes * 60) end
        -- set server mute if available
        if type(setPlayerMuted) == "function" then
            setPlayerMuted(target, true)
        else
            -- fallback: set element data; client chat should check this (not implemented here)
            setElementData(target, "admin:muted", true)
        end
        addPunishment(getPlayerSerial(target), tostring(getElementData(target,"player:tid") or ""), "mute", until_ts, tostring(payload.reason or "Mute od admina"), adminName)
        notifyAdmin("Zmutowano gracza "..getPlayerName(target))
        adminLog(adminName, "MUTE", getPlayerSerial(target), tostring(getElementData(target,"player:tid") or ""), payload.reason or "")
        return
    end

    if action == "ban" then
        if not target then notifyAdmin("Nie znaleziono gracza."); return end
        local minutes = tonumber(payload.minutes) or 0
        local reason = tostring(payload.reason or "Ban od administracji")
        local until_ts = 0
        if minutes > 0 then until_ts = os.time() + (minutes * 60) end
        -- insert punish to DB
        addPunishment(getPlayerSerial(target), tostring(getElementData(target,"player:tid") or ""), "ban", until_ts, reason, adminName)
        -- use MTA ban
        -- banPlayer (player, minutes, reason, serial) - minutes=0 for permanent
        local ban_ok = false
        pcall(function()
            banPlayer(target, minutes, reason, getPlayerSerial(target))
            ban_ok = true
        end)
        if ban_ok then
            notifyAdmin("Zbanowano "..getPlayerName(target).." ("..(minutes>0 and tostring(minutes).."m" or "na stałe")..")")
            adminLog(adminName, "BAN", getPlayerSerial(target), tostring(getElementData(target,"player:tid") or ""), reason)
        else
            notifyAdmin("Ban zapisany w DB, ale nie udało się wywołać banPlayer.")
            adminLog(adminName, "BAN_DB_ONLY", getPlayerSerial(target), tostring(getElementData(target,"player:tid") or ""), reason)
        end
        return
    end

    if action == "unban" then
        -- payload: serial or tid or name (name for online find)
        local targetSerial = tostring(payload.serial or "")
        local targetTid = tostring(payload.tid or "")
        if target == nil and payload.serial == nil then
            notifyAdmin("Podaj serial lub tid do unbana.")
            return
        end
        -- remove active bans: we'll insert an 'unban' entry and optionally delete bans
        addPunishment(targetSerial, targetTid, "unban", 0, tostring(payload.reason or "Unban"), adminName)
        -- also delete bans from punishments where serial matches and type='ban' (optional)
        db:exec("DELETE FROM punishments WHERE serial=? AND type='ban'", {targetSerial})
        notifyAdmin("Unban wykonany dla serial: "..tostring(targetSerial))
        adminLog(adminName, "UNBAN", targetSerial, targetTid, payload.reason or "")
        return
    end

    notifyAdmin("Nieznana akcja: "..tostring(action))
end)
