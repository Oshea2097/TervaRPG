Vehicle = {}
Vehicle.__index = Vehicle

local json = { toJSON = toJSON, fromJSON = fromJSON } -- MTA native

-- util: random power/torque from preset range
local function pickPowerTorque(preset)
    local hp = preset.hp_min + math.random() * (preset.hp_max - preset.hp_min)
    local nm = preset.nm_min + math.random() * (preset.nm_max - preset.nm_min)
    return math.floor(hp), math.floor(nm)
end

-- constructor (data can be partial)
function Vehicle:new(data)
    local self = setmetatable({}, Vehicle)
    self.id = data.id or nil
    self.ownerSerial = data.ownerSerial or data.owner or "unknown"
    self.model = data.model or 411
    self.brand = data.brand or data.brand or "Generic"
    self.modelName = data.modelName or "Model"
    self.mass = tonumber(data.mass) or 1200
    -- engine object: reference preset or inline
    if type(data.engine) == "string" and ENGINE_PRESETS[data.engine] then
        local p = ENGINE_PRESETS[data.engine]
        local hp, nm = pickPowerTorque(p)
        self.engineKey = data.engine
        self.engine = {
            key = data.engine,
            family = p.family,
            capacity = p.capacity,
            hp = hp,
            nm = nm,
            fuel = p.fuel
        }
    else
        self.engineKey = data.engineKey or data.engine and data.engine.key or "R4_1.6"
        self.engine = data.engine or ENGINE_PRESETS[self.engineKey] and {
            key = self.engineKey,
            family = ENGINE_PRESETS[self.engineKey].family,
            capacity = ENGINE_PRESETS[self.engineKey].capacity,
            hp, nm = pickPowerTorque(ENGINE_PRESETS[self.engineKey])
        } or { key="custom", capacity = data.capacity or 1.6, hp = data.hp or 100, nm = data.nm or 140, fuel = data.fuel or "PB95" }
    end

    -- gearbox
    self.gearbox = data.gearbox or GEARBOX_PRESETS.manual
    -- fuel
    self.fuelType = data.fuelType or (self.engine and self.engine.fuel) or "PB95"
    self.fuel = tonumber(data.fuel) or 50.0 -- percent / liters depending on how you treat tanks; we'll treat as liters for now
    -- fluids
    self.fluids = data.fluids or {
        engine_oil = { type = FLUID_TYPES.engine_oil.common, lastChange = os.time() },
        gearbox_oil = { type = FLUID_TYPES.gearbox_oil.common, lastChange = os.time() },
        brake_fluid = { type = FLUID_TYPES.brake_fluid.common, lastChange = os.time() },
        coolant = { type = FLUID_TYPES.coolant.common, lastChange = os.time() },
        washer = { type = FLUID_TYPES.washer.common, lastChange = os.time() },
        powersteer = { type = FLUID_TYPES.powersteer.common, lastChange = os.time() },
    }
    -- wear percent (100 = new)
    self.wear = data.wear or { engine = 100, clutch = 100, timingBelt = 100, turbo = 100, brakes = 100, suspension = 100 }
    self.setups = data.setups or {}
    self.ecustate = data.ecustate or { map = "stock", afr = 14.7, ignition = 0, tuned = false }
    self.mileage = tonumber(data.mileage) or 0
    self.odometer = tonumber(data.odometer) or 0
    self.insurance = data.insurance or {}
    self.inspection = data.inspection or {}
    self.extra = data.extra or {}
    self.vin = data.vin or ("VIN"..tostring(math.random(100000,999999)))
    self.regNumber = data.regNumber or ("PL"..tostring(math.random(1000,9999)))
    self.pos = data.pos or { x=0, y=0, z=3 }
    self.rot = data.rot or { x=0, y=0, z=0 }
    self.isSpawned = data.isSpawned or false
    return self
end

