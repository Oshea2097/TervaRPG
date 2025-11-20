-- tr_hud/hud_client.lua
-- DX HUD: left top stats + right bottom radar + FPS/Ping under radar
-- Values: player:HP and player:armour element data

local showHUD = true
local screenW, screenH = guiGetScreenSize()
local baseW, baseH = 1920, 1080 -- referencyjne wymiary do skalowania
local scaleX, scaleY = screenW / baseW, screenH / baseH
local fontMain, fontBig
local imgRadar, imgHP, imgArmour

-- FPS counter
local fps = 0
local frames = 0
local lastTick = getTickCount()
local fpsTimer = nil

-- Colors
local colPanel = tocolor(8, 12, 16, 200)
local colPanelBorder = tocolor(255,255,255,15)
local colText = tocolor(220,230,240,230)
local colMoney = tocolor(200,230,255,240)
local colBarBG = tocolor(40,48,56,200)
local colHP = { r1=70, g1=150, b1=255 } -- blue-ish gradient start
local colHP2 = { r2=110, g2=200, b2=255 } -- end
local colArm = { r=180, g=180, b=190 } -- grey for armour

-- Sizes (scaled)
local function sx(x) return math.floor(x * scaleX + 0.5) end
local function sy(y) return math.floor(y * scaleY + 0.5) end

-- Positions
local leftPad = sx(28)
local topPad = sy(24)
local panelW = sx(420)
local panelH = sy(160)

local radarSize = sx(200) -- kwadrat
local radarPad = sx(30)

local function loadResources()
    -- font (Honey Salt)
    if fileExists("fonts/HoneySalt.ttf") then
        fontMain = dxCreateFont("fonts/HoneySalt.ttf", sx(14)) or "default-font"
        fontBig = dxCreateFont("fonts/HoneySalt.ttf", sx(28)) or "default-bold"
    else
        fontMain = "default"
        fontBig = "default-bold"
        outputDebugString("[tr_hud] Font HoneySalt.ttf not found in /fonts. Using default.")
    end

    -- images
    if fileExists("images/radar.png") then
        imgRadar = dxCreateTexture("images/radar.png")
    else
        imgRadar = nil
        outputDebugString("[tr_hud] radar.png not found in /images.")
    end
    if fileExists("images/icon_hp.png") then
        imgHP = dxCreateTexture("images/icon_hp.png")
    else
        imgHP = nil
    end
    if fileExists("images/icon_armour.png") then
        imgArmour = dxCreateTexture("images/icon_armour.png")
    else
        imgArmour = nil
    end
end

-- Smooth value helper
local function approach(current, target, speed)
    if current < target then
        return math.min(current + speed, target)
    elseif current > target then
        return math.max(current - speed, target)
    end
    return target
end

-- FPS timer
local function startFPSTimer()
    if isTimer(fpsTimer) then killTimer(fpsTimer) end
    fpsTimer = setTimer(function()
        local now = getTickCount()
        local dt = now - lastTick
        fps = math.floor((frames / math.max(1, dt)) * 1000 + 0.5)
        frames = 0
        lastTick = now
    end, 1000, 0)
end

-- Draw rounded-ish panel (simple)
local function drawPanel(x, y, w, h)
    dxDrawRectangle(x, y, w, h, colPanel)
    dxDrawRectangle(x, y, w, 2, colPanelBorder) -- top border subtle
end

-- Draw gradient bar (left->right) using many slim rects (cheap)
local function drawGradientBar(x, y, w, h, c1, c2)
    local steps = math.max(8, math.floor(w / 6))
    for i=0, steps-1 do
        local t = i / (steps-1)
        local r = math.floor(c1.r1 * (1 - t) + c2.r2 * t)
        local g = math.floor(c1.g1 * (1 - t) + c2.g2 * t)
        local b = math.floor(c1.b1 * (1 - t) + c2.b2 * t)
        local xi = x + (i/steps) * w
        local wi = math.ceil(w / steps)
        dxDrawRectangle(xi, y, wi, h, tocolor(r,g,b,220))
    end
end

-- Main render function
local hpSmooth = 100
local armSmooth = 0

