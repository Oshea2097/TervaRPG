-- tr_admins/admin_client.lua

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

function createAdminPanel(data)
    if panelVisible then return end
    browser = createBrowser(screenW, screenH, true, true)
    loadBrowserURL(browser, "http://mta/local/html/index.html")
    showCursor(true)
    focusBrowser(browser)
    panelVisible = true
    addEventHandler("onClientBrowserDocumentReady", browser, function()
        executeBrowserJavascript(browser, string.format("initAdminPanel(%s)", toJSON(data)))
    end)
end

function destroyAdminPanel()
    if not panelVisible then return end
    destroyElement(browser)
    showCursor(false)
    browser = nil
    panelVisible = false
end

addEvent("admin:clientShowPanel", true)
addEventHandler("admin:clientShowPanel", root, function(success, data)
    if not success then
        outputChatBox("[ADMIN] " .. tostring(data), 255, 80, 80)
        return
    end
    createAdminPanel(data)
end)

addEvent("admin:closePanel", true)
addEventHandler("admin:closePanel", root, destroyAdminPanel)

addEvent("admin:receivePlayers", true)
addEventHandler("admin:receivePlayers", root, function(players)
    if browser and isElement(browser) then
        executeBrowserJavascript(browser, string.format("updatePlayers(%s)", toJSON(players)))
    end
end)

addEvent("admin:notify", true)
addEventHandler("admin:notify", root, function(msg)
    if browser and isElement(browser) then
        executeBrowserJavascript(browser, string.format("notify('%s')", msg))
    end
end)
