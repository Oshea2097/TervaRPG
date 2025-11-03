-- ============================================
-- TervaRPG Server Status Sync
-- Automatyczna synchronizacja statusu serwera z aplikacją
-- ============================================

local API_URL = "https://api.base44.com/v1"
local API_KEY = "a260d0f0af8d47c1b28eb217e0eed824" -- Pobierz z Dashboard -> Settings -> Secrets
local APP_ID = "6901c610f8920fd3e49b1a0e" -- Znajdziesz w URL dashboardu
local SERVER_CONFIG_ID = "" -- Zostanie automatycznie pobrane przy pierwszym uruchomieniu

function getServerConfigId()
    if SERVER_CONFIG_ID ~= "" then
        return SERVER_CONFIG_ID
    end
    
    fetchRemote(API_URL .. "/apps/" .. APP_ID .. "/entities/ServerConfig", {
        method = "GET",
        headers = {
            ["Authorization"] = "Bearer " .. API_KEY,
            ["Content-Type"] = "application/json"
        }
    }, function(responseData, errno)
        if errno == 0 then
            local response = fromJSON(responseData)
            if response and response.data and #response.data > 0 then
                SERVER_CONFIG_ID = response.data[1].id
                outputServerLog("[TervaRPG] Server Config ID: " .. SERVER_CONFIG_ID)
            end
        else
            outputServerLog("[TervaRPG] Błąd pobierania config ID: " .. tostring(errno))
        end
    end)
end

function updateServerStatus()
    local currentPlayers = getPlayerCount()
    local maxPlayers = getMaxPlayers()
    
    if SERVER_CONFIG_ID == "" then
        getServerConfigId()
        return
    end
    
    local updateData = {
        current_players = currentPlayers,
        max_players = maxPlayers,
        is_online = true,
        last_updated = getRealTime().timestamp
    }
    
    local jsonData = toJSON(updateData)
    
    fetchRemote(API_URL .. "/apps/" .. APP_ID .. "/entities/ServerConfig/" .. SERVER_CONFIG_ID, {
        method = "PUT",
        postData = jsonData,
        headers = {
            ["Authorization"] = "Bearer " .. API_KEY,
            ["Content-Type"] = "application/json"
        }
    }, function(responseData, errno)
        if errno == 0 then
            outputServerLog("[TervaRPG] Status zaktualizowany: " .. currentPlayers .. "/" .. maxPlayers .. " graczy")
        else
            outputServerLog("[TervaRPG] Błąd aktualizacji statusu: " .. tostring(errno))
        end
    end)
end

addEventHandler("onResourceStart", resourceRoot, function()
    outputServerLog("===========================================")
    outputServerLog("[TervaRPG] Server Status Sync - Włączony")
    outputServerLog("===========================================")
    
    -- Pobierz ID konfiguracji
    getServerConfigId()
    
    -- Poczekaj 5 sekund i zaktualizuj po raz pierwszy
    setTimer(function()
        updateServerStatus()
    end, 5000, 1)
    
    setTimer(updateServerStatus, 30000, 0)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if SERVER_CONFIG_ID ~= "" then
        local offlineData = {
            current_players = 0,
            is_online = false,
            last_updated = getRealTime().timestamp
        }
        
        fetchRemote(API_URL .. "/apps/" .. APP_ID .. "/entities/ServerConfig/" .. SERVER_CONFIG_ID, {
            method = "PUT",
            postData = toJSON(offlineData),
            headers = {
                ["Authorization"] = "Bearer " .. API_KEY,
                ["Content-Type"] = "application/json"
            }
        })
    end
    
    outputServerLog("[TervaRPG] Server Status Sync - Wyłączony")
end)

addEventHandler("onPlayerJoin", root, function()
    setTimer(updateServerStatus, 1000, 1) -- Czekaj sekundę i aktualizuj
end)

addEventHandler("onPlayerQuit", root, function()
    setTimer(updateServerStatus, 1000, 1)
end)

outputServerLog("[TervaRPG] Skrypt załadowany!")
