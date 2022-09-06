--- === SimpleTimeTracker ===
---
--- Simple tracking of active time on the computer
---

local obj={}
obj.__index = obj

-- Metadata
obj.name = "SimpleTimeTracker"
obj.version = "1.0"
obj.author = "Jacob Bennett <jacob@fatobesegoo.se>"
obj.homepage = "https://github.com/sc8ing/SimpleTimeTracker"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- SimpleTimeTracker:init()
-- Method
-- Initialize the spoon
function obj:init()
    self.logger = hs.logger.new(obj.name, "debug")
    self.timer = nil
    self.state = {
        idledAt = 0
    }
end

-- SimpleTimeTracker:start()
-- Method
-- Start tracking time
--
-- Parameters:
-- * options - Table with configurable parameters
--     * logFilePath - Path to the time tracking log file
--     * debugOn - Whether debug information should be logged to the hammerspoon console
--     * hasIdledWaitSeconds - How long to wait before marking the user as idle
function obj:start(options)
    local defaultOps = {
        hasIdledWaitSeconds = 60 * 5,
        debugOn = false,
        logFilePath = nil
    }
    self.options = options
    setmetatable(self.options, { __index = defaultOps })
    self.timer = hs.timer.new(2, function ()
        self:tick()
    end)
    self.timer:start()
end

-- SimpleTimeTracker:stop()
-- Method
-- Stop tracking time
function obj:stop()
    -- Do this to finish the last log line, otherwise even though
    -- the timer's stopped it'll count this as active time
    if not self.state.idledAt then
        self:recordIdle()
    end
    self.timer:stop()
end

-- SimpleTimeTracker:showTime()
-- Method
-- Alter the amount of time tracked today rounded to hours and minutes
function obj:showTime()
    local totalSeconds = self:totalTime()
    local hours = math.floor(totalSeconds / 60 / 60)
    local minutes = math.floor((totalSeconds - (hours * 60 * 60)) / 60)
    hs.alert(hours .. " Hours " .. minutes .. " Minutes")
end

-- SimpleTimeTracker:totalTime()
-- Method
-- Alter the amount of time for today
--
-- Returns:
-- * The total number of seconds of time tracked for today
function obj:totalTime()
    local now = os.date("*t", os.time())
    local dayStart = os.time { year = now.year, month = now.month, day = now.day, hour = 0 }
    local logFile = io.open(self.options.logFilePath, "r")
    local totalTime = 0
    for line in logFile:lines() do
        self:debug("checking line " .. line)
        local maybeStart = nil
        local maybeEnd = nil
        for time in string.gmatch(line, "%d+") do
            if maybeStart == nil then
                maybeStart = tonumber(time)
            else
                maybeEnd = tonumber(time)
            end
        end
        if maybeStart ~= nil then
            if maybeStart < dayStart then
                self:debug("setting maybe start to day start")
                maybeStart = dayStart
            end
            self:debug(maybeStart .. " to " .. (maybeEnd or "null"))
            if maybeEnd ~= nil and maybeEnd > dayStart then
                self:debug("adding " .. (maybeEnd - maybeStart))
                totalTime = totalTime + (maybeEnd - maybeStart)
            elseif maybeEnd == nil then
                self:debug("adding to now " .. (os.time() - maybeStart))
                totalTime = totalTime + (os.time() - maybeStart)
            else
                self:debug("ignoring line")
            end
        end
    end
    logFile:close()
    return totalTime
end

-- SimpleTimeTracker:bindHotkeys()
-- Method
-- Bind hot keys
-- 
-- Parameters:
-- * mapping - A table containing hot key modifier/key details for:
--     * showTime - Alter the total amount of time tracked for today in hours and minutes
function obj:bindHotkeys(mapping)
  local actions = {
    showTime = hs.fnutils.partial(self.showTime, self)
  }
  hs.spoons.bindHotkeysToSpec(actions, mapping)
  return self
end

function obj:debug(msg)
    if self.options.debugOn then
        self.logger.d(msg)
    end
end

function obj:recordIdle()
    self.state.idledAt = os.time()
    local theLog = io.open(self.options.logFilePath, "a+")
    theLog:write((os.time() - hs.host.idleTime()) .. "\n")
    theLog:flush()
    theLog:close()
end

function obj:recordUnidle()
    self.state.idledAt = nil
    local theLog = io.open(self.options.logFilePath, "a+")
    theLog:write(os.time() .. " - ")
    theLog:flush()
    theLog:close()
end

function obj:tick()
    -- Currently marked as unidle (no idledAt time), but have been idling for long enough
    -- that we should start counting this as idle time
    if not self.state.idledAt and hs.host.idleTime() > self.options.hasIdledWaitSeconds then
        self:debug("idled " .. hs.host.idleTime())
        obj.recordIdle(self)
    -- If we've been idling for less time than has passed since we were marked as idle, then
    -- that means we started moving again at some point since the last tick, so mark unidled
    elseif os.difftime(os.time(), self.state.idledAt or os.time()) > hs.host.idleTime() then
        self:debug("unidled")
        obj.recordUnidle(self)
    -- Otherwise no change of state has happened and we are still idle/unidle just like last tick
    else
        self:debug("still un/idle from " .. (self.state.idledAt or 'not idle'))
    end
end

return obj