-- calculate an approximate performance number adjusted by wear and ECU
function Vehicle:calculatePerformance()
    local baseHP = tonumber(self.engine.hp) or 100
    local wearFactor = (self.wear.engine or 100) / 100
    local tuneMult = (self.ecustate and self.ecustate.tuned) and (1 + (self.ecustate.powerIncrease or 0)/100) or 1.0
    local fuelMult = FUEL_MULT[self.fuelType] or 1.0
    local effective = math.floor(baseHP * wearFactor * tuneMult * (1 / fuelMult))
    return effective
end

-- calculate instantaneous fuel consumption (liters per second) given speed km/h and throttle 0..1
function Vehicle:calcFuelConsumption(speedKmh, throttle)
    throttle = throttle or 0.5
    local disp = tonumber(self.engine.capacity) or 1.6
    local base_l_per_100 = BASE_CONSUMPTION_L_PER_100KM + disp * 3 + (self.ecustate.tuned and 2 or 0)
    local speedFactor = 1 + math.max(0, (speedKmh - 80) / 200)
    local throttleFactor = 0.5 + throttle
    local ft = FUEL_MULT[self.fuelType] or 1.0
    local l100 = base_l_per_100 * speedFactor * throttleFactor * ft
    local lps = (l100 * math.max(1, speedKmh)) / 3600
    if speedKmh < 1 then lps = math.max(0.0004, lps * 0.2) end
    return lps
end

-- apply wear for dt_seconds given speed and throttle
function Vehicle:applyWear(speedKmh, throttle, dt_seconds)
    local km_driven = (speedKmh * (dt_seconds/3600))
    self.mileage = self.mileage + km_driven
    self.odometer = self.odometer + km_driven
    local baseWear = WEAR_BASE_PER_KM * km_driven * 100 -- percent scale
    local throttleFactor = 1 + throttle
    -- engine wear
    self.wear.engine = math.max(0, (self.wear.engine or 100) - baseWear * throttleFactor)
    -- clutch wear heavier for manual on starts etc (we approximate)
    if (self.gearbox and self.gearbox.clutchWearFactor) then
        local cDelta = baseWear * (self.gearbox.clutchWearFactor or 1.0) * (throttle*2)
        self.wear.clutch = math.max(0, (self.wear.clutch or 100) - cDelta)
    end
    -- brakes wear by high speed braking (approx)
    if speedKmh > 80 then self.wear.brakes = math.max(0, (self.wear.brakes or 100) - baseWear * 0.5) end
    -- turbo wear when present and high throttle
    if self.engineKey and string.find(self.engineKey:lower(),"turbo") and throttle > 0.7 then
        self.wear.turbo = math.max(0, (self.wear.turbo or 100) - baseWear * 0.8)
    end
end

-- service functions
function Vehicle:refuel(amount, fuelType)
    if fuelType and fuelType ~= self.fuelType then
        return false, "wrong_fuel_type"
    end
    self.fuel = (self.fuel or 0) + tonumber(amount)
    return true, self.fuel
end

function Vehicle:changeOil(fluidType)
    if not FLUID_TYPES[fluidType] then return false, "unknown_fluid" end
    self.fluids.engine_oil = { type = fluidType, lastChange = os.time() }
    return true
end

function Vehicle:replacePart(part)
    if self.wear[part] == nil then return false, "no_part" end
    self.wear[part] = 100
    return true
end

function Vehicle:changeFuelType(newType)
    if not FUEL_MULT[newType] then return false, "invalid_fuel" end
    self.fuelType = newType
    return true
end

function Vehicle:tuneECU(mapTable)
    for k,v in pairs(mapTable) do self.ecustate[k]=v end
    self.ecustate.tuned = true
    -- small immediate wear penalty
    self.wear.engine = math.max(0, (self.wear.engine or 100) - (mapTable.powerIncrease and (mapTable.powerIncrease * 0.2) or 1))
    return true
end

