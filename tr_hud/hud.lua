local screenW, screenH = guiGetScreenSize()
local showHUD = true

local honeySalt = dxCreateFont("fonts/honey-salt.ttf", 18, false, "antialiased")
local iconHP = dxCreateTexture("img/heart.png")
local iconArmour = dxCreateTexture("img/armour.png")

bindKey("F5", "down", function()
    showHUD = not showHUD
end)

function getFPS()
    return getElementData(localPlayer, "fps") or 60
end

addEventHandler("onClientRender", root, function()
    if not showHUD then return end

    local hp = getElementHealth(localPlayer) or 100
    local armour = getPedArmor(localPlayer) or 0
    local money = getPlayerMoney(localPlayer) or 0
    local nick = getPlayerName(localPlayer) or "Unknown"

    local time = getRealTime()
    local hour = string.format("%02d", time.hour)
    local minute = string.format("%02d", time.minute)
    local day = string.format("%02d", time.monthday)
    local month = string.format("%02d", time.month + 1)
    local year = time.year + 1900

    local fps = getFPS()
    local ping = getPlayerPing(localPlayer)

    ---------------------------------------
    -- RADAR (placeholder, na razie prostokąt)
    ---------------------------------------

    local radarSize = 220
    local radarX = 20
    local radarY = screenH - radarSize - 60

    dxDrawRectangle(radarX, radarY, radarSize, radarSize, tocolor(0, 0, 0, 120), true)

    dxDrawText("FPS: "..fps.." | Ping: "..ping.."ms", radarX + 5, radarY + radarSize + 10, 0, 0, tocolor(255,255,255,200), 0.85, honeySalt)

    ---------------------------------------
    -- HUD PRAWY GÓRNY
    ---------------------------------------

    local hudW, hudH = 350, 230
    local hudX = screenW - hudW - 30
    local hudY = 30

    dxDrawRectangle(hudX, hudY, hudW, hudH, tocolor(0, 0, 0, 140))

    -- HP
    dxDrawImage(hudX + 20, hudY + 25, 24, 24, iconHP)
    dxDrawRectangle(hudX + 50, hudY + 30, 250, 12, tocolor(50, 50, 50, 180))
    dxDrawRectangle(hudX + 50, hudY + 30, 250 * (hp / 100), 12, tocolor(0, 130, 255, 220))

    -- ARMOUR
    dxDrawImage(hudX + 20, hudY + 65, 24, 24, iconArmour)
    dxDrawRectangle(hudX + 50, hudY + 70, 250, 12, tocolor(50, 50, 50, 180))
    dxDrawRectangle(hudX + 50, hudY + 70, 250 * (armour / 100), 12, tocolor(180, 180, 180, 220))

    -- MONEY
    dxDrawText("$ "..money, hudX + 20, hudY + 110, 0, 0, tocolor(255,255,255,255), 1.1, honeySalt)

    -- NICK
    dxDrawText("NICK: "..nick, hudX + 20, hudY + 150, 0, 0, tocolor(230,230,230,255), 0.9, honeySalt)

    -- DATE + TIME
    dxDrawText(day.."."..month.."."..year, hudX + 20, hudY + 185, 0, 0, tocolor(210,210,210,255), 0.9, honeySalt)
    dxDrawText(hour..":"..minute, hudX + hudW - 80, hudY + 185, 0, 0, tocolor(210,210,210,255), 0.9, honeySalt)
end)
