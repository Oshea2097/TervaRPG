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
