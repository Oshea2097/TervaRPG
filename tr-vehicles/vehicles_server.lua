
-- Main manager: DB integration, spawn/despawn, simulation tick, events, exports
-- Only essential 'why' comments.

local DB_EXPORT = exports.tr_databaseConnector -- expected exported module
if not DB_EXPORT then
    outputDebugString("[vehicles_system] ERROR: tr_databaseConnector export not found.", 1)
end

local VehiclesMgr = {}
VehiclesMgr.__index = VehiclesMgr

function VehiclesMgr.new()
    local self = setmetatable({}, VehiclesMgr)
    self.db = DB_EXPORT
    self.cache = {} -- cache[ownerSerial] = { id -> Vehicle instance }
    self.spawnIndex = {} -- spawnIndex[id] = element
    self.tickTimer = nil
    self.tickInterval = 3000
    return self
end

-- DB helpers (assumes exported API: execute, fetchAll, fetchOne)
function VehiclesMgr:execute(sql, params)
    if not self.db then return false, "no_db" end
    return self.db.execute(sql, params)
end
function VehiclesMgr:fetchAll(sql, params)
    if not self.db then return false, "no_db" end
    return self.db.fetchAll(sql, params)
end
function VehiclesMgr:fetchOne(sql, params)
    if not self.db then return false, "no_db" end
    return self.db.fetchOne(sql, params)
end

-- Create table if needed
function VehiclesMgr:initDB()
    if not self.db then return end
    local file = fileExists and fileExists("sql/vehicles.sql") and "sql/vehicles.sql"
    if file then
        -- try to read and execute content (admin should run SQL manually ideally)
        local f = fileOpen(file)
        if f then
            local size = fileGetSize(f)
            local content = fileRead(f, size)
            fileClose(f)
            if content and content ~= "" then
                self:execute(content, {})
            end
        end
    else
        -- fallback: attempt simple create if allowed (already provided earlier)
    end
end

-- Load player's vehicles into cache
function VehiclesMgr:loadPlayerVehicles(player)
    local serial = getPlayerSerial(player)
    if not serial then return {} end
    local ok, rows = self:fetchAll("SELECT * FROM vehicles WHERE ownerSerial = ?", { serial })
    if not ok then
        outputDebugString("[vehicles_system] DB fetch error: "..tostring(rows), 2)
        return {}
    end
    local out = {}
    for _, r in ipairs(rows or {}) do
        local jengine = nil
        if type(r.engine) == "string" then
            -- engine stored as key or JSON; try to decode
            local decoded = pcall(fromJSON, r.engine) and fromJSON(r.engine) or r.engine
            jengine = decoded
        else
            jengine = r.engine
        end
        -- construct Vehicle object
        local vdata = {
            id = r.id,
            ownerSerial = r.ownerSerial,
            model = tonumber(r.model),
            vin = r.vin,
            regNumber = r.regNumber,
            brand = r.brand,
            modelName = r.modelName,
            mass = tonumber(r.mass) or 1200,
            engine = (type(jengine) == "string" and jengine) or (jengine and jengine.key) or r.engine,
            gearbox = (r.gearbox and pcall(fromJSON, r.gearbox) and fromJSON(r.gearbox)) or r.gearbox,
            fuelType = r.fuelType or (jengine and jengine.fuel) or "PB95",
            fuel = tonumber(r.fuel) or 50,
            fluids = (r.fluids and fromJSON(r.fluids)) or {},
            wear = (r.wear and fromJSON(r.wear)) or {},
            setups = (r.setups and fromJSON(r.setups)) or {},
            ecustate = (r.ecustate and fromJSON(r.ecustate)) or {},
            mileage = tonumber(r.mileage) or 0,
            odometer = tonumber(r.odometer) or 0,
            insurance = (r.insurance and fromJSON(r.insurance)) or {},
            inspection = (r.inspection and fromJSON(r.inspection)) or {},
            extra = (r.extra and fromJSON(r.extra)) or {},
            pos = { x = tonumber(r.posX) or 0, y = tonumber(r.posY) or 0, z = tonumber(r.posZ) or 3 },
            rot = { x = tonumber(r.rotX) or 0, y = tonumber(r.rotY) or 0, z = tonumber(r.rotZ) or 0 },
            isSpawned = tonumber(r.isSpawned) == 1
        }
        local obj = Vehicle:new(vdata)
        out[r.id] = obj
    end
    self.cache[serial] = out
    return out
