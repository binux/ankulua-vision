local localPath = scriptPath()
dofile(localPath.."dkjson.lua")

stateMachine = {
  baseRange = 10,
  highlightTime = 0.3,
  highlightFind = true,
  highlightClick = true,
  wholeWindow = Region(0, 0, 1920, 1080),
  debugBox = Region(200, 1080 - 30, 500, 30),
  stateBox = Region(0, 1080 - 30, 200, 30),
  lastScreen = nil,
  waitStatesDebounce = 0.5,

  ANY_SCREEN = '[any]',
  PREV_SCREEN = '[prev-screen]'
}

function stateMachine:init(meta)
  -- TODO: from config
  setHighlightTextStyle(0x80ffffff, 0xff02b6b6, 12)
  Settings:setCompareDimension(true, 1920)
  Settings:setScriptDimension(true, 1920)

  self.screens = meta.screens
  self.screensMap = {}
  self.hotspotsMap = {}
  for i, screen in ipairs(self.screens) do
    screen.actions = {}
    self.screensMap[screen.name] = screen
    for j, hotspot in ipairs(screen.hotspots) do
      for k, next in ipairs(hotspot.next) do
        if next == "[any]" then
          hotspot.next[k] = self.ANY_SCREEN
        elseif next == "[next-screen]" then
          if self.screens[i+1] then
            hotspot.next[k] = self.screens[i+1].name
          else
            table.remove(hotspot.next, k)
          end
        elseif next == "[prev-screen]" then
          hotspot.next[k] = self.PREV_SCREEN
        end
      end
    end
    for j, zone in ipairs(screen.hotspots) do
      self.hotspotsMap[zone.file] = zone
      if zone.similarity and zone.similarity > 0 then
        zone.pattern = Pattern(zone.file):similar(zone.similarity or 0.8)
      end
    end
    for j, zone in ipairs(screen.detectZones) do
      zone.pattern = Pattern(zone.file):similar(zone.similarity or 0.8)
    end
  end
end

function stateMachine:toRegion(z)
  local range = (z.range or 10) + self.baseRange
  local region = Region(z.left - range / 2, z.top - range / 2., z.width + range, z.height + range)
  return region
end

function stateMachine:findStart()
  self.waitFindCache = true
  self.findCache = false
end

function stateMachine:findEnd()
  usePreviousSnap(false)
  self.waitFindCache = false
  self.findCache = false
end

function stateMachine:find(region, image, timeout)
  if typeOf(region) == "string" or typeOf(region) == "table" then
    timeout = image
    image = region
    region = nil
  end
  if not region then region = self.wholeWindow end
  if typeOf(image) == "string" and self.hotspotsMap[image] then
    local hotspot = self.hotspotsMap[image];
    region = self:toRegion(hotspot)
    if hotspot.similarity == 0 then
      return region
    end
    image = hotspot.pattern or hotspot.file
  end

  if self.findCache then
    usePreviousSnap(true)
  elseif self.waitFindCache then
    self.waitFindCache = false
    self.findCache = true
    usePreviousSnap(false)
  else
    usePreviousSnap(false)
  end

  local m = region:exists(image, timeout or 0)
  if m == nil then return end
  if self.highlightFind then
    m:highlight(nil, self.highlightTime)
  end
  return m
end

function stateMachine:dragFind(image, down, left)
  local m = self:find(image)
  if m then return m end

  local mid = Location(self.wholeWindow:getW() * 0.5, self.wholeWindow:getH() * 0.5)
  repeat
    self.wholeWindow:save("_lastScreen.png")
    if down and down > 0 then
      swipe(mid, Location(mid:getX(), mid:getY() * 1.5))
    elseif down and down < 0 then
      swipe(mid, Location(mid:getX(), mid:getY() * 0.5))
    elseif down and down == 0 then
      return self:dragFind(image, 1) or self:dragFind(image, -1)
    end
    if left and left > 0 then
      swipe(mid, Location(mid:getX() * 0.5, mid:getY()))
    elseif left and left < 0 then
      swipe(mid, Location(mid:getX() * 1.5, mid:getY()))
    elseif left and left == 0 then
      return self:dragFind(image, nil, -1) or self:dragFind(image, nil, 1)
    end
    local m = self:find(image)
    if m then return m end
  until self:find("_lastScreen.png")
end

