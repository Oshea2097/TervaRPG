
local DB = {
    connection = nil,
    connected = false,
    cfg = {
        host = "sql.25.svpj.link",
        port = 3306,
        user = "db_114539",
        password = "SbK3Ja0t18yI7Gg",
        database = "db_114539",
        charset = "utf8mb4",
    }
}

local RECONNECT_DELAY = 5000 -- ms
local connectionTimer = nil

local function log(msg, ...)
    outputServerLog(("[tr_databaseConnector] " .. msg):format(...))
end

function DB.connect()
    if DB.connected then return true end
    local c = DB.cfg
    local connStr = string.format("dbname=%s;host=%s;port=%d;charset=%s", c.database, c.host, c.port, c.charset)
    DB.connection = dbConnect("mysql", connStr, c.user, c.password, "share=1")
    if DB.connection then
        DB.connected = true
        log("Połączono z bazą danych %s:%d [%s]", c.host, c.port, c.database)
        return true
    else
        DB.connected = false
        log("Nie udało się połączyć z bazą, próba ponownie za %d sekund...", RECONNECT_DELAY/1000)
        if not connectionTimer then
            connectionTimer = setTimer(DB.connect, RECONNECT_DELAY, 0)
        end
        return false
    end
end

function DB.disconnect()
    if DB.connection and isElement(DB.connection) then
        destroyElement(DB.connection)
    end
    DB.connected = false
    DB.connection = nil
    if isTimer(connectionTimer) then
        killTimer(connectionTimer)
        connectionTimer = nil
    end
    log("Połączenie z bazą zakończone.")
end

function getConnection()
    if not DB.connected or not isElement(DB.connection) then
        DB.connect()
    end
    return DB.connection
end

function query(sql, params, callback)
    if not getConnection() then return false end
    local qh = dbQuery(getConnection(), sql, unpack(params or {}))
    if not qh then
        log("Błąd zapytania: %s", tostring(sql))
        return false
    end
    if type(callback) == "function" then
        dbPoll(qh, -1, callback)
    else
        local result, _, err = dbPoll(qh, -1)
        if not result then
            log("Błąd poll: %s", tostring(err))
        end
        return result
    end
end

function exec(sql, params)
    if not getConnection() then return false end
    local ok = dbExec(getConnection(), sql, unpack(params or {}))
    if not ok then
        log("Błąd exec: %s", sql)
    end
    return ok
end

function fetchOne(sql, params)
    local result = query(sql, params)
    if result and #result > 0 then
        return result[1]
    end
    return nil
end

addEventHandler("onResourceStart", resourceRoot, function()
    DB.connect()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    DB.disconnect()
end)

-- Eksporty
_G.DB = DB
