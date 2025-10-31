local sw,sh=guiGetScreenSize()
local phoneTexture,isCourier=nil,false
local dialogText,showDialogUntil="",0

addEventHandler("onClientResourceStart",resourceRoot,function()
    phoneTexture=dxCreateTexture("telefon.png")
    triggerServerEvent("glovo:checkStatus",resourceRoot)
end)

bindKey("b","down",function()
    showCursor(not isCursorShowing())
end)

bindKey("e","down",function()
    triggerServerEvent("glovo:interact",resourceRoot)
    triggerServerEvent("glovo:startDelivery",resourceRoot)
end)

addEvent("glovo:setCourierStatus",true)
addEventHandler("glovo:setCourierStatus",resourceRoot,function(st)
    isCourier=st
end)

addEvent("glovo:showDialog",true)
addEventHandler("glovo:showDialog",resourceRoot,function(txt)
    dialogText=txt
    showDialogUntil=getTickCount()+5000
end)

addEventHandler("onClientRender",root,function()
    local w,h=200,350
    local x,y=sw-w-20,sh-h-20

    if phoneTexture then
        dxDrawImage(x,y,w,h,phoneTexture)
    else
        dxDrawRectangle(x,y,w,h,tocolor(10,10,10,220))
    end

    local bx,by,bw,bh=x+20,y+h-60,w-40,30
    dxDrawRectangle(bx,by,bw,bh,tocolor(255,200,0))
    dxDrawText("Glovo App",bx,by,bx+bw,by+bh,tocolor(0,0,0),1,"default-bold","center","center")

    if getTickCount()<showDialogUntil then
        dxDrawRectangle(sw*0.3,sh*0.85,sw*0.4,30,tocolor(0,0,0,180))
        dxDrawText(dialogText,sw*0.3,sh*0.85,sw*0.7,sh*0.85+30,tocolor(255,255,255),1,"default-bold","center","center")
    end
end)
