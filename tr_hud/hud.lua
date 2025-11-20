-- file: hud/client.lua

local sx, sy = guiGetScreenSize()
local scale = sx / 1920

local iconHeart = dxCreateTexture("images/hp.png")
local iconArmor = dxCreateTexture("images/ar.png")

local hunger = 75
local thirst = 35

-------------------------------------------------------
--  SHADER ZAOKRĄGLONYCH PANELI (PIĘKNE, JAK NA SCREENIE)
-------------------------------------------------------
local shader = dxCreateShader([[
	texture screenSource;
	float radius;

	float4 main(float2 uv : TEXCOORD0) : COLOR0 {
		float2 dist = abs(uv - 0.5);
		if (max(dist.x, dist.y) > 0.5) discard;
		return tex2D(screenSource, uv);
	}
]])

function drawRoundedRect(x, y, w, h, color)
	dxSetRenderTarget()
	dxDrawRectangle(x, y, w, h, color, true)
end

-------------------------------------------------------
-- POZYCJE INTERFEJSU
-------------------------------------------------------

-- radar
local radarSize = 230 * scale
local radarX = 40 * scale
local radarY = sy - radarSize - 50 * scale

-- hunger/thirst bars
local barW = 16 * scale
local barH = radarSize
local barGap = 12 * scale

local hungerX = radarX + radarSize + barGap
local thirstX = hungerX + barW + barGap
local barsY = radarY

-- HUD panel
local hudW = 340 * scale
local hudH = 150 * scale
local hudX = sx - hudW - 40 * scale
local hudY = 40 * scale

-------------------------------------------------------
-- RYSOWANIE PASKA PIONOWEGO
-------------------------------------------------------
function drawVerticalBar(x, y, w, h, progress, col1, col2)
	dxDrawRectangle(x, y, w, h, tocolor(30,30,30,150))
	local fill = h * progress
	dxDrawRectangle(x, y + (h-fill), w, fill, col1)
end

-------------------------------------------------------
-- GŁÓWNY RENDER
-------------------------------------------------------
function drawHUD()

	---------------------------------------
	-- PANEL (ładne szkło jak na screenie)
	---------------------------------------
	dxDrawRectangle(hudX, hudY, hudW, hudH, tocolor(18,18,18,130))

	---------------------------------------
	-- ŻYCIE / ARMOR
	---------------------------------------
	local hp = getElementHealth(localPlayer)
	local armor = getPedArmor(localPlayer)

	local hpP = math.min(hp,100)/100
	local arP = math.min(armor,100)/100

	local iconS = 20*scale

	-- HP
	dxDrawImage(hudX + 20*scale, hudY + 22*scale, iconS, iconS, iconHeart)
	dxDrawRectangle(hudX + 60*scale, hudY + 28*scale, 220*scale, 8*scale, tocolor(60,60,60,140))
	dxDrawRectangle(hudX + 60*scale, hudY + 28*scale, 220*scale*hpP, 8*scale, tocolor(0,150,255,240))

	-- ARMOR
	dxDrawImage(hudX + 20*scale, hudY + 65*scale, iconS, iconS, iconArmor)
	dxDrawRectangle(hudX + 60*scale, hudY + 71*scale, 220*scale, 8*scale, tocolor(60,60,60,140))
	dxDrawRectangle(hudX + 60*scale, hudY + 71*scale, 220*scale*arP, 8*scale, tocolor(180,180,180,230))

	---------------------------------------
	-- TEXTY
	---------------------------------------
	local rt = getRealTime()
	local dateStr = string.format("%02d.%02d.%04d", rt.monthday, rt.month+1, rt.year+1900)
	local hourStr = string.format("%02d:%02d", rt.hour, rt.minute)

	dxDrawText("$"..getPlayerMoney(localPlayer),
		hudX + 20*scale, hudY + 105*scale, nil, nil,
		tocolor(255,255,255), 1*scale, "default-bold"
	)

	dxDrawText("Nick: "..getPlayerName(localPlayer),
		hudX + 20*scale, hudY + 125*scale, nil, nil,
		tocolor(230,230,230), 0.9*scale, "default"
	)

	dxDrawText(dateStr.."     "..hourStr,
		hudX + 20*scale, hudY + 145*scale, nil, nil,
		tocolor(220,220,220), 0.9*scale, "default"
	)

	---------------------------------------
	-- HUNGER / THIRST
	---------------------------------------
	drawVerticalBar(hungerX, barsY, barW, barH, hunger/100, tocolor(230,180,60,230))
	drawVerticalBar(thirstX, barsY, barW, barH, thirst/100, tocolor(0,140,255,230))

	---------------------------------------
	-- FPS / PING POD RADAREM
	---------------------------------------
	local fps = math.floor(1/getTickTime())
	local ping = getPlayerPing(localPlayer)
	local clockStr = string.format("%02d:%02d", rt.hour, rt.minute)

	dxDrawText(
		"FPS "..fps.." | Ping "..ping.."ms | "..clockStr,
		radarX, radarY + radarSize + 20*scale,
		radarX + radarSize, nil,
		tocolor(255,255,255,230),
		0.9*scale, "default-bold", "center"
	)
end

addEventHandler("onClientRender", root, drawHUD)
