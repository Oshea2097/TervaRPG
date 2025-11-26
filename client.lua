-- tr-notifications/client.lua
-- Subtelne dx-notyfikacje po prawej stronie ekranu

local screenW, screenH = guiGetScreenSize()
local font = nil

-- Safe font loader (fallback do "default")
if fileExists("font.ttf") then
    font = dxCreateFont("font.ttf", 12)
    if not font then font = "default" end
else
    font = "default"
end

local notifications = {} -- { {text=..., type=..., tick=..., life=... , progress=...}, ... }
local LIFETIME = 5000 -- ms

local styles = {
    info =    { bg = tocolor(30,30,34,210), accent = tocolor(80,150,255,255) },
    success = { bg = tocolor(25,40,20,210), accent = tocolor(80,255,120,255) },
    warning = { bg = tocolor(40,30,12,210), accent = tocolor(255,180,80,255) },
    error =   { bg = tocolor(40,10,10,220), accent = tocolor(255,80,80,255) }
}

-- Add notification (called from server)
addEvent("tr:noti:add", true)
addEventHandler("tr:noti:add", root, function(text, ntype)
    ntype = tostring(ntype or "info")
    text = tostring(text or "")
    local now = getTickCount()
    table.insert(notifications, 1, { text = text, type = ntype, tick = now, life = LIFETIME, alpha = 0 })
end)

-- Render notifications
addEventHandler("onClientRender", root, function()
    if #notifications == 0 then return end
    local margin = 14
    local boxW = math.min(360, screenW * 0.28)
    local x = screenW - boxW - margin
    local y = margin

    for i = #notifications, 1, -1 do
        local n = notifications[i]
        local elapsed = getTickCount() - n.tick
        if elapsed >= n.life then
            table.remove(notifications, i)
        else
            local lifeProg = elapsed / n.life
            local slide = math.min(1, lifeProg * 6) -- quick slide-in
            local boxH = 44
            local drawX = x + (1 - slide) * 60 -- slide from right
            local alpha = math.floor((1 - lifeProg) * 255)
            local style = styles[n.type] or styles.info

            -- background
            dxDrawRectangle(drawX, y, boxW, boxH, tocolor(0,0,0,200 * (alpha/255)))
            -- accent bar
            dxDrawRectangle(drawX, y, 6, boxH, tocolor(getR(style.accent), getG(style.accent), getB(style.accent), alpha))

            -- text
            dxDrawText(n.text, drawX + 14, y, drawX + boxW - 12, y + boxH, tocolor(235,235,235,alpha), 1, font, "left", "center", false, false, false, true)
            y = y + boxH + 8
        end
    end
end)

-- Utility to extract r,g,b from tocolor (works with numbers)
function getR(c) return bitExtract(c, 24, 8) end
function getG(c) return bitExtract(c, 16, 8) end
function getB(c) return bitExtract(c, 8, 8) end
