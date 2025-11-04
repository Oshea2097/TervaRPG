-- Anti-spam + blacklist + logging to chat_logs

local Chat = {}
Chat.__index = Chat

function Chat:new(core)
    local o = {
        core = core,
        rateLimit = { count = 5, window = 7 }, -- 5 messages per 7 sec
        recent = {},   -- recent[serial] = {ts,ts,...}
        blacklist = { "kurwa", "idiota", "fuck" } -- tune it
    }
    setmetatable(o, self)
    core.db:prepare("chat_insert", "INSERT INTO chat_logs (serial, name, message, created_at) VALUES (?, ?, ?, NOW())")
    return o
end

local function now() return os.time() end

function Chat:isSpam(serial)
    local list = self.recent[serial] or {}
    local cur = now()
    local filtered = {}
    for _,ts in ipairs(list) do if cur - ts <= self.rateLimit.window then table.insert(filtered, ts) end end
    table.insert(filtered, cur)
    self.recent[serial] = filtered
    return #filtered > self.rateLimit.count
end

function Chat:containsBlacklisted(msg)
    if not msg then return false end
    local low = tostring(msg):lower()
    for _,w in ipairs(self.blacklist) do
        if low:find(w, 1, true) then return true, w end
    end
    return false
end

function Chat:handleChat(player, message)
    if not isElement(player) then return false end
    local serial = getPlayerSerial(player) or getPlayerName(player)
    if self:isSpam(serial) then
        outputChatBox("[Core] AntiSpam: za dużo wiadomości.", player, 255,100,100)
        return true
    end
    local bad, word = self:containsBlacklisted(message)
    if bad then
        outputChatBox("[Core] Wiadomość zawiera zabronione słowo: "..tostring(word), player, 255,100,100)
        self.core.punishments:warn(serial, "chat blacklist: "..tostring(word), "chatfilter")
        return true
    end
    -- log to DB (async via prepared)
    pcall(function()
        self.core.db:execPrepared("chat_insert", serial, tostring(getPlayerName(player) or ""), tostring(message))
    end)
    return false
end

return Chat
