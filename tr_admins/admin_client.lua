
-- Klient panelu administracyjnego (CEF)

local panelVisible = false
local browser = nil
local screenW, screenH = guiGetScreenSize()

bindKey("F2", "down", function()
    if not panelVisible then
        triggerServerEvent("admin:requestOpen", localPlayer)
    else
        destroyAdminPanel()
    end
end)

-- Tworzenie panelu CEF
function createAdminPanel(data)
    if panelVisible then return end

    browser = createBrowser(screenW, screenH, true, true)
    loadBrowserURL(browser, "http://mta/local/html/index.html")
    showCursor(true)
    focusBrowser(browser)
    panelVisible = true

    -- Przekazujemy dane do przeglądarki
    addEventHandler("onClientBrowserDocumentReady", browser, function()
        local json = toJSON(data)
        executeBrowserJavascript(browser, string.format("initAdminPanel(%s)", json))
    end)
end

-- Niszczenie panelu
function destroyAdminPanel()
    if not panelVisible then return end
    destroyElement(browser)
    showCursor(false)
    browser = nil
    panelVisible = false
end

-- Odbiór danych z serwera
addEvent("admin:clientShowPanel", true)
addEventHandler("admin:clientShowPanel", root, function(success, data)
    if not success then
        outputChatBox("[ADMIN] " .. tostring(data), 255, 80, 80)
        return
    end
    createAdminPanel(data)
end)

-- Zamykanie panelu z poziomu CEF
addEvent("admin:closePanel", true)
addEventHandler("admin:closePanel", root, destroyAdminPanel)
