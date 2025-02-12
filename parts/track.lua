local gc=love.graphics
local gc_push,gc_pop=gc.push,gc.pop
local gc_translate,gc_rotate=gc.translate,gc.rotate
local gc_setColor=gc.setColor
local gc_rectangle=gc.rectangle

local ins,rem=table.insert,table.remove
local max,min=math.max,math.min
local interval=MATH.interval

local SETTING=SETTING

local Track={}

local function _insert(t,v)
    for i=#t,1,-1 do
        if t[i].mode==v.mode then
            rem(t,i)
            break
        end
    end
    ins(t,1,v)
end
function Track.new(id)
    local track={
        id=id,
        name='',
        showname='',
        chordColor=defaultChordColor,
        pressed=false,
        lastPressTime=-1e99,
        lastReleaseTime=-1e99,
        time=0,
        notes={},
        animQueue={insert=_insert},--Current animation data
        state={
            x=0,y=0,
            ang=0,
            kx=1,ky=1,
            dropSpeed=1000,
            r=1,g=1,b=1,alpha=100,
            available=true,
            nameTime=0,
        },
        defaultState=false,
        targetState=false,
    }
    track.defaultState=TABLE.copy(track.state)
    track.startState=TABLE.copy(track.state)
    track.targetState=TABLE.copy(track.state)
    return setmetatable(track,{__index=Track})
end

function Track:rename(name)
    self.name=name.." "
    self.showName=self.name
    if self.showName:find(" ")then self.showName=self.showName:sub(1,self.showName:find(" ")-1)end
    self.showName=KEY_MAP_inv[self.showName]:upper()
end

function Track:setChordColor(chordColor)
    self.chordColor=chordColor
end

function Track:setDefaultPosition(x,y)self.defaultState.x,self.defaultState.y=x,y end
function Track:setDefaultAngle(ang)self.defaultState.ang=ang end
function Track:setDefaultSize(kx,ky)self.defaultState.kx,self.defaultState.ky=kx,ky end
function Track:setDefaultDropSpeed(speed)self.defaultState.dropSpeed=speed end
function Track:setDefaultAlpha(alpha)self.defaultState.alpha=interval(alpha,0,100)end
function Track:setDefaultAvailable(bool)self.defaultState.available=bool end
function Track:setDefaultColor(r,g,b)self.defaultState.r,self.defaultState.g,self.defaultState.b=interval(r,0,1),interval(g,0,1),interval(b,0,1) end

function Track:movePosition(animData,dx,dy)
    self:setPosition(animData,self.targetState.x+(dx or 0),self.targetState.y+(dy or 0))
end
function Track:moveAngle(animData,da)
    self:setAngle(animData,self.targetState.ang+(da or 0))
end
function Track:moveSize(animData,dkx,dky)
    self:setSize(animData,self.targetState.kx+(dkx or 0),self.targetState.ky+(dky or 0))
end
function Track:moveDropSpeed(animData,dds)
    self:setDropSpeed(animData,self.targetState.dropSpeed+dds)
end
function Track:moveAlpha(animData,da)
    self:setAlpha(animData,self.targetState.alpha+da)
end
function Track:moveAvailable()--wtf
    self:setAvailable(not self.state.available)
end
function Track:moveColor(animData,dr,dg,db)
    self:setColor(animData,
        interval(self.targetState.r+(dr or 0),0,1),
        interval(self.targetState.g+(dg or 0),0,1),
        interval(self.targetState.b+(db or 0),0,1)
    )
end

function Track:setPosition(animData,x,y)
    self.startState.x,self.startState.y=self.targetState.x,self.targetState.y
    self.targetState.x,self.targetState.y=x or self.defaultState.x,y or self.defaultState.y
    self.animQueue:insert{mode='position',data=animData}
end
function Track:setAngle(animData,ang)
    self.startState.ang=self.targetState.ang
    self.targetState.ang=ang or self.defaultState.ang
    self.animQueue:insert{mode='angle',data=animData}
end
function Track:setSize(animData,kx,ky)
    self.startState.kx,self.startState.ky=self.targetState.kx,self.targetState.ky
    self.targetState.kx,self.targetState.ky=kx or self.defaultState.kx,ky or self.defaultState.ky
    self.animQueue:insert{mode='size',data=animData}
end
function Track:setDropSpeed(animData,dropSpeed)
    self.startState.dropSpeed=self.targetState.dropSpeed
    self.targetState.dropSpeed=dropSpeed or self.defaultState.dropSpeed
    self.animQueue:insert{mode='dropSpeed',data=animData}
end
function Track:setAlpha(animData,alpha)
    self.startState.alpha=self.targetState.alpha
    self.targetState.alpha=interval(alpha or self.defaultState.alpha,0,100)
    self.animQueue:insert{mode='alpha',data=animData}
end
function Track:setAvailable(bool)
    if bool==nil then bool=self.defaultState.available end
    self.state.available=bool
    if not self.state.available and self.pressed then
        self.pressed=false
        self.lastReleaseTime=self.time
    end
