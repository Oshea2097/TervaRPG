-- file: hud/client.lua

local sx, sy = guiGetScreenSize()
local scale = sx / 1920

-- Czcionka Honey Salt
local fontMain = dxCreateFont("fonts/HoneySalt.otf", 30 * scale)

-- Tło hud.png
local bgHud = dxCreateTexture("images/bg.png")

-------------------------------------------------------
-- WYŁĄCZENIE STANDARDOWEGO HUD GTA
-------------------------------------------------------
addEventHandler("onClientResourceStart", resourceRoot, function()
    showPlayerHudComponent("radar", true)
    showPlayerHudComponent("health", false)
    showPlayerHudComponent("armour", false)
    showPlayerHudComponent("money", false)
    showPlayerHudComponent("ammo", false)
    showPlayerHudComponent("weapon", false)
    showPlayerHudComponent("clock", false)
    showPlayerHudComponent("breath", false)
end)

-------------------------------------------------------
-- POZYCJE HUD
-------------------------------------------------------
local hudW = 420 * scale
local hudH = 220 * scale
local hudX = sx - hudW - 40 * scale
local hudY = 40 * scale

-------------------------------------------------------
-- RYSOWANIE HUDU
-------------------------------------------------------
function drawHUD()

    ---------------------------------------------------
    -- TŁO HUD → ZAMIANA PROSTOKĄTA NA GRAFIKĘ
    ---------------------------------------------------
    dxDrawImage(hudX, hudY, hudW, hudH, bgHud)

    ---------------------------------------------------
    -- HP & ARMOR (IDENTYCZNIE JAK BYŁO WCZEŚNIEJ)
    ---------------------------------------------------
    local hp = getElementHealth(localPlayer)
    local armor = getPedArmor(localPlayer)

    local hpP = math.min(hp, 100) / 100
    local arP = math.min(armor, 100) / 100

    -- HP
    dxDrawRectangle(hudX + 60*scale, hudY + 50*scale, 260*scale, 12*scale, tocolor(50,50,50,150))
    dxDrawRectangle(hudX + 60*scale, hudY + 50*scale, 260*scale * hpP, 12*scale, tocolor(0,150,255,245))

    -- ARMOR
    dxDrawRectangle(hudX + 60*scale, hudY + 95*scale, 260*scale, 12*scale, tocolor(50,50,50,150))
    dxDrawRectangle(hudX + 60*scale, hudY + 95*scale, 260*scale * arP, 12*scale, tocolor(180,180,180,240))

    ---------------------------------------------------
    -- TEKSTY W OBRYSIE HUDU
    ---------------------------------------------------
    local rt = getRealTime()
    local dateStr = string.format("%02d.%02d.%04d", rt.monthday, rt.month+1, rt.year+1900)
    local hourStr = string.format("%02d:%02d", rt.hour, rt.minute)

    dxDrawText(
        "$"..getPlayerMoney(localPlayer),
        hudX + 50*scale, hudY + 135*scale,
        hudX + hudW - 50*scale, nil,
        tocolor(255,255,255),
        1.0 * scale, fontMain, "left", "top"
    )

    dxDrawText(
        getPlayerName(localPlayer),
        hudX + 50*scale, hudY + 165*scale,
        hudX + hudW - 50*scale, nil,
        tocolor(230,230,230),
        0.9 * scale, fontMain, "left", "top"
    )

    dxDrawText(
        dateStr .. "   |   " .. hourStr,
        hudX + 50*scale, hudY + 195*scale,
        hudX + hudW - 50*scale, nil,
        tocolor(200,200,200),
        0.9 * scale, fontMain, "left", "top"
    )

    ---------------------------------------------------
    -- FPS + PING POD RADAREM
    ---------------------------------------------------
    local fps = math.floor(1 / getTickTime())
    local ping = getPlayerPing(localPlayer)

    dxDrawText(
        "FPS "..fps.."   |   Ping "..ping.."ms   |   "..hourStr,
        40 * scale, sy - 180 * scale,
        300 * scale, nil,
        tocolor(255,255,255),
        0.75 * scale, fontMain,
        "left"
    )
end

addEventHandler("onClientRender", root, drawHUD)
