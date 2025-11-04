-- Główny loader core, uruchamia moduly, eventy, migracje SQL

local CORE_CONFIG = CORE_CONFIG or {
    db = {
        host = "sql.25.svpj.link",
        port = 3306,
        user = "db_114539",
        pass = "SbK3Ja0t18yI7Gg",
        database = "db_114539",
        charset = "utf8mb4"
    },
    autosave_interval_ms = 5 * 60 * 1000
}

local Database = require("core.database")
local Users = require("core.modules.users")
local Punishments = require("core.modules.punishments")
local Chat = require("core.modules.chat")
local Vehicles = require("core.modules.vehicles")
local Factions = require("core.modules.factions")
local Admins = require("core.modules.admins")

local Core = {}
Core.__index = Core

function Core:new()
    local o = {
        cfg = CORE_CONFIG,
        db = nil,
        users = nil,
        punishments = nil,
        chat = nil,
        vehicles = nil,
        factions = nil,
        admins = nil,
        autosaveTimer = nil
    }
    setmetatable(o, self)
    return o
end

local function log(fmt, ...)
    outputDebugString(("[core] " .. fmt):format(...))
end

function Core:init()
    log("Init core...")
    self.db = Database:new(self.cfg.db)
    local ok, err = self.db:connect()
    if not ok then
        log("DB connect failed: %s", tostring(err))
        return false, err
    end
  
    local migrationsFile = "core/migrations.sql"
    if fileExists(migrationsFile) then
        local f = fileOpen(migrationsFile)
        local c = fileRead(f, fileGetSize(f))
        fileClose(f)
        for stmt in c:gmatch("([^;]+);") do
            stmt = stmt:match("^%s*(.-)%s*$")
            if stmt ~= "" then
                local ok_mig, mig_err = self.db:execRaw(stmt)
                if not ok_mig then
                    log("Migration failed: %s", tostring(mig_err))
                    -- continue, but warn
                end
            end
        end
        log("Migrations executed (if any).")
    else
        log("migrations.sql not found, skipping.")
    end

    self.users = Users:new(self)
    self.punishments = Punishments:new(self)
    self.chat = Chat:new(self)
    self.vehicles = Vehicles:new(self)
    self.factions = Factions:new(self)
    self.admins = Admins:new(self)

    addEventHandler("onPlayerJoin", root, function() self:onPlayerJoin(source) end)
    addEventHandler("onPlayerQuit", root, function() self:onPlayerQuit(source) end)
    addEventHandler("onPlayerChat", root, function(message, msgType)
        if self.chat and self.chat:handleChat(source, message) then
            cancelEvent()
        end
    end)

    self.autosaveTimer = setTimer(function() self:autosave() end, self.cfg.autosave_interval_ms, 0)
    log("Core initialized.")
    return true
end

function Core:onPlayerJoin(player)
    if not isElement(player) then return end
    local serial = getPlayerSerial(player)
    if not serial then
        kickPlayer(player, "No serial.")
        return
    end
    local ok, userdata = self.users:loadBySerial(serial, player)
    if not ok then
        log("users:loadBySerial failed: %s", tostring(userdata))
        kickPlayer(player, "Błąd konta.")
        return
    end
    local banned, banData = self.punishments:isBannedBySerial(serial)
    if banned then
        local untilTxt = (banData.until == 0) and "na stałe" or ("do "..os.date("%Y-%m-%d %H:%M:%S", banData.until))
        kickPlayer(player, ("Zbanowany %s. Powód: %s"):format(untilTxt, tostring(banData.reason)))
        return
    end

    local tid = userdata.tid
    self.vehicles:load(tid, player)
    self.factions:load(tid, player)
    self.admins:load(tid, player)
    setElementData(player, "core:tid", tid)
    setElementData(player, "core:user", userdata)
    log("Player joined: %s (tid=%s)", tostring(getPlayerName(player)), tostring(tid))
end

function Core:onPlayerQuit(player)
    if not isElement(player) then return end
    local serial = getPlayerSerial(player)
    if not serial then return end
    local tid = self.users:getTidBySerial(serial)
    if tid then
        pcall(function() self.vehicles:save(tid) end)
        pcall(function() self.factions:save(tid) end)
        pcall(function() self.admins:save(tid) end)
    end
    pcall(function() self.users:saveBySerial(serial) end)
    log("Player quit: %s", tostring(getPlayerName(player)))
end

function Core:autosave()
    log("Autosave started.")
    for _,player in ipairs(getElementsByType("player")) do
        local serial = getPlayerSerial(player)
        if serial then
            pcall(function() self.users:saveBySerial(serial) end)
        end
    end
    if self.vehicles.autosave then pcall(function() self.vehicles:autosaveAll() end) end
    log("Autosave finished.")
end

addEventHandler("onResourceStart", resourceRoot, function()
    if not _G.RPGCore then
        _G.RPGCore = Core:new()
        local ok, err = _G.RPGCore:init()
        if not ok then outputDebugString("Core init failed: "..tostring(err)) end
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if _G.RPGCore then
        if isTimer(_G.RPGCore.autosaveTimer) then killTimer(_G.RPGCore.autosaveTimer) end
        _G.RPGCore = nil
    end
end)

return Core