end
function Track:setColor(animData,r,g,b)
    self.startState.r,self.startState.g,self.startState.b=self.targetState.r,self.targetState.g,self.targetState.b
    self.targetState.r,self.targetState.g,self.targetState.b=r or self.defaultState.r,g or self.defaultState.g,b or self.defaultState.b
    self.animQueue:insert{mode='color',data=animData}
end
function Track:setNameTime(nameTime)
    if not nameTime then nameTime=self.defaultState.nameTime end
    self.targetState.nameTime=nameTime
end

function Track:addItem(note)
    table.insert(self.notes,note)
end
function Track:pollNote(mode)
    local l=self.notes
    if mode=='note'then
        for i=1,#l do
            if
                l[i].type=='tap'or
                l[i].type=='hold'and l[i].active and l[i].head
            then
                return i,l[i]
            end
        end
    elseif mode=='hold'then
        for i=1,#l do
            if
                l[i].type=='hold'and l[i].active
            then
                return i,l[i]
            end
        end
    end
end

local holdHeadSFX={
    'hold4',
    'hold3',
    'hold2',
    'hold1',
    'hold1',
}
function Track:press(auto)
    --Animation
    self.pressed=true
    self.lastPressTime=self.time

    --Check first note
    local i,note=self:pollNote('note')
    if note and(auto or note.available)and self.time>note.time-note.trigTime then
        local deviateTime=self.time-note.time
        local hitLV=getHitLV(deviateTime)
        local _1,_2,_3
        if hitLV>0 then
            _1,_2,_3=note:getAlpha(1),self.state.x/420,-(math.abs(hitLV-4.5)-.5)
        end
        if note.type=='tap'then--Press tap note
            rem(self.notes,i)
            if _1 then
                SFX.play('hit_tap',.4+.6*_1,_2,_3)
            end
        elseif note.type=='hold'then--Press hold note
            if not note.head then return end
            note.head=false
            if _1 then
                SFX.play('hit_tap',.4+.5*_1,_2,_3)
                SFX.play(holdHeadSFX[hitLV],.4+.6*_1,_2)
            end
        end
        return deviateTime
    end
end

local holdTailSFX={
    'hit8',
    'hit7',
    'hit6',
    'hit5',
    'hit5',
}
function Track:release(auto)
    self.pressed=false
    self.lastReleaseTime=self.time
    local i,note=self:pollNote('hold')
    if note and(auto or note.available)and note.type=='hold'and not note.head then--Release hold note
        local deviateTime=note.etime-self.time
        local hitLV=getHitLV(deviateTime)
        if self.time>note.etime-note.trigTime then
            if note.tail and hitLV>0 then
                SFX.play(holdTailSFX[hitLV],.4+.6*note:getAlpha(1),self.state.x/420)
            end
            rem(self.notes,i)
        else
            note.active=false
        end
        return deviateTime,not note.tail
    end
end

local approach,lerp=MATH.expApproach,MATH.lerp
local animManager={
    position={'x','y'},
    angle={'ang'},
    size={'kx','ky'},
    dropSpeed={'dropSpeed'},
    alpha={'alpha'},
    color={'r','g','b'},
}
function Track:update(dt)
    local s=self.state
    local S=self.startState
    local T=self.targetState

    if T.nameTime>0 then
        T.nameTime=max(T.nameTime-dt,0)
    end
    if s.nameTime~=T.nameTime then
        if s.nameTime<T.nameTime then
            s.nameTime=min(s.nameTime+2.6*dt,T.nameTime)
        else
            s.nameTime=max(s.nameTime-dt,T.nameTime)
        end
    end

    for i=#self.animQueue,1,-1 do
        local a=self.animQueue[i]
        local animData=a.data
        local animKeys=animManager[a.mode]
        if animData.type=='S'then
            for j=1,#animKeys do
                s[animKeys[j]]=T[animKeys[j]]
            end
            rem(self.animQueue,i)
        elseif animData.type=='L'then
            for j=1,#animKeys do
                s[animKeys[j]]=lerp(S[animKeys[j]],T[animKeys[j]],(self.time-animData.start)/animData.duration)
            end
            if self.time>animData.start+animData.duration then
                for j=1,#animKeys do
                    s[animKeys[j]]=T[animKeys[j]]
                end
                rem(self.animQueue,i)
            end
        elseif animData.type=='E'then
            for j=1,#animKeys do
                s[animKeys[j]]=approach(s[animKeys[j]],T[animKeys[j]],animData.speed*dt)
            end
            if self.time>animData.start+10/animData.speed then
                for j=1,#animKeys do
                    s[animKeys[j]]=T[animKeys[j]]
                end
                rem(self.animQueue,i)
            end
        end
    end
end

