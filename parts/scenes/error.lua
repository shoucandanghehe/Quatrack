local gc=love.graphics
local rnd=math.random

local BGcolor
local sysAndScn,errorText
local errorShot,errorInfo

local scene={}

function scene.sceneInit()
    BGcolor=rnd()>.026 and{.3,.5,.9}or{.62,.3,.926}
    sysAndScn=SYSTEM.."-"..VERSION.string.."       scene:"..Z.getErr('#').scene
    errorText=LOADED and text.errorMsg or"An error has occurred while the game was loading.\nAn error log has been created so you can send it to the author."
    errorShot,errorInfo=Z.getErr('#').shot,Z.getErr('#').mes
    if SETTING then
        SFX.fplay('error',SETTING.voc*.8 or 0)
    end
end

function scene.draw()
    gc.clear(BGcolor)
    gc.setColor(1,1,1)
    gc.draw(errorShot,100,326,nil,512/errorShot:getWidth(),288/errorShot:getHeight())
    gc.setColor(COLOR.Z)
    setFont(100)gc.print(":(",100,0,0,1.2)
    setFont(40)gc.printf(errorText,100,160,SCR.w0-100)
    setFont(20,'mono')
    gc.print(sysAndScn,100,630)
    setFont(15,'mono')
    gc.printf(errorInfo[1],626,326,1260-626)
    gc.print("TRACEBACK",626,390)
    for i=4,#errorInfo do
        gc.print(errorInfo[i],626,340+20*i)
    end
end

scene.widgetList={
    WIDGET.newKey{name='console',x=940,y=640,w=170,h=80,font=65,fText=CHAR.icon.console,code=goScene'app_console'},
    WIDGET.newKey{name='quit',x=1140,y=640,w=170,h=80,font=40,fText=CHAR.icon.cross_thick,code=love.event.quit},
}

return scene
