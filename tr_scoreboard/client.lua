local scoreboard = {
    visible = false,
    dataRaw = {},
    dataFiltered = {},
    alpha = 0,
    assets = {},
    loaded = false,
    animStart = 0,
    searchText = "",
    guiSearch = nil
}

local rankColors = {
    ["root"] = tocolor(255, 77, 77, 255),
    ["opiekun administracji"] = tocolor(255, 148, 77, 255),
    ["starszy administrator"] = tocolor(255, 210, 77, 255),
    ["administrator"] = tocolor(163, 255, 77, 255),
    ["moderator"] = tocolor(77, 255, 219, 255),
    ["helper"] = tocolor(77, 148, 255, 255),
    ["test helper"] = tocolor(153, 153, 153, 255),
    ["player"] = tocolor(232,232,232,255)
}

local function loadAssets()
    if scoreboard.loaded then return end
    -- fonts
    scoreboard.assets.font = dxCreateFont("assets/fonts/HoneySalt.ttf", 14, false, "antialiased")
    if not scoreboard.assets.font then
        scoreboard.assets.font = "default-bold"
    end
    -- background image (plain rounded card); code will scale it
    if fileExists("assets/img/board_bg.png") then
        scoreboard.assets.bg = dxCreateTexture("assets/img/board_bg.png")
    else
        scoreboard.assets.bg = nil
    end
    scoreboard.loaded = true
end

local function unloadAssets()
    if not scoreboard.loaded then return end
    for k,v in pairs(scoreboard.assets) do
        if isElement(v) then destroyElement(v) end
        scoreboard.assets[k] = nil
    end
    scoreboard.assets = {}
    scoreboard.loaded = false
end

local function applyFilter()
    if not scoreboard.searchText or scoreboard.searchText == "" then
        scoreboard.dataFiltered = scoreboard.dataRaw
        return
    end
    local q = tostring(scoreboard.searchText):lower()
    local out = {}
    for _, row in ipairs(scoreboard.dataRaw) do
        if tostring(row.name):lower():find(q, 1, true) or tostring(row.id):lower():find(q,1,true) or tostring(row.faction):lower():find(q,1,true) then
            table.insert(out, row)
        end
    end
    scoreboard.dataFiltered = out
end

local function formatPlayTime(pt)
    return tostring(pt or "0h")
end

