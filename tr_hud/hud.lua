-- file: hud/client.lua

local sx, sy = guiGetScreenSize()

-- icon paths
local iconHeart = dxCreateTexture("images/heart.png")
local iconArmor = dxCreateTexture("images/armor.png")

-- placeholder hunger/thirst
local hunger = 70
local thirst = 40

-- radar config
local radarSize = 240
local radarX = 20
local radarY = sy - radarSize - 20

-- hunger/thirst bars
local barW = 12
local barH = radarSize
local barGap = 10

local hungerX = radarX + radarSize + barGap
local thirstX = hungerX + barW + barGap
local barsY = radarY

-- HUD top-right
local hudW = 320
local hudH = 160
local hudX = sx - hudW - 20
local hudY = 20

local function drawBar(x, y, w, h, progress, r, g, b)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 120))
    dxDrawRectangle(x, y + (1 - progress) * h, w, progress * h, tocolor(r, g, b, 230))
end

function drawHUD()
    local hp = getElementHealth(localPlayer)
    local armor = getPedArmor(localPlayer)
    local hpPercent = math.min(hp / 100, 1)
    local arPercent = math.min(armor / 100, 1)

    dxDrawRectangle(hudX, hudY, hudW, hudH, tocolor(0, 0, 0, 120))

    -- hp bar
    dxDrawImage(hudX + 20, hudY + 20, 24, 24, iconHeart)
    dxDrawRectangle(hudX + 60, hudY + 26, 220, 10, tocolor(60, 60, 60, 150))
    dxDrawRectangle(hudX + 60, hudY + 26, 220 * hpPercent, 10, tocolor(0, 140, 255, 230))

    -- armor bar
    dxDrawImage(hudX + 20, hudY + 60, 24, 24, iconArmor)
    dxDrawRectangle(hudX + 60, hudY + 66, 220, 10, tocolor(60, 60, 60, 150))
    dxDrawRectangle(hudX + 60, hudY + 66, 220 * arPercent, 10, tocolor(160, 160, 160, 230))

    -- Money + Nick + Date/Time
    local money = getPlayerMoney(localPlayer)
    local nick = getPlayerName(localPlayer)
    local time = getRealTime()
    local dateStr = string.format("%02d.%02d.%04d", time.monthday, time.month + 1, time.year + 1900)
    local hourStr = string.format("%02d:%02d", time.hour, time.minute)

    dxDrawText("$ "..tostring(money), hudX + 20, hudY + 100, hudX + hudW, hudY, tocolor(255, 255, 255), 1.0, "default-bold")
    dxDrawText("Nick: "..nick, hudX + 20, hudY + 125, hudX + hudW, hudY, tocolor(220, 220, 220), 1.0, "default")
    dxDrawText(dateStr.."      "..hourStr, hudX + 20, hudY + 145, hudX + hudW, hudY, tocolor(200, 200, 200), 1.0, "default")

    -- draw hunger/thirst bars
    drawBar(hungerX, barsY, barW, barH, hunger / 100, 200, 160, 0)
    drawBar(thirstX, barsY, barW, barH, thirst / 100, 0, 120, 255)

    -- radar area (classic)
    -- (GTA radar auto-renders, so only border)
    dxDrawRectangle(radarX - 3, radarY - 3, radarSize + 6, radarSize + 6, tocolor(0, 0, 0, 100))

    -- FPS + ping + time (below radar)
    local fps = getFPS()
    local ping = getPlayerPing(localPlayer)
    local clock = string.format("%02d:%02d", time.hour, time.minute)

    dxDrawText(
        "FPS: "..fps.." | PING: "..ping.."ms | "..clock,
        radarX, radarY + radarSize + 10,
        radarX + radarSize, radarY + radarSize + 40,
        tocolor(255,255,255,200), 1.0, "default-bold", "center"
    )
end

function getFPS()
    return math.floor(1 / getTickTime())
end

addEventHandler("onClientRender", root, drawHUD)
