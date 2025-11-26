-- FILE: tr_job_courier/server.lua
-- put this file: server.lua
-- Server-side logic: generowanie paczek, start/finish job, logika płatności, losowe zdarzenia

local DB = exports.tr_databaseConnector -- expects exports with exec, query, fetchOne compatible
local packages = {}       -- in-memory: packageId -> packageData
local playerJobs = {}     -- player -> jobData (packages list, vehicle, startTime)
local nextPackageId = 1

-- helper: notify (tries to use tr-notifications, fallback chat)
local function notify(player, text, typ)
    if isElement(player) then
        if exports["tr-notifications"] and exports["tr-notifications"].addNotification then
            pcall(function() exports["tr-notifications"]:addNotification(player, text, typ or "info") end)
            return
        end
        outputChatBox("[JOB] "..text, player, 200, 200, 255)
    end
end

-- generate a single package
local function generatePackage()
    local id = nextPackageId
    nextPackageId = nextPackageId + 1

    local sizeCategory = math.random(1,3) -- 1 small,2 med,3 large
    local weight = math.random(1, 30) * sizeCategory
    local baseValue = math.random(20, 400) * sizeCategory
    local isExpress = (math.random() <= JOB.pctExpress)
    local isFragile = (math.random() <= JOB.pctFragile)
    local isHighValue = (math.random() <= JOB.pctHighValue)
    local isSuspicious = (math.random() <= JOB.pctSuspicious)

    if isHighValue then baseValue = baseValue * 2 end
    local target = JOB.deliveryPoints[math.random(#JOB.deliveryPoints)]
    local package = {
        id = id,
        size = sizeCategory,
        weight = weight,
        baseValue = baseValue,
        express = isExpress,
        fragile = isFragile,
        highValue = isHighValue,
        suspicious = isSuspicious,
        target = target,
        status = "created", -- created, scanned, sorted, packed, in_transit, delivered, returned
        created_at = os.time()
    }
    packages[id] = package

    -- optional DB save
    if DB and DB.exec then
        pcall(function()
            DB.exec("INSERT INTO job_packages (pkg_id, sizeC, weight, baseValue, express, fragile, highValue, suspicious, targetX, targetY, targetZ, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())",
                {id, package.size, package.weight, package.baseValue, package.express and 1 or 0, package.fragile and 1 or 0, package.highValue and 1 or 0, package.suspicious and 1 or 0, package.target[1], package.target[2], package.target[3], package.status})
        end)
    end

    return package
end

-- generate N packages
local function generatePackages(n)
    local list = {}
    for i=1,n do
        local p = generatePackage()
        table.insert(list, p)
    end
    return list
end

-- start shift / job
local function startShift(player)
    if not isElement(player) then return end
    if playerJobs[player] then
        notify(player, "Masz już aktywną pracę.", "warning")
        return
    end

    local count = math.random(3, math.min(JOB.maxPackagesPerShift, 5))
    local pkgs = generatePackages(count)
    local jobData = {
        packages = {},
        vehicle = nil,
        startTime = os.time(),
    }
    for _,p in ipairs(pkgs) do
        jobData.packages[p.id] = p
    end
    playerJobs[player] = jobData

    -- send client assignment (only metadata)
    local metaList = {}
    for id,p in pairs(jobData.packages) do
        table.insert(metaList, { id = p.id, size = p.size, baseValue = p.baseValue, express = p.express, fragile = p.fragile, highValue = p.highValue })
    end

    triggerClientEvent(player, "job:assignment", resourceRoot, metaList, JOB.startPoint)
    notify(player, "Przyjęto zlecenie magazynowe. Sprawdź terminal.", "success")
end
addEvent("job:startShift", true)
addEventHandler("job:startShift", root, function()
    startShift(client)
end)
exports("startShift", startShift)

-- scan package (from client)
addEvent("job:scanPackage", true)
addEventHandler("job:scanPackage", root, function(pkgId)
    local player = client
    if not playerJobs[player] then notify(player, "Nie masz aktywnej pracy.", "error"); return end
    local job = playerJobs[player]
    local pkg = packages[pkgId]
    if not pkg then notify(player, "Paczka nie znaleziona.", "error"); return end
    if pkg.status ~= "created" then notify(player, "Ta paczka jest już zeskanowana.", "warning"); return end

    -- distance check: package must be near player - client should validate as well
    local px,py,pz = getElementPosition(player)
    -- we don't have real package entity coordinates in this MVP; assume scanning at terminal allowed
    pkg.status = "scanned"

    -- log
    if DB and DB.exec then
        pcall(function() DB.exec("UPDATE job_packages SET status=? WHERE pkg_id=?", { pkg.status, pkg.id }) end)
    end

    notify(player, "Paczka zeskanowana: #"..pkg.id, "info")
    triggerClientEvent(player, "job:packageScanned", resourceRoot, pkg.id)
end)

-- sort package to sector
addEvent("job:sortPackage", true)
addEventHandler("job:sortPackage", root, function(pkgId, sectorName)
    local player = client
    if not playerJobs[player] then notify(player, "Brak pracy", "error"); return end
    local pkg = packages[pkgId]
    if not pkg then notify(player, "Paczka nie istnieje", "error"); return end
    if pkg.status ~= "scanned" then notify(player, "Najpierw zeskanuj paczkę.", "warning"); return end

    -- assign sector
    pkg.status = "sorted"
    pkg.sector = sectorName
    if DB and DB.exec then
        pcall(function() DB.exec("UPDATE job_packages SET status=?, extra=? WHERE pkg_id=?", { pkg.status, tostring(sectorName), pkg.id }) end)
    end
    notify(player, "Paczka #"..pkg.id.." posortowana do sektora "..(sectorName or "-"), "success")
    triggerClientEvent(player, "job:packageSorted", resourceRoot, pkg.id, sectorName)
end)

-- prepare delivery: pack selected packages and spawn vehicle
addEvent("job:prepareDelivery", true)
addEventHandler("job:prepareDelivery", root, function(pkgIdList)
    local player = client
    if not playerJobs[player] then notify(player, "Nie masz pracy", "error"); return end
    local job = playerJobs[player]

    -- validate
    local toDeliver = {}
    for _,pid in ipairs(pkgIdList) do
        local pkg = packages[pid]
        if pkg and (pkg.status == "sorted" or pkg.status=="scanned") then
            table.insert(toDeliver, pkg)
            pkg.status = "packed"
        end
    end
    if #toDeliver == 0 then notify(player, "Brak paczek do zapakowania.", "warning"); return end

    -- spawn vehicle near player
    local px,py,pz = getElementPosition(player)
    local model = JOB.vehicleModels.van
    local veh = createVehicle(model, px + 3, py, pz)
    setElementData(veh, "jobVehicle", true)
    setVehicleLocked(veh, false)
    playerJobs[player].vehicle = veh
    playerJobs[player].toDeliver = toDeliver

    notify(player, "Pojazd przygotowany. Załaduj paczki i jedź do punktów.", "success")
    triggerClientEvent(player, "job:vehicleReady", resourceRoot, veh)
end)

-- deliver package (arrived at target)
addEvent("job:deliverPackage", true)
addEventHandler("job:deliverPackage", root, function(pkgId)
    local player = client
    if not playerJobs[player] then notify(player, "Masz już zakończoną pracę.", "error"); return end
    local job = playerJobs[player]
    if not job.toDeliver then notify(player, "Brak załadowanych paczek.", "error"); return end

    local targetPkg = nil
    for i,p in ipairs(job.toDeliver) do
        if p.id == pkgId then targetPkg = p; table.remove(job.toDeliver, i); break end
    end
    if not targetPkg then notify(player, "Ta paczka nie jest załadowana.", "error"); return end

    -- compute payout
    local base = targetPkg.baseValue + math.random(JOB.salaryRange.min, JOB.salaryRange.max)
    if targetPkg.express then base = base * JOB.expressMultiplier end
    if targetPkg.fragile then base = math.floor(base * JOB.fragilePenalty) end
    if targetPkg.highValue then base = math.floor(base * JOB.highValueMultiplier) end

    -- random events: if suspicious, player must take special action (for MVP: penalty)
    if targetPkg.suspicious and math.random() < 0.5 then
        -- event: return to base for inspection
        targetPkg.status = "returned"
        notify(player, "Paczka podejrzana — zwrócono do magazynu. Brak wypłaty.", "warning")
        if DB and DB.exec then pcall(function() DB.exec("UPDATE job_packages SET status=? WHERE pkg_id=?", {targetPkg.status, targetPkg.id}) end) end
        return
    end

    -- deliver success
    targetPkg.status = "delivered"
    if DB and DB.exec then pcall(function() DB.exec("UPDATE job_packages SET status=?, delivered_at=NOW() WHERE pkg_id=?", {targetPkg.status, targetPkg.id}) end) end

    -- give money (element data)
    local curMoney = tonumber(getElementData(player, "player:money")) or 0
    setElementData(player, "player:money", curMoney + base)

    -- reputation / rating (simple)
    local rep = tonumber(getElementData(player, "player:rep")) or 0
    rep = rep + math.floor(base / 100)
    setElementData(player, "player:rep", rep)

    notify(player, "Dostarczono paczkę #"..targetPkg.id.." — otrzymujesz $"..base, "success")
    -- log
    if DB and DB.exec then pcall(function() DB.exec("INSERT INTO job_logs (tid, pkg_id, action, amount, created_at) VALUES (?, ?, ?, ?, NOW())", { tostring(getElementData(player,"player:tid") or ""), targetPkg.id, "delivered", base }) end) end

    -- finish shift if no packages left
    local remaining = 0
    for _,p in pairs(job.packages) do if p.status ~= "delivered" and p.status ~= "returned" then remaining = remaining + 1 end end
    if remaining == 0 then
        notify(player, "Wszystkie paczki obsłużone. Shift zakończony.", "success")
        -- cleanup vehicle
        if isElement(job.vehicle) then destroyElement(job.vehicle) end
        playerJobs[player] = nil
    end
end)

-- cancel / player quit cleanup
addEventHandler("onPlayerQuit", root, function()
    local p = source
    if playerJobs[p] and isElement(playerJobs[p].vehicle) then destroyElement(playerJobs[p].vehicle) end
    playerJobs[p] = nil
end)

-- simple admin command to spawn packages for testing
addCommandHandler("genpkgs", function(player, cmd, n)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Admin")) then
        outputChatBox("Brak uprawnień.", player)
        return
    end
    local count = tonumber(n) or 5
    local created = generatePackages(count)
    outputChatBox("Wygenerowano "..#created.." paczek (serwer).", player)
end)

-- expose small APIs
exports("generatePackage", generatePackage)
exports("startShift", startShift)
