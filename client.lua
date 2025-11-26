
local screenW, screenH = guiGetScreenSize()
local font = dxCreateFont("font.ttf", 12) or "default"
local assignedPackages = {}
local currentStartPoint = nil
local deliveryMarkers = {} -- pkgId -> marker

-- create start marker
local startBlip, startMarker
addEventHandler("onClientResourceStart", resourceRoot, function()
    local sp = JOB.startPoint
    startMarker = createMarker(sp.x, sp.y, sp.z - 1, "cylinder", 1.2, 80, 150, 255, 120)
    startBlip = createBlip(sp.x, sp.y, sp.z, 41, 2, 255,255,255,255, 0, 300)
end)

-- receive assignment
addEvent("job:assignment", true)
addEventHandler("job:assignment", root, function(pkgMetaList, startPoint)
    assignedPackages = {}
    for _,m in ipairs(pkgMetaList) do assignedPackages[m.id] = m end
    currentStartPoint = startPoint
    -- open tablet UI automatically for now
    outputChatBox("[JOB] Przydzielono paczki: "..tostring(#pkgMetaList))
    -- create client markers for each package (for scanning demo place them near start)
    for id,meta in pairs(assignedPackages) do
        local x = startPoint.x + math.random(-6,6)
        local y = startPoint.y + math.random(-6,6)
        local z = startPoint.z
        local m = createMarker(x,y,z - 0.7, "corona", 1.0, 255,200,80,180)
        deliveryMarkers[id] = m
        addEventHandler("onClientMarkerHit", m, function(h)
            if h ~= localPlayer then return end
            -- prompt
            outputChatBox("Naciśnij K, aby zeskanować paczkę #"..id)
            -- store last marker -> pkg
            lastMarkerForScan = id
        end)
    end
end)

-- scan action (press K)
bindKey("k", "down", function()
    if lastMarkerForScan then
        triggerServerEvent("job:scanPackage", resourceRoot, lastMarkerForScan)
        lastMarkerForScan = nil
    else
        outputChatBox("Brak paczki do skanowania w pobliżu.")
    end
end)

-- events feedback from server
addEvent("job:packageScanned", true)
addEventHandler("job:packageScanned", root, function(pkgId)
    outputChatBox("[JOB] Paczka #"..pkgId.." została zeskanowana.")
    -- mark it visually: change marker color
    if deliveryMarkers[pkgId] and isElement(deliveryMarkers[pkgId]) then
        setMarkerColor(deliveryMarkers[pkgId], 80,255,80,180)
    end
end)

addEvent("job:packageSorted", true)
addEventHandler("job:packageSorted", root, function(pkgId, sector)
    outputChatBox("[JOB] Paczka #"..pkgId.." posortowana do sektora "..tostring(sector))
end)

addEvent("job:vehicleReady", true)
addEventHandler("job:vehicleReady", root, function(veh)
    outputChatBox("[JOB] Pojazd jest gotowy. Wsiądź i zapakuj paczki.")
    -- mark target points for delivery (show blips for demo)
    if assignedPackages then
        for id,meta in pairs(assignedPackages) do
            local pt = meta and meta.id and meta or nil -- meta contains only minimal; server will handle full targets
        end
    end
end)

-- client-side delivery (player drives to package.target and triggers server deliver)
-- for demo we add key L to deliver whatever package marker you're near
bindKey("l", "down", function()
    -- check nearby delivery markers (simulate)
    local px,py,pz = getElementPosition(localPlayer)
    for id,m in pairs(deliveryMarkers) do
        if isElement(m) then
            local mx,my,mz = getElementPosition(m)
            local dist = getDistanceBetweenPoints3D(px,py,pz,mx,my,mz)
            if dist < 3 then
                triggerServerEvent("job:deliverPackage", resourceRoot, id)
                if isElement(m) then destroyElement(m) end
                deliveryMarkers[id] = nil
                return
            end
        end
    end
    outputChatBox("Brak paczki do dostarczenia w pobliżu.")
end)

-- simple DX display of package count and open tablet (key T)
local showTablet = false
bindKey("t", "down", function()
    showTablet = not showTablet
end)

addEventHandler("onClientRender", root, function()
    -- top-left small HUD
    dxDrawText("Job: packages "..tostring(#(assignedPackages and table.count or {})), 10, 30, screenW, screenH, tocolor(255,255,255,255), 1, font)
    -- tablet UI
    if showTablet then
        local w, h = 480, 320
        local x, y = (screenW - w)/2, (screenH - h)/2
        dxDrawRectangle(x, y, w, h, tocolor(10,10,10,200))
        dxDrawText("Tablet Kurierski - Lista paczek", x + 12, y + 8, x + w - 12, y + 32, tocolor(220,220,220), 1.2, font)
        local oy = y + 40
        for id,meta in pairs(assignedPackages) do
            dxDrawText("ID:"..id.." Val:"..meta.baseValue.." Exp:"..tostring(meta.express), x + 12, oy, x + w - 12, oy + 18, tocolor(200,200,200), 1, font)
            oy = oy + 20
        end
    end
end)

-- helper count (since Lua doesn't have table.count)
function table.count(t)
    local c=0
    for _ in pairs(t) do c=c+1 end
    return c
end
