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