--Logics
function Track:updateLogic(time)
    self.time=time
    local missCount,marvCount=0,0
    for i=#self.notes,1,-1 do
        local note=self.notes[i]
        if note.type=='tap'then
            if self.time>note.time+note.lostTime then
                rem(self.notes,i)
                missCount=missCount+1
            end
        elseif note.type=='hold'then
            if note.head then--Hold not pressed, miss whole when head missed
                if note.active and self.time>note.time+note.lostTime then
                    note.active=false
                    note.head=false
                    missCount=missCount+2
                end
            else--Pressed, miss tail when tail missed
                note.time=max(note.time,self.time)
                if note.active then
                    if note.tail then
                        if self.time>note.etime+note.lostTime then
                            rem(self.notes,i)
                            missCount=missCount+1
                        end
                    else
                        if self.time>note.etime then
                            rem(self.notes,i)
                            marvCount=marvCount+1
                        end
                    end
                elseif self.time>note.etime then
                    rem(self.notes,i)
                end
            end
        end
    end
    return missCount,marvCount
end

local function _drawChordBox(c,a,trackW,H,thick)
    c[4]=a
    gc_setColor(c)
    gc_rectangle('fill',-trackW-5,-H-thick-6,2*trackW+10,6)
    gc_rectangle('fill',-trackW-5,-H-thick,5,thick)
    gc_rectangle('fill',trackW,-H-thick,5,thick)
end
function Track:draw(map)
    local s=self.state
    gc_push('transform')

    --Set coordinate for single track
    gc_translate(s.x*SETTING.scaleX,s.y)
    gc_rotate(s.ang/57.29577951308232)
    local trackW=50*s.kx*SETTING.trackW
    local ky=s.ky

    local noteDX,noteDY=SETTING.scaleX,s.ky*s.dropSpeed/50

    do--Draw track frame
        local r,g,b,a=s.r,s.g,s.b,s.alpha/100
        --Draw track name
        if s.nameTime>0 then
            setFont(40)
            gc_setColor(r,g,b,a*.626*min(2*s.nameTime,1))
            mStr(self.showName,0,-60)
        end

        --Draw track line
        gc_setColor(r,g,b,a*max(1-(self.pressed and 0 or self.time-self.lastReleaseTime)/.26,.26))
        gc_rectangle('fill',-trackW,0,2*trackW,4*ky)

        --Draw sides
        local unitY=640*ky
        for i=0,.99,.01 do
            gc_setColor(r,g,b,a*(1-i))
            gc_rectangle('fill',-trackW,4*ky-unitY*i,-4,-unitY*.01)
            gc_rectangle('fill',trackW,4*ky-unitY*i,4,-unitY*.01)
            if self.pressed then
                gc_setColor(r,g,b,a*(1-i)/6)
                gc_rectangle('fill',-trackW,-unitY*i,2*trackW,-unitY*.01)
            end
        end
    end

    --Prepare to draw notes
    local dropSpeed=s.dropSpeed*(map.freeSpeed and 1.1^(SETTING.dropSpeed or 0))*ky
    local thick=SETTING.noteThick*ky

    local chordAlpha=SETTING.chordAlpha
    if chordAlpha==0 then
        chordAlpha=false
    end

    --Draw notes
    for i=1,#self.notes do
        local note=self.notes[i]
        local timeRemain=note.time-self.time
        local headH=timeRemain*dropSpeed

        local r,g,b=note:getColor(1-timeRemain/2.6)
        local a=note:getAlpha(1-timeRemain/2.6)
        if note.type=='tap'and timeRemain<0 then
            a=a*(1+timeRemain/hitLVOffsets[1])
        end

        local dx,dy=note:getOffset(1-timeRemain/2.6)
        dx,dy=dx*noteDX,dy*noteDY

        gc_translate(dx,dy)
        if note.type=='tap'then
            if chordAlpha and note.chordCount>1 then
                _drawChordBox(self.chordColor[note.chordCount-1],chordAlpha*a,trackW,headH,thick)
            end
            gc_setColor(r,g,b,a)
            gc_rectangle('fill',-trackW,-headH-thick,2*trackW,thick)
        elseif note.type=='hold'then
            local tailH=(note.etime-self.time)*dropSpeed
            local a2=note.active and a or a*.5
            --Body
            gc_setColor(r,g,b,a2*SETTING.holdAlpha)
            gc_rectangle('fill',-trackW*SETTING.holdWidth,-tailH,2*trackW*SETTING.holdWidth,tailH-headH+(note.head and -thick or 0))

            --Head & Tail
            if note.head then
                if chordAlpha and note.chordCount_head>1 then
                    _drawChordBox(self.chordColor[note.chordCount_head-1],chordAlpha*a,trackW,headH,thick)
                end
                gc_setColor(r,g,b,a)
                gc_rectangle('fill',-trackW,-headH-thick,2*trackW,thick)
            end
            if note.tail then
                if chordAlpha and note.chordCount_tail>1 then
                    _drawChordBox(self.chordColor[note.chordCount_tail-1],chordAlpha*a2,trackW,tailH,thick/2)
                end
                gc_setColor(r,g,b,a2)
                gc_rectangle('fill',-trackW,-tailH-thick/2,2*trackW,thick/2)
            end
        end
        gc_translate(-dx,-dy)
    end

    gc_pop()
end

return Track