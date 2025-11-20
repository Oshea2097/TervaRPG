-- file: hud/client.lua

local sx, sy = guiGetScreenSize()
local scale = sx / 1920

local iconHeart = dxCreateTexture("images/heart.png")
local iconArmor = dxCreateTexture("images/armor.png")

-------------------------------------------------------
-- WYŁĄCZENIE STANDARDOWEGO GTA HUD
-------------------------------------------------------
addEventHandler("onClientResourceStart", resourceRoot, function()
    showPlayerHudComponent("radar", true)      -- radar zostaje
    showPlayerHudComponent("health", false)
    showPlayerHudComponent("armour", false)
    showPlayerHudComponent("money", false)
    showPlayerHudComponent("ammo", false)
    showPlayerHudComponent("weapon", false)
    showPlayerHudComponent("clock", false)
    showPlayerHudComponent("breath", false)
end)

-------------------------------------------------------
-- HUD POZYCJE
-------------------------------------------------------
local hudW = 340 * scale
local hudH = 150 * scale
local hudX = sx - hudW - 40 * scale
local hudY = 40 * scale

-------------------------------------------------------
-- RENDER PRZEJRZYSTEGO, ŁADNEGO HUDU
-------------------------------------------------------
function drawHUD()

    ---------------------------------------------------
    -- PANEL (łagodne zaokrąglone tło jak na Twoim screenie)
    ---------------------------------------------------
    dxDrawRectangle(hudX, hudY, hudW, hudH, tocolor(15,15,15,160))

    ---------------------------------------------------
    -- HP / ARMOR
    ---------------------------------------------------
    local hp = getElementHealth(localPlayer)
    local armor = getPedArmor(localPlayer)

    local hpP = math.min(hp, 100) / 100
    local arP = math.min(armor, 100) / 100

    local iconS = 22 * scale

    -- HP
    dxDrawImage(hudX + 20*scale, hudY + 25*scale, iconS, iconS, iconHeart)
    dxDrawRectangle(hudX + 60*scale, hudY + 32*scale, 230*scale, 9*scale, tocolor(50,50,50,150))
    dxDrawRectangle(hudX + 60*scale, hudY + 32*scale, 230*scale * hpP, 9*scale, tocolor(0,150,255,245))

    -- ARMOR
    dxDrawImage(hudX + 20*scale, hudY + 72*scale, iconS, iconS, iconArmor)
    dxDrawRectangle(hudX + 60*scale, hudY + 78*scale, 230*scale, 9*scale, tocolor(50,50,50,150))
    dxDrawRectangle(hudX + 60*scale, hudY + 78*scale, 230*scale * arP, 9*scale, tocolor(180,180,180,240))

    ---------------------------------------------------
    -- MONEY / NICK / DATA / GODZINA
    ---------------------------------------------------
    local rt = getRealTime()
    local dateStr = string.format("%02d.%02d.%04d", rt.monthday, rt.month+1, rt.year+1900)
    local hourStr = string.format("%02d:%02d", rt.hour, rt.minute)

    dxDrawText("$"..getPlayerMoney(localPlayer),
        hudX + 20*scale, hudY + 115*scale,
        nil, nil, tocolor(255,255,255),
        1*scale, "default-bold"
    )

    dxDrawText("Nick: "..getPlayerName(localPlayer),
        hudX + 20*scale, hudY + 135*scale,
        nil, nil, tocolor(230,230,230),
        0.9*scale, "default"
    )

    dxDrawText(dateStr.."   |   "..hourStr,
        hudX + 20*scale, hudY + 157*scale,
        nil, nil, tocolor(220,220,220),
        0.9*scale, "default"
    )

    ---------------------------------------------------
    -- FPS + PING POD RADAREM
    ---------------------------------------------------
    local fps = math.floor(1 / getTickTime())
    local ping = getPlayerPing(localPlayer)

    dxDrawText(
        "FPS "..fps.."   |   Ping "..ping.."ms   |   "..hourStr,
        40*scale, sy - 260*scale + 220*scale,
        300*scale, nil,
        tocolor(255,255,255), 0.85*scale,
        "default-bold", "left"
    )
end

addEventHandler("onClientRender", root, drawHUD)
