
-- Users module: zarządza tabelą users, tworzenie tid, cache, load/save

local Users = {}
Users.__index = Users

function Users:new(core)
    local o = { core = core, cache = {} } -- cache[serial] = row
    setmetatable(o, self)

    core.db:prepare("users_get_by_serial", "SELECT tid, serial, name, money, bankMoney, pjA, pjB, pjC, pjD, pjCE, kz, admin, faction FROM users WHERE serial = ? LIMIT 1")
    core.db:prepare("users_insert", "INSERT INTO users (serial, name, money, bankMoney, pjA, pjB, pjC, pjD, pjCE, kz, admin, faction, lastSeen) VALUES (?, ?, 0, 0, 0, 0, 0, 0, 0, '', 0, 'Brak', NOW())")
    core.db:prepare("users_update", "UPDATE users SET name=?, money=?, bankMoney=?, pjA=?, pjB=?, pjC=?, pjD=?, pjCE=?, kz=?, admin=?, faction=?, lastSeen=NOW() WHERE serial=?")

    return o
end

function Users:loadBySerial(serial, player)
    if not serial then return false, "no_serial" end
    if self.cache[serial] then
        if player then setElementData(player, "player:data", self.cache[serial]) end
        return true, self.cache[serial]
    end
    local ok, res = self.core.db:execPrepared("users_get_by_serial", serial)
    if not ok then return false, res end
    if #res == 0 then
        local name = tostring(getPlayerName(player) or "unknown"):sub(1,64)
        local ok2, res2 = self.core.db:execPrepared("users_insert", serial, name)
        if not ok2 then return false, res2 end
        local tid = self.core.db:lastInsertId()
        local row = { tid = tid, serial = serial, name = name, money = 0, bankMoney = 0, pjA = 0, pjB = 0, pjC = 0, pjD = 0, pjCE = 0, kz = "", admin = 0, faction = "Brak" }
        self.cache[serial] = row
        if player then setElementData(player, "player:data", row) end
        return true, row
    else
        local row = res[1]
        row.money = tonumber(row.money) or 0
        row.bankMoney = tonumber(row.bankMoney) or 0
        row.pjA = tonumber(row.pjA) == 1 and 1 or 0
        row.pjB = tonumber(row.pjB) == 1 and 1 or 0
        row.pjC = tonumber(row.pjC) == 1 and 1 or 0
        row.pjD = tonumber(row.pjD) == 1 and 1 or 0
        row.pjCE = tonumber(row.pjCE) == 1 and 1 or 0
        row.admin = tonumber(row.admin) or 0
        self.cache[serial] = row
        if player then setElementData(player, "player:data", row) end
        return true, row
    end
end

function Users:getTidBySerial(serial)
    if self.cache[serial] then return self.cache[serial].tid end
    local ok, res = self.core.db:execPrepared("users_get_by_serial", serial)
    if not ok or not res[1] then return nil end
    return res[1].tid
end

function Users:saveBySerial(serial)
    local row = self.cache[serial]
    if not row then return false, "no_cache" end
    row.name = tostring(row.name or "unknown"):sub(1,64)
    local ok, res = self.core.db:execPrepared("users_update",
        row.name, row.money, row.bankMoney,
        row.pjA, row.pjB, row.pjC, row.pjD, row.pjCE,
        row.kz or "", row.admin or 0, row.faction or "Brak", serial)
    if not ok then return false, res end
    return true
end

return Users