function stateMachine:click(image, timeout)
  if typeOf(image) == "string" and self.hotspotsMap[image] then
    image = self.hotspotsMap[image]
  end

  local m
  needHighlight = true
  if not image then
    m = Location(self.wholeWindow:getW() * 0.66, self.wholeWindow:getH() * 0.66)
  elseif typeOf(image) == "string" then
    m = self:find(nil, image, timeout)
    if self.highlightFind then needHighlight = false end
  elseif typeOf(image) == "table" and image.pattern then
    m = self:find(self:toRegion(image), image.pattern, timeout)
    if self.highlightFind then needHighlight = false end
  elseif typeOf(image) == "table" and image.file then
    m = self:toRegion(image)
  else
    m = image
  end

  if m == nil then return false end
  if self.highlightClick and needHighlight then
    m:highlight(nil, self.highlightTime)
  end
  continueClick(m, 1)
  return true
end

function stateMachine:zoomOut()
  repeat
    self.wholeWindow:save("_lastScreen.png")
    zoom(50, 350, 330, 350, 1200, 350, 350, 350, 300)
    wait(1)
  until self:find(nil, "_lastScreen.png")
  wait(1)
  startApp("com.digitalsky.girlsfrontline.cn")
end

function stateMachine:updateState(state)
  self:log(state)
  self.lastScreen = state
  self.stateBox:highlightOff()
  self.stateBox:highlight(state or 'nil')
end

function stateMachine:debug(msg)
  self:log(msg)
  self.debugBox:highlightOff()
  self.debugBox:highlight(msg)
end

function stateMachine:log(text)
  local file = io.open(localPath.."game.log", "a")
  if (file~=nil) then
    io.output(file)
    file:write(os.date("%Y-%m %d %X : ") .. (text or 'nil') .."\r\n")
    io.close(file)
  end
end

function stateMachine:checkState(state)
  local screen = state
  if typeOf(state) == "string" then
    screen = self.screensMap[state]
  end
  if not screen then return end

  local score = 0
  for i, z in ipairs(screen.detectZones) do
    local m = self:find(self:toRegion(z), z.pattern)
    if m then
      score = score + m:getScore()
    else
      score = 0
      break
    end
  end
  if score > 0 then
    return score
  end
end

function stateMachine:getState()
  local t = Timer()
  local bestScore = 0
  local bestScreen = nil
  self:findStart()
  for i, screen in ipairs(self.screens) do
    if screen.match then
      local score = self:checkState(screen) or 0
      if score > bestScore then
        bestScore = score
        bestScreen = screen
      end
    end
  end
  self:findEnd()
  if bestScore > 0 then
    self:log('getState ' .. bestScreen.name .. ' - ' .. t:check())
    self:updateState(bestScreen.name)
    return bestScreen.name
  end
end

function stateMachine:leaveState(state, timeout)
  timeout = timeout or 10
  local t = Timer()
  local screen = self.screensMap[state]
  if not screen then return end

  while t:check() < timeout do
    if self:checkState(screen) then
      wait(1)
    else
      return true
    end
  end
  return false
end

function stateMachine:waitStates(states, timeout)
  if typeOf(states) == "string" then
    states = {states}
  end
  self:debug('waiting ' .. table.concat(states, '|'))
  if #states <= 0 then return end
  timeout = timeout or 30
  local t = Timer()
  while t:check() < timeout do
    local noSearch = true
    local bestScore = 0
    local bestState = nil
    local hasAny = false
    self:findStart()
    for i, state in ipairs(states) do
      if state == self.ANY_SCREEN then
        hasAny = true
      elseif not self.screensMap[state] then
      else
        noSearch = false
        local score = self:checkState(state)
        if score and score > bestScore then
          bestScore = score
          bestState = state
        end
      end
    end
    self:findEnd()
    if bestScore > 0 then
      wait(self.waitStatesDebounce)
      if self:checkState(bestState) then
        self:updateState(bestState)
        self:debug('time ' .. t:check())
        return bestState
      end
    end
    if hasAny then
      local getState = self:getState()
      if getState then
        wait(self.waitStatesDebounce)
        if self:checkState(getState) then
          self:updateState(getState)
          self:debug('time ' .. t:check())
          return getState
        end
      end
    end
    if noSearch then return nil end
    wait(0.3)
  end
end

stateMachine.waitState = stateMachine.waitStates

function stateMachine:getScreenNexts(screen)
  local result = {}
  for i, hotspot in ipairs(screen.hotspots) do
    for j, next in ipairs(hotspot.next) do
      result[next] = 1
    end
  end
  for name, action in pairs(screen.actions) do
    result[name] = 1
  end

  local r = {}
  for s, c in pairs(result) do
    table.insert(r, s)
  end
  return r
end