end

-- Save vehicle instance to DB
function VehiclesMgr:saveVehicleToDB(vehicle)
    if not self.db or not vehicle or not vehicle.id then return false, "no_db_or_vehicle" end
    local s = vehicle:serializeForDB()
    local sql = [[
        UPDATE vehicles SET
            model=?, vin=?, regNumber=?, brand=?, modelName=?, mass=?,
            engine=?, gearbox=?, fuelType=?, fuel=?, fluids=?, wear=?, setups=?, ecustate=?,
            mileage=?, odometer=?, insurance=?, inspection=?, extra=?, posX=?, posY=?, posZ=?, rotX=?, rotY=?, rotZ=?, isSpawned=?
        WHERE id = ?
    ]]
    local params = {
        s.model, s.vin, s.regNumber, s.brand, s.modelName, s.mass,
        toJSON(s.engine), toJSON(s.gearbox), s.fuelType, s.fuel, toJSON(s.fluids), toJSON(s.wear), toJSON(s.setups), toJSON(s.ecustate),
        s.mileage, s.odometer, toJSON(s.insurance), toJSON(s.inspection), toJSON(s.extra),
        s.pos.x, s.pos.y, s.pos.z, s.rot.x, s.rot.y, s.rot.z, s.isSpawned and 1 or 0,
        s.id
    }
    local ok, res = self:execute(sql, params)
    if not ok then outputDebugString("[vehicles_system] saveVehicleToDB error: "..tostring(res), 2) end
    return ok, res
end

