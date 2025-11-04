-- FILE: admins/admin_gui.lua
-- Client-side CEF integration for Admin Panel (F2)
-- - creates/destroys CEF browser
-- - toggles panel with F2
-- - receives UI actions via onClientBrowserConsole (console.log bridge)
-- - forwards actions to server via triggerServerEvent("admin:action", ...)
-- - sendToUI(name, table) -> executes JS: window.receiveFromLua(name, payload)

local AdminGUI = {}
AdminGUI.__index = AdminGUI

-- Config
local GUI_PATH = "admins/gui/index.html" -- relative to resource
local TOGGLE_KEY = "F2"
local CONSOLE_PREFIX = "admin:action:" -- prefix in console.log from JS
local BROWSER = nil
local VISIBLE = false

-- Utility: JSON encode (use toJSON if available)
local function encodeJSON(tbl)
    if type(tbl) == "table" then
        if type(toJSON) == "function" then return toJSON(tbl) end
        -- minimal encoder (for reasonable payloads)
        local function esc(s)
            return tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')
        end
        local parts = {}
        local isArray = (#tbl > 0)
        if isArray then
            for i=1,#tbl do
                local v = tbl[i]
                if type(v) == "string" then table.insert(parts, '"' .. esc(v) .. '"')
                elseif type(v) == "number" or type(v) == "boolean" then table.insert(parts, tostring(v))
                elseif type(v) == "table" then table.insert(parts, encodeJSON(v))
                else table.insert(parts, 'null') end
            end
            return "["..table.concat(parts, ",").."]"
        else
            for k,v in pairs(tbl) do
                local key = '"'..esc(k)..'":'
                local val
                if type(v) == "string" then val = '"'..esc(v)..'"'
                elseif type(v) == "number" or type(v) == "boolean" then val = tostring(v)
                elseif type(v) == "table" then val = encodeJSON(v)
                else val = 'null' end
                table.insert(parts, key .. val)
            end
            return "{"..table.concat(parts, ",").."}"
        end
    end
    return 'null'
end

-- Debug log
local function dbg(fmt, ...)
    outputDebugString(("[admin_gui] " .. fmt):format(...))
end

-- Create browser and load local file
function AdminGUI:createBrowser()
    if BROWSER and isElement(BROWSER) then return end
    -- create CEF browser
    BROWSER = guiCreateBrowser(0, 0, 1, 1, true, true, false) -- fullscreen
    addEventHandler("onClientBrowserCreated", BROWSER, function()
        -- load resource URL
        local url = "http://mta/" .. GUI_PATH -- MTA maps resource URL to http://mta/<resource>/<path>
        loadBrowserURL(BROWSER, url)
        -- attach console handler for JS->Lua messages
        addEventHandler("onClientBrowserConsole", BROWSER, AdminGUI.onBrowserConsole)
        dbg("Browser created, loading %s", url)
    end)
end

-- Destroy browser
function AdminGUI:destroyBrowser()
    if BROWSER and isElement(BROWSER) then
        removeEventHandler("onClientBrowserConsole", BROWSER, AdminGUI.onBrowserConsole)
        destroyElement(BROWSER)
        BROWSER = nil
        collectgarbage()
        dbg("Browser destroyed")
    end
end

-- Toggle panel visibility
function AdminGUI:toggle()
    if not BROWSER or not isElement(BROWSER) then
        self:createBrowser()
        -- small delay may be necessary to ensure browser loaded; we can show when ready via JS handshake
    end
    VISIBLE = not VISIBLE
    showCursor(VISIBLE)
    if BROWSER and isElement(BROWSER) then
        -- set browser visible via execute JS function (we expect UI to have window.showPanel(boolean))
        local js = ("(function(){ if(window.showPanel) { window.showPanel(%s); } })();"):format(tostring(VISIBLE and "true" or "false"))
        executeBrowserJavascript(BROWSER, js)
    end
    dbg("Panel toggled -> %s", tostring(VISIBLE))
end

-- Close panel (force)
function AdminGUI:close()
    if VISIBLE then
        VISIBLE = false
        showCursor(false)
        if BROWSER and isElement(BROWSER) then
            local js = "(function(){ if(window.showPanel) window.showPanel(false); })();"
            executeBrowserJavascript(BROWSER, js)
        end
    end
end

-- Send data to UI: window.receiveFromLua(name, payload)
function AdminGUI:sendToUI(name, payloadTable)
    if not BROWSER or not isElement(BROWSER) then return false end
    local payload = encodeJSON(payloadTable or {})
    -- payload may need escaping inside JS string; we send as object
    local js = ("(function(){ if(window.receiveFromLua) window.receiveFromLua(%q, %s); })();"):format(tostring(name), payload)
    executeBrowserJavascript(BROWSER, js)
    return true
end

-- Parse console messages from browser (JS -> Lua bridge)
-- Expected format: "admin:action:<actionName>:<JSON_payload>"
function AdminGUI.onBrowserConsole(browser, message)
    if type(message) ~= "string" then return end
    if message:sub(1, #CONSOLE_PREFIX) ~= CONSOLE_PREFIX then return end
    local rest = message:sub(#CONSOLE_PREFIX + 1)
    -- rest should be: "<actionName>:<json>"
    local sep = rest:find(":", 1, true)
    local actionName, jsonPart
    if sep then
        actionName = rest:sub(1, sep-1)
        jsonPart = rest:sub(sep+1)
    else
        actionName = rest
        jsonPart = "{}"
    end

    local payload = nil
    if jsonPart and jsonPart ~= "" then
        local ok, res = pcall(function() return fromJSON(jsonPart) end)
        if ok and type(res) == "table" then payload = res else
            -- try fallback: treat as simple string
            payload = { raw = jsonPart }
        end
    else
        payload = {}
    end

    dbg("UI action -> %s ; payload=%s", tostring(actionName), tostring(jsonPart or "{}"))
    -- forward to server for validation & execution
    triggerServerEvent("admin:action", resourceRoot, actionName, payload)
end

-- Bind F2 to toggle panel
local function bindToggle()
    bindKey(TOGGLE_KEY, "down", function()
        -- check if player has permission locally? we ask server to confirm opening; for now allow opening, server will validate actions
        AdminGUI:toggle()
    end)
end

-- Unbind and clean
local function cleanup()
    if isTimer(AdminGUI._handshakeTimer or false) then killTimer(AdminGUI._handshakeTimer) end
    unbindKey(TOGGLE_KEY, "down", AdminGUI.toggle)
    AdminGUI:destroyBrowser()
end

-- resource events
addEventHandler("onClientResourceStart", resourceRoot, function()
    bindToggle()
    dbg("admin_gui resource started")
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    cleanup()
    dbg("admin_gui resource stopped")
end)

-- optional server -> client API: server can trigger show/hide or push data
addEvent("admin:clientShowPanel", true)
addEventHandler("admin:clientShowPanel", root, function(shouldShow)
    if shouldShow then
        if not BROWSER then AdminGUI:createBrowser() end
        if not VISIBLE then AdminGUI:toggle() end
    else
        if VISIBLE then AdminGUI:toggle() end
    end
end)

addEvent("admin:clientSendData", true)
addEventHandler("admin:clientSendData", root, function(name, tbl)
    AdminGUI:sendToUI(name, tbl)
end)

-- Expose for other client scripts if needed
_G.AdminGUI = AdminGUI
