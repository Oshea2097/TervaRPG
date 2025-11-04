-- FILE: core/database.lua
-- DB wrapper dla MTA: bezpieczne prepared statements, reconnect, timeouty
-- Uwaga: używa MTA API: dbConnect, dbPrepare, dbQuery, dbPoll, dbExec

local Database = {}
Database.__index = Database

function Database:new(config)
    local o = {
        cfg = config or {},
        conn = nil,
        prepared = {},     -- name -> statement object
        last_error = nil,
        poll_timeout = 5000 -- ms
    }
    setmetatable(o, self)
    return o
end

local function log(...)
    outputDebugString("[DB] " .. table.concat({...}, " "))
end

function Database:connect()
    local c = self.cfg
    if not c or not c.host then return false, "no_config" end
    local connStr = string.format("dbname=%s;host=%s;port=%d;charset=%s",
        tostring(c.database), tostring(c.host), tonumber(c.port) or 3306, tostring(c.charset or "utf8"))
    local conn, err = dbConnect("mysql", connStr, tostring(c.user), tostring(c.pass), "share=1;autoreconnect=1;charset="..tostring(c.charset or "utf8"))
    if not conn then
        self.last_error = err or "dbConnect_failed"
        log("connect failed:", self.last_error)
        return false, self.last_error
    end
    self.conn = conn
    log("connected to DB:", c.host, c.database)
    return true
end

function Database:_ensure()
    if self.conn and getResourceState(exports) then -- cheap check; MTA doesn't provide direct isConnected func
        return true
    end
    local ok, err = self:connect()
    return ok, err
end

function Database:prepare(name, query)
    if not name or not query then return false, "invalid_args" end
    if not self.conn then
        local ok, err = self:connect()
        if not ok then return false, err end
    end
    if self.prepared[name] then return true end
    local stmt = dbPrepare(self.conn, query)
    if not stmt then
        self.last_error = "prepare_failed"
        log("prepare failed for", name)
        return false, "prepare_failed"
    end
    self.prepared[name] = stmt
    return true
end

function Database:execPrepared(name, ...)
    if not self.prepared[name] then return false, "no_stmt" end
    if not self.conn then
        local ok, err = self:connect()
        if not ok then return false, err end
    end
    local stmt = self.prepared[name]
    local qh = dbQuery(stmt, ...)
    if not qh then
        self.last_error = "dbQuery_failed"
        return false, "dbQuery_failed"
    end
    local res = dbPoll(qh, self.poll_timeout)
    if not res then
        self.last_error = "dbPoll_timeout"
        return false, "dbPoll_timeout"
    end
    return true, res
end

function Database:execRaw(query, ...)
    if not query then return false, "no_query" end
    if not self.conn then
        local ok, err = self:connect()
        if not ok then return false, err end
    end
    local ok = dbExec(self.conn, query, ...)
    if not ok then
        self.last_error = "exec_failed"
        return false, "exec_failed"
    end
    return true
end

function Database:fetchOnePrepared(name, ...)
    local ok, res = self:execPrepared(name, ...)
    if not ok then return false, res end
    if res[1] then return true, res[1] end
    return true, nil
end

function Database:lastInsertId()
    if not self.conn then return nil end
    local qh = dbQuery(self.conn, "SELECT LAST_INSERT_ID() AS id")
    if not qh then return nil end
    local res = dbPoll(qh, 2000)
    if not res or not res[1] or not res[1].id then return nil end
    return tonumber(res[1].id)
end

function Database:close()
    -- There is no explicit dbClose in MTA; set conn nil and let resource stop handle it
    self.prepared = {}
    self.conn = nil
    log("db wrapper closed")
end

return Database