local function renderScoreboard()
    local sw, sh = guiGetScreenSize()
    local w, h = math.floor(sw * 0.72), math.floor(sh * 0.68)
    local x, y = math.floor((sw - w) / 2), math.floor((sh - h) / 2)

    local progress = math.min(1, math.max(0, (getTickCount() - scoreboard.animStart) / 400))
    if not scoreboard.visible then progress = 1 - progress end
    scoreboard.alpha = math.floor(255 * progress)

    if scoreboard.alpha <= 5 then return end

    -- draw bg (if texture exists use it scaled, otherwise draw rounded rect with dx)
    local bgAlpha = math.floor(200 * (scoreboard.alpha / 255))
    if scoreboard.assets.bg and isElement(scoreboard.assets.bg) then
        dxDrawImage(x, y, w, h, scoreboard.assets.bg, 0,0,0, tocolor(255,255,255,bgAlpha))
    else
        dxDrawRectangle(x, y, w, h, tocolor(12, 13, 22, bgAlpha))
        -- subtle inner overlay for depth
        dxDrawRectangle(x+2, y+2, w-4, h-4, tocolor(16,16,24, math.floor(bgAlpha*0.6)))
    end

    -- header
    local headerText = "TervaRPG | wyszukiwarka graczy | Online: ".. tostring(#scoreboard.dataRaw)
    dxDrawText(headerText, x + 20, y + 14, x + w - 20, y + 46, tocolor(232,232,232,scoreboard.alpha), 1, scoreboard.assets.font, "left", "top")

    -- column headers
    local cols = {
        x + 40,
        x + 120,
        x + 320,
        x + 520,
        x + 720
    }
    local headers = {"ID", "Nick", "Frakcja", "Organizacja", "Czas gry"}
    for i, head in ipairs(headers) do
        dxDrawText(head, cols[i], y + 64, cols[i] + 200, y + 88, tocolor(180,180,180, scoreboard.alpha), 1, scoreboard.assets.font, "left", "top")
    end

    -- rows
    local startY = y + 96
    local rowH = 28
    local maxRows = math.floor((h - 140) / rowH)
    local rows = scoreboard.dataFiltered
    for i = 1, math.min(maxRows, #rows) do
        local r = rows[i]
        local rowY = startY + (i-1) * rowH
        local rank = tostring((r.rank or "player"):lower())
        local color = rankColors[rank] or rankColors["player"]
        -- background stripe
        if (i % 2) == 0 then
            dxDrawRectangle(x + 30, rowY - 2, w - 60, rowH, tocolor(255,255,255, math.floor(scoreboard.alpha * 0.02)))
        end
        dxDrawText(tostring(r.id or "-"), cols[1], rowY, cols[1] + 60, rowY + rowH, color, 1, scoreboard.assets.font, "left", "top")
        dxDrawText(tostring(r.name or "-"), cols[2], rowY, cols[2] + 260, rowY + rowH, color, 1, scoreboard.assets.font, "left", "top")
        dxDrawText(tostring(r.faction or "-"), cols[3], rowY, cols[3] + 180, rowY + rowH, color, 1, scoreboard.assets.font, "left", "top")
        dxDrawText(tostring(r.organization or "-"), cols[4], rowY, cols[4] + 180, rowY + rowH, color, 1, scoreboard.assets.font, "left", "top")
        dxDrawText(formatPlayTime(r.playTime), cols[5], rowY, cols[5] + 120, rowY + rowH, tocolor(220,220,220, scoreboard.alpha), 1, scoreboard.assets.font, "left", "top")
    end

    -- if more rows than visible, show a small hint
    if #rows > maxRows then
        dxDrawText("... więcej", x + 40, y + h - 30, x + 200, y + h - 10, tocolor(180,180,180, scoreboard.alpha), 1, scoreboard.assets.font, "left", "top")
    end
end

-- toggle scoreboard, create/destroy gui search edit
local function createSearchGUI()
    if scoreboard.guiSearch and isElement(scoreboard.guiSearch) then return end
    local sw, sh = guiGetScreenSize()
    local w, h = math.floor(sw * 0.72), math.floor(sh * 0.68)
    local x, y = math.floor((sw - w) / 2), math.floor((sh - h) / 2)
    local edit = guiCreateEdit(x + 260, y + 18, 340, 28, scoreboard.searchText or "", false)
    guiSetAlpha(edit, 0.95)
    guiEditSetReadOnly(edit, false)
    scoreboard.guiSearch = edit

    addEventHandler("onClientGUIChanged", edit, function()
        scoreboard.searchText = guiGetText(edit) or ""
        applyFilter()
    end)
end

local function destroySearchGUI()
    if scoreboard.guiSearch and isElement(scoreboard.guiSearch) then
        removeEventHandler("onClientGUIChanged", scoreboard.guiSearch)
        destroyElement(scoreboard.guiSearch)
        scoreboard.guiSearch = nil
    end
end

function toggleScoreboard()
    scoreboard.visible = not scoreboard.visible
    scoreboard.animStart = getTickCount()
    if scoreboard.visible then
        loadAssets()
        addEventHandler("onClientRender", root, renderScoreboard)
        createSearchGUI()
        guiSetInputEnabled(true)
        triggerServerEvent("scoreboard:requestData", resourceRoot)
    else
        guiSetInputEnabled(false)
        destroySearchGUI()
        -- wait for animation to finish then unload
        setTimer(function()
            if not scoreboard.visible then
                removeEventHandler("onClientRender", root, renderScoreboard)
                unloadAssets()
            end
        end, 450, 1)
    end
end

bindKey("tab", "down", toggleScoreboard)

-- receive data
addEvent("scoreboard:receiveData", true)
addEventHandler("scoreboard:receiveData", resourceRoot, function(data)
    scoreboard.dataRaw = data or {}
    applyFilter()
end)

-- request updates periodically while open
local updateTimer = nil
local function startAutoUpdate()
    if isTimer(updateTimer) then killTimer(updateTimer) end
    updateTimer = setTimer(function()
        if scoreboard.visible then triggerServerEvent("scoreboard:requestData", resourceRoot) end
    end, 5000, 0)
end
startAutoUpdate()
