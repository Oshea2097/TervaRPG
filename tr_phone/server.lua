local db = dbConnect("mysql", "dbname=db_110580;host=sql.25.svpj.link;port=3306;charset=utf8", "db_110580", "ctU312bng65od6ib")

local pickupPoints = {
    {npcSkin=155, name="Pizzeria Mario", x=2100.5, y=-1800.3, z=13.5},
    {npcSkin=205, name="BurgerShot", x=2030.5, y=-1500.3, z=13.5}
}

local dropPoints = {
    {name="Anna (Market)", x=2150.5, y=-1720.6, z=13.5},
    {name="Bartek (Glen Park)", x=2210.3, y=-1680.2, z=15.0}
}

local activeOrders = {}

function getUserID(player)
    return getElementData(player, "user:id") or 0
end

addEvent("glovo:checkStatus", true)
addEventHandler("glovo:checkStatus", resourceRoot, function()
    local userID = getUserID(client)
    local q = dbQuery(db, "SELECT * FROM glovo_users WHERE user_id = ?", userID)
    local res = dbPoll(q, -1)
    triggerClientEvent(client, "glovo:setCourierStatus", resourceRoot, res and #res > 0)
end)

addEvent("glovo:registerAsCourier", true)
addEventHandler("glovo:registerAsCourier", resourceRoot, function()
    local userID = getUserID(client)
    dbExec(db, "INSERT IGNORE INTO glovo_users (user_id) VALUES (?)", userID)
    triggerClientEvent(client, "glovo:setCourierStatus", resourceRoot, true)
end)

for _,point in ipairs(pickupPoints) do
    local npc = createPed(point.npcSkin, point.x, point.y, point.z)
    setElementFrozen(npc, true)
    local marker = createMarker(point.x, point.y, point.z - 1, "cylinder", 1.2, 255, 255, 0, 100)

    addEventHandler("onMarkerHit", marker, function(player)
        triggerClientEvent(player, "glovo:showDialog", resourceRoot, "Naciśnij E aby zacząć dostawę z "..point.name)
        setElementData(player, "glovo:currentPickup", point)
    end)

    addEventHandler("onMarkerLeave", marker, function(player)
        setElementData(player, "glovo:currentPickup", nil)
    end)
end

addEvent("glovo:startDelivery", true)
addEventHandler("glovo:startDelivery", resourceRoot, function()
    local pickup = getElementData(client, "glovo:currentPickup")
    if not pickup then return end

    local drop = dropPoints[math.random(#dropPoints)]
    local markerDrop = createMarker(drop.x, drop.y, drop.z -1, "cylinder", 1.2, 0, 255, 0, 150)
    setElementVisibleTo(markerDrop, root, false)

    activeOrders[client] = {
        stage="pickup",
        markerDrop=markerDrop,
        drop=drop,
        carrying=false
    }

    setElementVisibleTo(markerDrop, client, true)
    triggerClientEvent(client, "glovo:showDialog", resourceRoot, "Podejdź do skutera i wciśnij E, aby włożyć paczkę do bagażnika.")
end)

addEvent("glovo:interact", true)
addEventHandler("glovo:interact", resourceRoot, function()
    local order = activeOrders[client]
    if not order then return end

    if order.stage == "pickup" then
        order.stage = "bag"
        triggerClientEvent(client, "glovo:showDialog", resourceRoot, "Paczka w bagażniku! Podejdź ponownie i wciśnij E, by wyjąć.")
    elseif order.stage == "bag" then
        order.stage = "delivery"
        order.carrying = true
        local obj = createObject(1581, 0,0,0)
        exports.bone_attach:attachElementToBone(obj, client, 12,0.1,0,0.3,0,90,0)
        order.obj = obj
        triggerClientEvent(client, "glovo:showDialog", resourceRoot, "Jedź do "..order.drop.name)
    end
end)

addEventHandler("onMarkerHit", root, function(player, dim)
    if not dim or getElementType(player)~="player" then return end
    local order=activeOrders[player]
    if not order or source~=order.markerDrop or not order.carrying then return end

    if isElement(order.obj) then destroyElement(order.obj) end
    destroyElement(order.markerDrop)
    givePlayerMoney(player,500)
    local uid=getUserID(player)
    dbExec(db,"UPDATE glovo_users SET deliveries=deliveries+1 WHERE user_id=?",uid)
    activeOrders[player]=nil
    triggerClientEvent(player,"glovo:showDialog",resourceRoot,"Dostawa zakończona! Zarabiasz 500$")
end)