-- serialization helpers for DB
function Vehicle:serializeForDB()
    return {
        id = self.id,
        ownerSerial = self.ownerSerial,
        model = self.model,
        vin = self.vin,
        regNumber = self.regNumber,
        brand = self.brand,
        modelName = self.modelName,
        mass = self.mass,
        engine = self.engineKey or self.engine,
        gearbox = self.gearbox,
        fuelType = self.fuelType,
        fuel = self.fuel,
        fluids = self.fluids,
        wear = self.wear,
        setups = self.setups,
        ecustate = self.ecustate,
        mileage = self.mileage,
        odometer = self.odometer,
        insurance = self.insurance,
        inspection = self.inspection,
        extra = self.extra,
        pos = self.pos,
        rot = self.rot,
        isSpawned = self.isSpawned
    }
end


ENGINE_PRESETS = {
    -- BOXERS
    ["B4_1.6"]    = { family="B4", capacity=1.6, hp_min=90, hp_max=120, nm_min=130, nm_max=160, fuel="PB95" },
    ["B4_2.0"]    = { family="B4", capacity=2.0, hp_min=150, hp_max=300, nm_min=200, nm_max=400, fuel="PB95" },
    ["B4_2.5_T"]  = { family="B4 Turbo", capacity=2.5, hp_min=250, hp_max=350, nm_min=350, nm_max=450, fuel="PB98" },
    ["B6_3.0"]    = { family="B6", capacity=3.0, hp_min=230, hp_max=320, nm_min=300, nm_max=400, fuel="PB98" },
    ["B6_3.6_T"]  = { family="B6 Turbo", capacity=3.6, hp_min=400, hp_max=580, nm_min=500, nm_max=700, fuel="PB98" },

    -- WANKEL
    ["WANKEL_0.65_1R"] = { family="Wankel-1R", capacity=0.65, hp_min=100, hp_max=150, nm_min=130, nm_max=160, fuel="PB98" },
    ["WANKEL_1.3_2R"]  = { family="Wankel-2R", capacity=1.3, hp_min=150, hp_max=280, nm_min=180, nm_max=230, fuel="PB98" },
    ["WANKEL_1.3_2R_T"]= { family="Wankel-2R Turbo", capacity=1.3, hp_min=230, hp_max=350, nm_min=250, nm_max=300, fuel="PB98" },
    ["WANKEL_2.0_3R_T"]= { family="Wankel-3R Turbo", capacity=2.0, hp_min=350, hp_max=450, nm_min=400, nm_max=450, fuel="PB98" },
    ["WANKEL_2.6_4R_T"]= { family="Wankel-4R Turbo", capacity=2.6, hp_min=500, hp_max=900, nm_min=500, nm_max=900, fuel="PB98" },

    -- PETROL (R/V types)
    ["R3_1.0"]   = { family="R3", capacity=1.0, hp_min=70, hp_max=120, nm_min=100, nm_max=180, fuel="PB95" },
    ["R4_1.2"]   = { family="R4", capacity=1.2, hp_min=80, hp_max=130, nm_min=120, nm_max=200, fuel="PB95" },
    ["R4_1.4_T"] = { family="R4 Turbo", capacity=1.4, hp_min=120, hp_max=180, nm_min=200, nm_max=250, fuel="PB98" },
    ["R4_1.6_T"] = { family="R4 Turbo", capacity=1.6, hp_min=150, hp_max=220, nm_min=240, nm_max=320, fuel="PB98" },
    ["R4_2.0_T"] = { family="R4 Turbo", capacity=2.0, hp_min=200, hp_max=320, nm_min=300, nm_max=450, fuel="PB98" },
    ["R5_2.5_T"] = { family="R5 Turbo", capacity=2.5, hp_min=340, hp_max=420, nm_min=450, nm_max=500, fuel="PB98" },

    ["V6_3.0"]   = { family="V6", capacity=3.0, hp_min=220, hp_max=400, nm_min=300, nm_max=550, fuel="PB98" },
    ["V8_4.0_T"] = { family="V8", capacity=4.0, hp_min=450, hp_max=650, nm_min=600, nm_max=850, fuel="PB98" },
    ["V8_5.0"]   = { family="V8", capacity=5.0, hp_min=400, hp_max=500, nm_min=500, nm_max=600, fuel="PB98" },
    ["V8_6.2"]   = { family="V8", capacity=6.2, hp_min=450, hp_max=700, nm_min=600, nm_max=900, fuel="PB98" },
    ["V10_5.0"]  = { family="V10", capacity=5.0, hp_min=500, hp_max=630, nm_min=500, nm_max=600, fuel="PB98" },
    ["V12_6.0"]  = { family="V12", capacity=6.0, hp_min=700, hp_max=830, nm_min=700, nm_max=750, fuel="PB98" },

    -- DIESEL
    ["D_1.3_T"]  = { family="Diesel R4 Turbo", capacity=1.3, hp_min=70, hp_max=95, nm_min=180, nm_max=200, fuel="ON" },
    ["D_1.5_T"]  = { family="Diesel R4 Turbo", capacity=1.5, hp_min=75, hp_max=110, nm_min=180, nm_max=260, fuel="ON" },
    ["D_1.6_T"]  = { family="Diesel R4 Turbo", capacity=1.6, hp_min=90, hp_max=120, nm_min=230, nm_max=270, fuel="ON" },
    ["D_1.9_T"]  = { family="Diesel R4 Turbo", capacity=1.9, hp_min=90, hp_max=150, nm_min=210, nm_max=320, fuel="ON" },
    ["D_2.0_T"]  = { family="Diesel R4 Turbo", capacity=2.0, hp_min=110, hp_max=240, nm_min=250, nm_max=500, fuel="ON" },
    ["D_2.2_T"]  = { family="Diesel R4 Turbo", capacity=2.2, hp_min=130, hp_max=200, nm_min=300, nm_max=450, fuel="ON" },
    ["D_2.5_T"]  = { family="Diesel R4 Turbo", capacity=2.5, hp_min=140, hp_max=190, nm_min=350, nm_max=450, fuel="ON" },
    ["D_V6_3.0_T"]= { family="Diesel V6 Turbo", capacity=3.0, hp_min=200, hp_max=300, nm_min=500, nm_max=700, fuel="ON" },
    ["D_V8_4.0"] = { family="Diesel V8 Turbo", capacity=4.0, hp_min=320, hp_max=400, nm_min=750, nm_max=900, fuel="ON" },
    ["D_BIG_6.7"]= { family="Diesel R6/V8 Turbo", capacity=6.7, hp_min=350, hp_max=475, nm_min=900, nm_max=1300, fuel="ON" },
}

