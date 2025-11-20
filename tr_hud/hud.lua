local screenW, screenH = guiGetScreenSize()
local showHUD = true

-- Czcionka
local honeySalt = dxCreateFont("fonts/honey-salt.ttf", 18, false, "antialiased")

-- Ikony
local iconHP = dxCreateTexture("img/heart.png")
local iconArmour = dxCreateTexture("img/armour.png")

-- Przełączanie HUD (F5)
bindKey("F5", "down", function()
    showHUD = not showHUD
end)

addEventHandler("onClientRender", root, function()
    if not showHUD then return end

    local hp = getElementHealth(localPlayer)
    local armour = getPedArmor(localPlayer)
    local money = getPlayerMoney(localPlayer)
    local nick = getPlayerName(localPlayer)
    local date = getRealTime()

    local day = string.format("%02d", date.monthday)
    local month = string.format("%02d", date.month + 1)
    local year = date.year + 1900
    local hour = string.format("%02d", date.hour)
    local minute = string.format("%02d", date.minute)

    local fps = getFPS()
    local ping = getPlayerPing(localPlayer)

    ---------------------------
    -- RADAR LEWY DÓŁ
    ---------------------------

    -- Pozycja radaru
    local radarSize = 220
    local radarX = 20
    local radarY = screenH - radarSize - 60

    -- Tło radaru
    dxDrawRectangle(radarX, radarY, radarSize, radarSize, tocolor(0, 0, 0, 120), true)

    -- FPS/PING pod radarem
    dxDrawText("FPS: "..fps.."  |  Ping: "..ping.."ms", radarX + 5, radarY + radarSize + 10, 0, 0, tocolor(255,255,255,180), 1, honeySalt)

    ---------------------------
    -- HUD PRAWY GÓRNY
    ---------------------------

    local hudW, hudH = 350, 230
    local hudX = screenW - hudW - 30
    local hudY = 30

    dxDrawRectangle(hudX, hudY, hudW, hudH, tocolor(0, 0, 0, 130))

    -- HP
    dxDrawImage(hudX + 20, hudY + 25, 24, 24, iconHP)
    dxDrawRectangle(hudX + 50, hudY + 30, 250, 12, tocolor(50, 50, 50, 150))
    dxDrawRectangle(hudX + 50, hudY + 30, 250 * (hp / 100), 12, tocolor(0, 130, 255, 200))

    -- Armour
    dxDrawImage(hudX + 20, hudY + 65, 24, 24, iconArmour)
    dxDrawRectangle(hudX + 50, hudY + 70, 250, 12, tocolor(50, 50, 50, 150))
    dxDrawRectangle(hudX + 50, hudY + 70, 250 * (armour / 100), 12, tocolor(180, 180, 180, 200))

    -- Kasa
    dxDrawText("$ "..money, hudX + 20, hudY + 110, 0, 0, tocolor(255,255,255,255), 1.1, honeySalt)

    -- Nick
    dxDrawText("NICK: "..nick, hudX + 20, hudY + 150, 0, 0, tocolor(220,220,220,255), 0.9, honeySalt)

    -- Data i godzina
    dxDrawText(day.."."..month.."."..year, hudX + 20, hudY + 185, 0, 0, tocolor(200,200,200,255), 0.9, honeySalt)
    dxDrawText(hour..":"..minute, hudX + hudW - 80, hudY + 185, 0, 0, tocolor(200,200,200,255), 0.9, honeySalt)
end)

-- FPS detection
local fps = 60
local fpsTick = getTickCount()

function getFPS()
    if getTickCount() - fpsTick >= 1000 then
        fps = getPerformanceStats("FPS") or fps
        fpsTick = getTickCount()
    end
    return fps
end
