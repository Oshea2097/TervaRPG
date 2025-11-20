local screenW, screenH = guiGetScreenSize()
local showHUD = true

-- Wyłączenie standardowego HUD
addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, comp in ipairs({"radar", "health", "armour", "money", "clock", "weapon", "ammo", "vehicle_name"}) do
        setPlayerHudComponentVisible(comp, false)
    end
end)

-- Czcionka
local honeySalt = dxCreateFont("fonts/honey-salt.ttf", 20)
local iconHP = dxCreateTexture("img/heart.png")
local iconArmour = dxCreateTexture("img/armour.png")

-- Mapa do radaru
local mapImage = dxCreateTexture("img/map.jpg") -- 3000x3000 najlepiej
local mapSize = 3000

bindKey("F5", "down", function()
    showHUD = not showHUD
end)

-- FPS stabilizator
local fps = 60
local lastTick = getTickCount()
addEventHandler("onClientRender", root, function()
    local tick = getTickCount()
    fps = math.floor(1000 / (tick - lastTick))
    lastTick = tick
end)

---------------------------------------
-- RADAR FUNKCJE
---------------------------------------
local function worldToMap(x, y)
    return (x + 3000) / 6000 * mapSize, mapSize - (y + 3000) / 6000 * mapSize
end

---------------------------------------
-- RENDER
---------------------------------------
addEventHandler("onClientRender", root, function()
    if not showHUD then return end

    ---------------------------------------
    -- RADAR LEWY DÓŁ
    ---------------------------------------

    local radarSize = 220
    local radarX = 20
    local radarY = screenH - radarSize - 60

    local px, py = getElementPosition(localPlayer)
    local camRotZ = select(3, getElementRotation(getCamera()))

    local mapX, mapY = worldToMap(px, py)

    dxDrawRectangle(radarX, radarY, radarSize, radarSize, tocolor(0, 0, 0, 140))

    dxDrawImageSection(
        radarX, radarY,
        radarSize, radarSize,
        mapX - 50, mapY - 50,
        100, 100,
        mapImage,
        -camRotZ
    )

    -- Gracz
    dxDrawLine(
        radarX + radarSize/2, radarY + radarSize/2,
        radarX + radarSize/2, radarY + radarSize/2 - 10,
        tocolor(255, 0, 0, 220), 2
    )
    dxDrawCircle(radarX + radarSize/2, radarY + radarSize/2, 3, 0, 360, tocolor(255,255,255,230))

    dxDrawText(
        "FPS: "..fps.." | Ping: "..getPlayerPing(localPlayer).."ms",
        radarX + 5, radarY + radarSize + 10,
        0, 0, tocolor(255,255,255,200), 0.85, honeySalt
    )

    ---------------------------------------
    -- HUD PRAWY GÓRNY
    ---------------------------------------

    local hudW, hudH = 350, 230
    local hudX = screenW - hudW - 30
    local hudY = 30

    dxDrawRectangle(hudX, hudY, hudW, hudH, tocolor(0, 0, 0, 150))

    local hp = getElementHealth(localPlayer) or 100
    local arm = getPedArmor(localPlayer) or 0
    local money = getPlayerMoney(localPlayer) or 0
    local nick = getPlayerName(localPlayer)

    -- HP
    dxDrawImage(hudX + 20, hudY + 25, 26, 26, iconHP)
    dxDrawRectangle(hudX + 55, hudY + 30, 250, 12, tocolor(50,50,50,200))
    dxDrawRectangle(hudX + 55, hudY + 30, 250 * (hp / 100), 12, tocolor(0, 130, 255, 220))

    -- ARMOUR
    dxDrawImage(hudX + 20, hudY + 65, 26, 26, iconArmour)
    dxDrawRectangle(hudX + 55, hudY + 70, 250, 12, tocolor(50,50,50,200))
    dxDrawRectangle(hudX + 55, hudY + 70, 250 * (arm / 100), 12, tocolor(180,180,180,220))

    -- MONEY
    dxDrawText("$ "..money, hudX + 20, hudY + 115, 0, 0, tocolor(255,255,255,255), 1.2, honeySalt)

    -- NICK
    dxDrawText("NICK: "..nick, hudX + 20, hudY + 155, 0, 0, tocolor(230,230,230,255), 1.0, honeySalt)

    -- DATE + TIME
    local rt = getRealTime()
    local hour = string.format("%02d", rt.hour)
    local minute = string.format("%02d", rt.minute)
    local day = string.format("%02d", rt.monthday)
    local month = string.format("%02d", rt.month + 1)
    local year = rt.year + 1900

    dxDrawText(day.."."..month.."."..year, hudX + 20, hudY + 195, 0, 0, tocolor(210,210,210,255), 0.9, honeySalt)
    dxDrawText(hour..":"..minute, hudX + hudW - 80, hudY + 195, 0, 0, tocolor(210,210,210,255), 0.9, honeySalt)
end)