addEventHandler("onClientRender", root, function()
    if not showHUD then return end
    local px = leftPad
    local py = topPad

    -- fetch player values
    local lp = localPlayer
    local hp = tonumber(getElementData(lp, "player:HP")) or tonumber(getElementHealth(lp)) or 100
    local arm = tonumber(getElementData(lp, "player:armour")) or 0
    local money = tonumber(getElementData(lp, "player:money")) or 0
    local nick = tostring(getPlayerName(lp) or "Unknown")

    -- smooth interpolation
    hpSmooth = approach(hpSmooth, math.max(0, math.min(100, hp)), 1.8)
    armSmooth = approach(armSmooth, math.max(0, math.min(100, arm)), 2.2)

    -- LEFT TOP PANEL
    drawPanel(px, py, panelW, panelH)

    -- icons + bars positions
    local iconSize = sy(28)
    local barX = px + sx(70)
    local barW = panelW - sx(90)
    local barH = sy(12)
    local gap = sy(12)

    -- HP icon
    if imgHP then
        dxDrawImage(px + sx(18), py + sy(18), iconSize, iconSize, imgHP, 0, 0, 0, tocolor(255,255,255,220))
    else
        dxDrawRectangle(px + sx(18), py + sy(18), iconSize, iconSize, tocolor(180,30,30,180))
    end
    -- HP bar BG
    dxDrawRectangle(barX, py + sy(18) + (iconSize - barH)/2, barW, barH, colBarBG)
    -- HP bar fill (gradient)
    local hpFillW = math.floor((hpSmooth/100) * barW + 0.5)
    drawGradientBar(barX, py + sy(18) + (iconSize - barH)/2, hpFillW, barH, colHP, colHP2)

    -- Armour icon
    if imgArmour then
        dxDrawImage(px + sx(18), py + sy(18) + iconSize + gap, iconSize, iconSize, imgArmour, 0, 0, 0, tocolor(200,200,200,220))
    else
        dxDrawRectangle(px + sx(18), py + sy(18) + iconSize + gap, iconSize, iconSize, tocolor(100,100,120,180))
    end
    -- Armour bar BG
    dxDrawRectangle(barX, py + sy(18) + iconSize + gap + (iconSize - barH)/2, barW, barH, colBarBG)
    -- Armour fill (solid)
    local armFillW = math.floor((armSmooth/100) * barW + 0.5)
    dxDrawRectangle(barX, py + sy(18) + iconSize + gap + (iconSize - barH)/2, armFillW, barH, tocolor(colArm.r, colArm.g, colArm.b, 220))

    -- Money (big)
    local moneyY = py + sy(18) + iconSize*2 + gap*1.6
    dxDrawText("$ " .. tostring(money), px + sx(18), moneyY, px + panelW - sx(10), moneyY + sy(40),
               colMoney, 1.1 * scaleX, fontBig, "left", "top", false, false, true)

    -- Nick
    dxDrawText("NICK: " .. nick, px + sx(18), moneyY + sy(34), px + panelW - sx(10), moneyY + sy(64),
               colText, 0.9 * scaleX, fontMain, "left", "top", false, false, true)

    -- Date & time (bottom of panel)
    local datetime = os.date("%d.%m.%Y")
    local timenow = os.date("%H:%M")
    dxDrawText(datetime, px + sx(18), py + panelH - sy(28), px + sx(200), py + panelH - sy(8),
               colText, 0.9 * scaleX, fontMain, "left", "top", false, false, true)
    dxDrawText(timenow, px + panelW - sx(48), py + panelH - sy(28), px + panelW - sx(8), py + panelH - sy(8),
               colText, 0.9 * scaleX, fontMain, "right", "top", false, false, true)

    -- RADAR right bottom
    local rx = screenW - radarPad - radarSize
    local ry = screenH - radarPad - radarSize - sy(48) -- leave space for FPS/Ping
    -- radar panel
    dxDrawRectangle(rx - sx(12), ry - sy(12), radarSize + sx(24), radarSize + sy(24), colPanel)
    if imgRadar then
        dxDrawImage(rx, ry, radarSize, radarSize, imgRadar, 0, 0, 0, tocolor(255,255,255,220))
    else
        dxDrawRectangle(rx, ry, radarSize, radarSize, tocolor(20,20,20,220))
        dxDrawText("RADAR", rx, ry, rx + radarSize, ry + radarSize, colText, 1.0 * scaleX, fontMain, "center", "center")
    end

    -- FPS / Ping under radar
    local fpsX = rx + radarSize/2
    local fpsY = ry + radarSize + sy(8)
    -- Calculate ping
    local ping = getPlayerPing(localPlayer) or 0
    dxDrawText(("FPS: %d | Ping: %dms"):format(fps, ping), fpsX, fpsY, fpsX, fpsY + sy(24),
               tocolor(200,200,200,220), 0.9 * scaleX, fontMain, "center", "top", false, false, true)

    -- count frame
    frames = frames + 1
end)

-- handle FPS timer
addEventHandler("onClientResourceStart", resourceRoot, function()
    loadResources()
    lastTick = getTickCount()
    frames = 0
    startFPSTimer()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isTimer(fpsTimer) then killTimer(fpsTimer) end
    if fontMain and type(fontMain) == "userdata" then destroyElement(fontMain) end
    if fontBig and type(fontBig) == "userdata" then destroyElement(fontBig) end
    if imgRadar and type(imgRadar) == "userdata" then destroyElement(imgRadar) end
    if imgHP and type(imgHP) == "userdata" then destroyElement(imgHP) end
    if imgArmour and type(imgArmour) == "userdata" then destroyElement(imgArmour) end
end)

-- Toggle HUD on F5
bindKey("F5", "down", function()
    showHUD = not showHUD
    showCursor(false)
end)

-- ensure HUD hides when gui is shown (simple safeguard)
addEventHandler("onClientGUIFocus", root, function() end)

-- Expose function to toggle via other resources if needed
function exportsToggleHUD()
    showHUD = not showHUD
end