function stateMachine:plan(state, target, visited)
  if state == target then
    return {}
  end
  local screen = self.screensMap[state]
  if not screen then return end
  if visited == nil then
    visited = { [state] = true }
  end
  
  local bestPlan = nil
  for i, next in ipairs(self:getScreenNexts(screen)) do
    local plan = nil
    if visited[next] then 
    elseif next == target then
      plan = { next }
    else
      visited[next] = true
      plan = self:plan(next, target, visited)
      if plan then table.insert(plan, next) end
      visited[next] = nil
    end
    if plan and (bestPlan == nil or #plan < #bestPlan) then
      bestPlan = plan
    end
  end
  if bestPlan then
    return bestPlan
  else
    return nil
  end
end

function stateMachine:play(state, target)
  self:log(string.format('play %s => %s', state, target))
  local screen = self.screensMap[state]
  if not screen then
    self:log('cannot find state ' .. (state or 'nil'))
    return
  end

  if screen.actions[target] then
    return screen.actions[target](), true
  end

  local hotspot
  for i, h in ipairs(screen.hotspots) do
    for j, next in ipairs(h.next) do
      if next == target then
        hotspot = h
        break
      end
    end
  end
  if not hotspot then
    self:log('cannot find hotspot')
    return
  end

  -- click
  if not self:click(hotspot, 5) then
    self:log('cannot click in play')
    return
  end

  -- exit if target not defined
  if not self.screensMap[target] then
    self:leaveState(state, hotspot.timeout)
    local newState = self:getState()
    self:updateState(newState)
    return newState
  end

  -- leave state
  local hasAny = false
  for i, next in ipairs(hotspot.next) do
    if next == self.ANY_SCREEN or next == self.PREV_SCREEN then
      hasAny = true
      self:leaveState(state, hotspot.timeout)
      break
    end
  end

  -- wait state
  local waitStateSet = {}
  for i, next in ipairs(hotspot.next) do
    if next == self.ANY_SCREEN or next == self.PREV_SCREEN then
      if self.lastScreen and self.lastScreen ~= state then
        waitStateSet[self.lastScreen] = 1
      end
    end
    waitStateSet[next] = 1
  end
  local waitStates = {}
  for s, c in pairs(waitStateSet) do
    table.insert(waitStates, s)
  end
  local newState = self:waitStates(waitStates, hotspot.timeout)
  if not newState and self:checkState(state) then
    newState = state
  end
  if not newState then
    newState = self:getState()
  end
  self:updateState(newState)
  return newState
end

function stateMachine:waitKnownState(timeout)
  timeout = timeout or 30
  local t = Timer()
  while t:check() < timeout do
    local state = self:getState()
    if state then return state end
    wait(1)
  end
end

function stateMachine:goto(...)
  local curr = nil
  local suckInSameState = 0

  for i, state in ipairs(arg) do
    if curr == nil then
      if self:checkState(state) then
        curr = state
      else
        curr = self:waitKnownState()
      end
    end

    while curr ~= state do
      if not curr then
        self:debug("unknown state")
        return
      end
      local plan = self:plan(curr, state)
      if not plan then
        plan = self:plan(curr, self.PREV_SCREEN)
      end
      if not plan then
        plan = self:plan(curr, self.ANY_SCREEN)
      end
      if not plan then
        self:debug("no plan for " .. curr .. " => " .. state)
        return
      end
      self:debug(" => " .. plan[#plan])
      self:log('plan ' .. table.concat(plan, " < "))
      local newState, isAction = self:play(curr, plan[#plan])
      if newState and isAction and not self.screensMap[plan[#plan]] then
        -- accept action result if it's not a screen name
        curr = newState
        break
      end
      if newState == curr then
        suckInSameState = suckInSameState + 1
        if suckInSameState > 5 then
          return
        end
      else
        suckInSameState = 0
      end
      curr = newState
    end
  end
  return curr
end

function stateMachine:action(state, action, ...)
  local curr = self:goto(state)
  if curr ~= state then
    self:debug('cannot goto '..state)
    return
  end
  return self.screensMap[state].actions[action](arg)
end

function stateMachine:register(state, target, action)
  local screen = self.screensMap[state]
  if not screen then
    -- add virtual screen
    screen = {
      match = false,
      name = state,
      actions = {},
      hotspots = {},
      detectZones = {},
    }
    self.screensMap[screen.name] = screen
  end
  self.screensMap[state].actions[target] = action
end


local metaFile = assert(io.open(localPath.."meta.json", "rb"))
local content = metaFile:read("*all")
local meta, pos, err = json.decode(content, 1, nil)
metaFile:close()
if err then
  self:log(content)
  scriptExit("failed read meta.json" .. err)
end
stateMachine:init(meta)
