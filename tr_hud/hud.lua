local screenW, screenH = guiGetScreenSize()
local zoom = (screenW < 1920) and (screenW / 1920) or 1
local function sx(v) return v * zoom end
local function sy(v) return v * zoom end
local texHP = dxCreateTexture("img/icon_hp.png")
local texArmour = dxCreateTexture("img/icon_armour.png")
local texRadar = dxCreateTexture("img/radar.png")
local fontMain = dxCreateFont("fonts/HoneySalt.ttf", sx(12))
local smooth = {
    hp = 0,
    armour = 0,
    hunger = 100,
    thirst = 100,
}
local fps, fpsTick = 0, getTickCount()
addEventHandler("onClientRender", root, function()
    if getTickCount() - fpsTick >= 1000 then
        fps = getFPSLimit()
        fpsTick = getTickCount()
    end
end)

local showHUD = true
bindKey("F5", "down", function() showHUD = not showHUD end)

addEventHandler("onClientRender", root, function()
    if not showHUD then return end

    -------------------------------------------------
    -- Dane gracza
    -------------------------------------------------
    local hp = getElementHealth(localPlayer)
    local armour = getPedArmor(localPlayer)
    local money = getPlayerMoney(localPlayer)
    local hunger = getElementData(localPlayer, "player:hunger") or 100
    local thirst = getElementData(localPlayer, "player:thirst") or 100
    local nick = getPlayerName(localPlayer)

    local ping = getPlayerPing(localPlayer)

    local time = getRealTime()
    local day = time.monthday
    local month = time.month + 1
    local year = time.year + 1900
    local hour = time.hour
    local minute = time.minute

    -------------------------------------------------
    -- Smooth animacja
    -------------------------------------------------
    smooth.hp = smooth.hp + (hp - smooth.hp) * 0.1
    smooth.armour = smooth.armour + (armour - smooth.armour) * 0.1
    smooth.hunger = smooth.hunger + (hunger - smooth.hunger) * 0.08
    smooth.thirst = smooth.thirst + (thirst - smooth.thirst) * 0.08

    -------------------------------------------------
    -- RADAR (Lewy dolny róg)
    -------------------------------------------------
    local radarSize = sx(260)
    local radarX = sx(20)
    local radarY = screenH - radarSize - sy(150)

    dxDrawRectangle(radarX - sx(6), radarY - sy(6), radarSize + sx(12), radarSize + sy(12), tocolor(8, 12, 16, 200))

    -- radar obraz
    if texRadar then
        dxDrawImage(radarX, radarY, radarSize, radarSize, texRadar)
    else
        dxDrawRectangle(radarX, radarY, radarSize, radarSize, tocolor(50, 50, 50, 200))
    end

    -------------------------------------------------
    -- GŁÓD + PRAGNIENIE (po prawej od radaru)
    -------------------------------------------------
    local barW = sx(12)
    local barH = sy(130)
    local barX = radarX + radarSize + sx(25)
    local barY = radarY

    -- głód
    dxDrawText("GŁÓD", barX, barY - sy(20), barX + sx(80), barY, tocolor(230,230,230), sx(0.9), fontMain)
    dxDrawRectangle(barX, barY, barW, barH, tocolor(40,40,40,180))
    dxDrawRectangle(barX, barY + (barH - barH*(smooth.hunger/100)), barW, barH*(smooth.hunger/100), tocolor(255,165,0,230))

    -- pragnienie
    local tY = barY + barH + sy(40)
    dxDrawText("WODA", barX, tY - sy(20), barX + sx(80), tY, tocolor(230,230,230), sx(0.9), fontMain)
    dxDrawRectangle(barX, tY, barW, barH, tocolor(40,40,40,180))
    dxDrawRectangle(barX, tY + (barH - barH*(smooth.thirst/100)), barW, barH*(smooth.thirst/100), tocolor(80,180,255,230))

    -------------------------------------------------
    -- FPS + PING + DATA/GODZINA (pod radarem)
    -------------------------------------------------
    local infoY = radarY + radarSize + sy(14)

    dxDrawText(
        string.format("FPS: %d  |  Ping: %d ms", fps, ping),
        radarX, infoY,
        radarX + radarSize, infoY + sy(20),
        tocolor(230,230,230),
        sx(0.9), fontMain, "center"
    )

    dxDrawText(
        string.format("%02d.%02d.%d  |  %02d:%02d", day, month, year, hour, minute),
        radarX, infoY + sy(22),
        radarX + radarSize, infoY + sy(40),
        tocolor(210,210,210),
        sx(0.9), fontMain, "center"
    )

    -------------------------------------------------
    -- HUD (Prawy górny róg)
    -------------------------------------------------
    local hudX = screenW - sx(260) - sx(40)
    local hudY = sy(40)

    -- tło
    dxDrawRectangle(hudX, hudY, sx(260), sy(160), tocolor(8, 12, 16, 180))

    -------------------------------------------------
    -- HP
    -------------------------------------------------
    dxDrawImage(hudX + sx(10), hudY + sy(10), sx(32), sy(32), texHP)
    dxDrawRectangle(hudX + sx(50), hudY + sy(20), sx(200), sy(14), tocolor(40,40,40,200))
    dxDrawRectangle(hudX + sx(50), hudY + sy(20), sx(200 * (smooth.hp / 100), sy(14)), tocolor(255,80,80,220))

    -------------------------------------------------
    -- ARMOUR
    -------------------------------------------------
    dxDrawImage(hudX + sx(10), hudY + sy(55), sx(32), sy(32), texArmour)
    dxDrawRectangle(hudX + sx(50), hudY + sy(65), sx(200), sy(14), tocolor(40,40,40,200))
    dxDrawRectangle(hudX + sx(50), hudY + sy(65), sx(200 * (smooth.armour / 100), sy(14)), tocolor(120,170,255,220))

    -------------------------------------------------
    -- MONEY + NICK
    -------------------------------------------------
    dxDrawText(nick, hudX + sx(10), hudY + sy(100), hudX + sx(250), hudY + sy(120), tocolor(240,240,240), sx(0.95), fontMain)
    dxDrawText("$"..tostring(money), hudX + sx(10), hudY + sy(125), hudX + sx(250), hudY + sy(145), tocolor(140,255,140), sx(1), fontMain)
end)