-- Create new DB entry and cache
function VehiclesMgr:createVehicle(player, model, opts)
    local serial = getPlayerSerial(player)
    if not serial then return false, "no_serial" end
    opts = opts or {}
    local v = Vehicle:new({
        owner = serial,
        model = model,
        brand = opts.brand or "Brand",
        modelName = opts.modelName or "Model",
        mass = opts.mass or 1200,
        engine = opts.engine or "R4_1.2",
        gearbox = opts.gearbox or GEARBOX_PRESETS.manual,
        fuelType = opts.fuelType,
        fuel = opts.fuel or 50,
        pos = opts.pos,
    })
    local sql = [[
        INSERT INTO vehicles (ownerSerial, model, vin, regNumber, brand, modelName, mass, engine, gearbox, fuelType, fuel, fluids, wear, setups, ecustate, mileage, odometer, insurance, inspection, extra, posX,posY,posZ, rotX,rotY,rotZ, isSpawned)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    local sData = v:serializeForDB()
    local params = {
        serial, sData.model, sData.vin, sData.regNumber, sData.brand, sData.modelName, sData.mass,
        toJSON(sData.engine), toJSON(sData.gearbox), sData.fuelType, sData.fuel,
        toJSON(sData.fluids), toJSON(sData.wear), toJSON(sData.setups), toJSON(sData.ecustate),
        sData.mileage, sData.odometer, toJSON(sData.insurance), toJSON(sData.inspection), toJSON(sData.extra),
        sData.pos.x, sData.pos.y, sData.pos.z, sData.rot.x, sData.rot.y, sData.rot.z, sData.isSpawned and 1 or 0
    }
    local ok, res = self:execute(sql, params)
    if not ok then return false, res end
    local insertedId = res.insertId or res.lastInsertId or false
    if insertedId then
        v.id = insertedId
        self.cache[serial] = self.cache[serial] or {}
        self.cache[serial][insertedId] = v
        return true, v
    end
    return false, "insert_failed"
end

-- Spawn a vehicle element for player
function VehiclesMgr:spawnVehicle(player, vehicleId)
    local serial = getPlayerSerial(player)
    if not serial then return false, "no_serial" end
    local list = self.cache[serial] or self:loadPlayerVehicles(player)
    local v = list[vehicleId]
    if not v then return false, "not_found" end
    if v.isSpawned then return false, "already_spawned" end
    local vehElem = createVehicle(v.model, v.pos.x, v.pos.y, v.pos.z, v.rot.x, v.rot.y, v.rot.z)
    if not vehElem then return false, "create_failed" end
    setElementData(vehElem, "vehicleID", v.id, false)
    setElementData(vehElem, "ownerSerial", v.ownerSerial, false)
    setElementData(vehElem, "fuel", v.fuel, false)
    setElementData(vehElem, "wear", v.wear, false)
    setElementData(vehElem, "engine", v.engine, false)
    setElementData(vehElem, "ecustate", v.ecustate, false)
    self.spawnIndex[v.id] = vehElem
    v.isSpawned = true
    self:saveVehicleToDB(v)
    return true, vehElem
end

-- Despawn: save + destroy
function VehiclesMgr:despawnVehicle(player, vehicleId)
    local serial = getPlayerSerial(player)
    if not serial then return false, "no_serial" end
    local v = (self.cache[serial] or {})[vehicleId]
    if not v then return false, "not_found" end
    local elem = self.spawnIndex[vehicleId]
    if elem and isElement(elem) then
        -- update pos/rot before save
        local x,y,z = getElementPosition(elem)
        local rx,ry,rz = getElementRotation(elem)
        v.pos = { x=x,y=y,z=z }
        v.rot = { x=rx,y=ry,z=rz }
        v.fuel = getElementData(elem, "fuel") or v.fuel
        v.wear = getElementData(elem, "wear") or v.wear
        v.isSpawned = false
        self:saveVehicleToDB(v)
        destroyElement(elem)
        self.spawnIndex[vehicleId] = nil
        return true
    else
        v.isSpawned = false
        self:saveVehicleToDB(v)
        return true
    end
end

-- Simulation tick
function VehiclesMgr:simulateTick()
    for serial, list in pairs(self.cache) do
        for id, v in pairs(list) do
            if v.isSpawned then
                local vehElem = self.spawnIndex[id]
                if vehElem and isElement(vehElem) then
                    local speed = (function()
                        local vx,vy,vz = getElementVelocity(vehElem)
                        local sp = math.sqrt(vx*vx + vy*vy + vz*vz) * 50 -- approximate
                        return sp
                    end)()
                    local throttle = 0.5
                    local driver = getVehicleOccupant(vehElem, 0)
                    if driver and isElement(driver) then throttle = 0.8 end
                    -- fuel consumption
                    local lps = v:calcFuelConsumption(speed, throttle)
                    local dt = self.tickInterval / 1000
                    v.fuel = math.max(0, (v.fuel or 0) - lps * dt)
                    -- wear
                    v:applyWear(speed, throttle, dt)
                    -- update element data
                    setElementData(vehElem, "fuel", v.fuel, false)
                    setElementData(vehElem, "wear", v.wear, false)
                    setElementData(vehElem, "ecustate", v.ecustate, false)
                    setElementData(vehElem, "mileage", v.mileage, false)
                    -- small autosave of dynamic fields
                    self:execute("UPDATE vehicles SET fuel=?, mileage=?, odometer=?, wear=? WHERE id = ?", {
                        v.fuel, v.mileage, v.odometer, toJSON(v.wear), id
                    })
                    -- risk of damage if very low oil or low wear
                    local oilAgeDays = math.floor((os.time() - (v.fluids.engine_oil.lastChange or os.time())) / 86400)
                    if oilAgeDays > 365 and math.random() < 0.0008 then
                        v.wear.engine = math.max(0, v.wear.engine - 1)
                        triggerEvent("onVehicleEngineStress", vehElem, id)
                    end
                end
            end
        end
    end
end

-- start/stop simulation
function VehiclesMgr:start()
    if self.tickTimer and isTimer(self.tickTimer) then killTimer(self.tickTimer) end
    self.tickTimer = setTimer(function() self:simulateTick() end, self.tickInterval, 0)
end
function VehiclesMgr:stop()
    if self.tickTimer and isTimer(self.tickTimer) then killTimer(self.tickTimer); self.tickTimer = nil end
end

-- save all cached vehicles (resource stop)
function VehiclesMgr:saveAll()
    for serial, list in pairs(self.cache) do
        for id, v in pairs(list) do
            -- if spawned, attempt to save element state
            if v.isSpawned and self.spawnIndex[id] and isElement(self.spawnIndex[id]) then
                local e = self.spawnIndex[id]
                local x,y,z = getElementPosition(e)
                local rx,ry,rz = getElementRotation(e)
                v.pos = { x=x,y=y,z=z }
                v.rot = { x=rx,y=ry,z=rz }
                v.fuel = getElementData(e, "fuel") or v.fuel
                v.wear = getElementData(e, "wear") or v.wear
                v.isSpawned = 1
            else
                v.isSpawned = 0
            end
            self:saveVehicleToDB(v)
        end
    end
end

-- service API wrappers (validate owner)
function VehiclesMgr:_getVehicleIfOwner(player, vehicleId)
    local serial = getPlayerSerial(player)
    if not serial then return nil, "no_serial" end
    local v = (self.cache[serial] or {})[vehicleId]
    if not v then return nil, "not_owner_or_not_found" end
    return v
end

function VehiclesMgr:serviceChangeOil(player, vehicleId, oilType)
    local v, err = self:_getVehicleIfOwner(player, vehicleId)
    if not v then return false, err end
    local ok = v:changeOil(oilType)
    if ok then self:saveVehicleToDB(v) end
    return ok
end

function VehiclesMgr:serviceReplacePart(player, vehicleId, part)
    local v, err = self:_getVehicleIfOwner(player, vehicleId)
    if not v then return false, err end
    local ok = v:replacePart(part)
    if ok then self:saveVehicleToDB(v) end
    return ok
end

function VehiclesMgr:serviceRefuel(player, vehicleId, amount, fuelType)
    local v, err = self:_getVehicleIfOwner(player, vehicleId)
    if not v then return false, err end
    local ok, res = v:refuel(amount, fuelType)
    if ok then self:saveVehicleToDB(v) end
    return ok, res
end

function VehiclesMgr:serviceChangeFuelType(player, vehicleId, newType)
    local v, err = self:_getVehicleIfOwner(player, vehicleId)
    if not v then return false, err end
    local ok, res = v:changeFuelType(newType)
    if ok then self:saveVehicleToDB(v) end
    return ok, res
end

function VehiclesMgr:serviceTuneECU(player, vehicleId, mapTable)
    local v, err = self:_getVehicleIfOwner(player, vehicleId)
    if not v then return false, err end
    local ok = v:tuneECU(mapTable)
    if ok then
        self:saveVehicleToDB(v)
        local elem = self.spawnIndex[vehicleId]
        if elem and isElement(elem) then
            triggerClientEvent(player, "vehicles:onTuned", player, vehicleId, v.ecustate)
        end
    end
    return ok
end

-- Exports for other resources
function VehiclesMgr:getVehicle(vehicleId)
    for serial, list in pairs(self.cache) do
        if list[vehicleId] then return list[vehicleId] end
    end
    return nil
end

-- Initialization
local VM = VehiclesMgr.new()
VM:initDB()
VM:start()

addEventHandler("onResourceStop", resourceRoot, function() VM:saveAll(); VM:stop() end)

-- Player events
addEventHandler("onPlayerJoin", root, function()
    -- nothing automatic; load on demand to save memory
end)

-- Command examples for admin/test
addCommandHandler("vcreate", function(player, cmd, model)
    model = tonumber(model) or 411
    local ok, res = VM:createVehicle(player, model, { brand="UserBrand", modelName="UserModel", engine="R4_1.6" })
    if ok then outputChatBox("Vehicle created ID:"..res.id, player) else outputChatBox("Create failed: "..tostring(res), player) end
end)

addCommandHandler("vspawn", function(player, cmd, id)
    if not id then outputChatBox("Usage: /vspawn [id]", player) return end
    local ok, res = VM:spawnVehicle(player, tonumber(id))
    if ok then outputChatBox("Spawned vehicle: "..tostring(id), player) else outputChatBox("Spawn failed: "..tostring(res), player) end
end)

addCommandHandler("vpark", function(player, cmd, id)
    if not id then outputChatBox("Usage: /vpark [id]", player) return end
    local ok, res = VM:despawnVehicle(player, tonumber(id))
    if ok then outputChatBox("Vehicle parked: "..tostring(id), player) else outputChatBox("Park failed: "..tostring(res), player) end
end)

addCommandHandler("vdiag", function(player, cmd, id)
    if not id then outputChatBox("Usage: /vdiag [id]", player) return end
    local v = VM:getVehicle(tonumber(id))
    if not v then outputChatBox("Vehicle not found.", player); return end
    local perf = v:calculatePerformance()
    outputChatBox(("VIN:%s HP:%d Fuel:%.2f WearEngine:%.2f Mileage:%.2f"):format(v.vin, perf, v.fuel, v.wear.engine, v.mileage), player)
end)

-- Remote events (client -> server)
addEvent("vehicles:requestDiagnostics", true)
addEventHandler("vehicles:requestDiagnostics", root, function(player, vehicleId)
    local v = VM:getVehicle(tonumber(vehicleId))
    if not v then triggerClientEvent(player, "vehicles:receiveDiagnostics", player, { error="not_found" }); return end
    triggerClientEvent(player, "vehicles:receiveDiagnostics", player, {
        id = v.id, vin = v.vin, reg = v.regNumber, engine = v.engine, fuel = v.fuel,
        fuelType = v.fuelType, wear = v.wear, fluids = v.fluids, ecustate = v.ecustate, mileage = v.mileage
    })
end)

addEvent("vehicles:serviceChangeOil", true)
addEventHandler("vehicles:serviceChangeOil", root, function(player, vehicleId, oilType)
    local ok, err = VM:serviceChangeOil(player, tonumber(vehicleId), oilType)
    triggerClientEvent(player, "vehicles:serviceResult", player, ok and true or false, err or "ok")
end)

addEvent("vehicles:serviceReplacePart", true)
addEventHandler("vehicles:serviceReplacePart", root, function(player, vehicleId, part)
    local ok, err = VM:serviceReplacePart(player, tonumber(vehicleId), part)
    triggerClientEvent(player, "vehicles:serviceResult", player, ok and true or false, err or "ok")
end)

addEvent("vehicles:serviceRefuel", true)
addEventHandler("vehicles:serviceRefuel", root, function(player, vehicleId, amount, fuelType)
    local ok, res = VM:serviceRefuel(player, tonumber(vehicleId), tonumber(amount), fuelType)
    triggerClientEvent(player, "vehicles:serviceResult", player, ok and true or false, res or "ok")
end)

addEvent("vehicles:serviceChangeFuelType", true)
addEventHandler("vehicles:serviceChangeFuelType", root, function(player, vehicleId, newType)
    local ok, res = VM:serviceChangeFuelType(player, tonumber(vehicleId), newType)
    triggerClientEvent(player, "vehicles:serviceResult", player, ok and true or false, res or "ok")
end)

addEvent("vehicles:serviceTuneECU", true)
addEventHandler("vehicles:serviceTuneECU", root, function(player, vehicleId, mapTable)
    local ok, res = VM:serviceTuneECU(player, tonumber(vehicleId), mapTable)
    triggerClientEvent(player, "vehicles:serviceResult", player, ok and true or false, res or "ok")
end)

-- Exports
function getVehicleSystem() return VM end
exports("getVehicleSystem", getVehicleSystem)
_G.getVehicleSystem = getVehicleSystem