-- Fuel multipliers (affect consumption/performance)
FUEL_MULT = {
    PB95 = 1.0,
    PB98 = 0.98,
    E85  = 0.92,
    LPG  = 1.08,
    ON   = 1.05
}

GEARBOX_PRESETS = {
    manual  = { name="manual", gears=5, clutchWearFactor=1.0 },
    manual6 = { name="manual6", gears=6, clutchWearFactor=1.0 },
    semi    = { name="semi-auto", gears=6, clutchWearFactor=0.6 },
    auto4   = { name="automatic4", gears=4, clutchWearFactor=0.2 },
    auto6   = { name="automatic6", gears=6, clutchWearFactor=0.2 },
}

FLUID_TYPES = {
    engine_oil = { common="5w30", change_interval_days = 180 },
    gearbox_oil = { common="75w90", change_interval_days = 365 },
    brake_fluid = { common="DOT4", change_interval_days = 365*2 },
    coolant = { common="G12", change_interval_days = 365*2 },
    washer = { common="water", change_interval_days = 365*5 },
    powersteer = { common="ATF", change_interval_days = 365*2 },
}

-- Base consumption constants
BASE_CONSUMPTION_L_PER_100KM = 5 -- baseline for small engines, scaled by displacement
WEAR_BASE_PER_KM = 0.0005 -- base wear percent per km


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
