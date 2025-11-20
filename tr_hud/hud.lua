-- file: hud/client.lua

local sx, sy = guiGetScreenSize()
local scale = sx / 1920

local iconHeart = dxCreateTexture("images/heart.png")
local iconArmor = dxCreateTexture("images/armor.png")

local hunger = 75
local thirst = 55

-- RADAR SETTINGS
local radarSize = 220 * scale
local radarX = 30 * scale
local radarY = sy - radarSize - 40 * scale

-- Bars next to radar
local barW = 14 * scale
local barH = radarSize
local barGap = 12 * scale

local hungerX = radarX + radarSize + barGap
local thirstX = hungerX + barW + barGap
local barsY = radarY

-- HUD TOP-RIGHT
local hudW = 360 * scale
local hudH = 165 * scale
local hudX = sx - hudW - 30 * scale
local hudY = 30 * scale

local function drawVerticalBar(x, y, w, h, progress, color)
    dxDrawRectangle(x, y, w, h, tocolor(25, 25, 25, 120))
    dxDrawRectangle(x, y + h * (1 - progress), w, h * progress, color)
end

function drawHUD()
    local hp = getElementHealth(localPlayer)
    local armor = getPedArmor(localPlayer)

    local hpPercent = math.min(hp, 100) / 100
    local arPercent = math.min(armor, 100) / 100

    -- === HUD PANEL (GLASS STYLE) ===
    dxDrawRectangle(hudX, hudY, hudW, hudH, tocolor(15, 15, 15, 150), true)

    -- icons size
    local iconS = 22 * scale

    -- === HEALTH BAR ===
    dxDrawImage(hudX + 25 * scale, hudY + 25 * scale, iconS, iconS, iconHeart)
    dxDrawRectangle(hudX + 60 * scale, hudY + 30 * scale, 220 * scale, 10 * scale, tocolor(60,60,60,130), true)
    dxDrawRectangle(hudX + 60 * scale, hudY + 30 * scale, (220 * scale) * hpPercent, 10 * scale, tocolor(50,160,255,240), true)

    -- === ARMOR BAR ===
    dxDrawImage(hudX + 25 * scale, hudY + 70 * scale, iconS, iconS, iconArmor)
    dxDrawRectangle(hudX + 60 * scale, hudY + 75 * scale, 220 * scale, 10 * scale, tocolor(60,60,60,130), true)
    dxDrawRectangle(hudX + 60 * scale, hudY + 75 * scale, (220 * scale) * arPercent, 10 * scale, tocolor(200,200,200,220), true)

    local money = getPlayerMoney(localPlayer)
    local nick = getPlayerName(localPlayer)
    local rt = getRealTime()
    local dateStr = string.format("%02d.%02d.%04d", rt.monthday, rt.month+1, rt.year+1900)
    local hourStr = string.format("%02d:%02d", rt.hour, rt.minute)

    dxDrawText("$"..money, hudX + 25*scale, hudY + 115*scale, nil,nil, tocolor(255,255,255), 1*scale, "default-bold")
    dxDrawText("Nick: "..nick, hudX + 25*scale, hudY + 140*scale, nil,nil, tocolor(230,230,230), 0.9*scale, "default")
    dxDrawText(dateStr.."     "..hourStr, hudX + 25*scale, hudY + 160*scale, nil,nil, tocolor(220,220,220), 0.9*scale, "default")

    -- === RADAR BORDER (NOT COVERING MAP) ===
    dxDrawRectangle(radarX - 4, radarY - 4, radarSize + 8, radarSize + 8, tocolor(15,15,15,150))

    -- === HUNGER/THIRST ===
    drawVerticalBar(hungerX, barsY, barW, barH, hunger / 100, tocolor(200,170,40,230))
    drawVerticalBar(thirstX, barsY, barW, barH, thirst / 100, tocolor(50,130,255,230))

    -- === FPS/PING/TIME ===
    local fps = getFPS()
    local ping = getPlayerPing(localPlayer)
    local clockStr = string.format("%02d:%02d", rt.hour, rt.minute)

    dxDrawText(
        "FPS: "..fps.."  |  Ping: "..ping.."ms  |  "..clockStr,
        radarX, radarY + radarSize + 15 * scale,
        radarX + radarSize, nil,
        tocolor(255,255,255,220), 0.9*scale, "default-bold", "center"
    )
end

function getFPS()
    return math.floor(1 / getTickTime())
end

addEventHandler("onClientRender", root, drawHUD)
