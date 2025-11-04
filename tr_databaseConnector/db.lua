
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
            connectionTimer = setTimer(DB.connect, RECONNECT_DELAY,
