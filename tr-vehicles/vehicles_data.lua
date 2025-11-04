
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
