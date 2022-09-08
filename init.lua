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

local function prettyTimeDiff(diffSecs)
    local hours = math.floor(diffSecs / 60 / 60)
    local minutes = math.floor((diffSecs - (hours * 60 * 60)) / 60)
    return hours, minutes
end

local function prettyTime(epochSecs)
    return os.date("%m/%d/%y %H:%M", epochSecs)
end


-- SimpleTimeTracker:init()
-- Method
-- Initialize the spoon
function obj:init()
    self.logger = hs.logger.new(obj.name, "debug")
    self.timer = nil
    self.openLogFile = nil
    self.state = {
        idledAt = 0,
        activeAt = os.time()
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
    self:recordActive()
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
    self.openLogFile:close()
end

-- SimpleTimeTracker:showTime()
-- Method
-- Alter the amount of time tracked today rounded to hours and minutes
function obj:showTime()
    local hours, minutes = prettyTimeDiff(self:totalTime())
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
    local logFile = assert(io.open(self.options.logFilePath, "r"))
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
        if maybeStart == nil or maybeEnd == nil then
            self:debug("skipping because start or end is nil")
        else
            if maybeStart < dayStart and maybeEnd > dayStart then
                self:debug("setting maybe start to day start")
                maybeStart = dayStart
            end
            self:debug(prettyTime(maybeStart) .. " to " .. prettyTime(maybeEnd))

            if maybeEnd > dayStart then
                local h, m = prettyTimeDiff(maybeEnd - maybeStart)
                self:debug("adding " .. h .. ":" .. m)
                totalTime = totalTime + (maybeEnd - maybeStart)
            else
                self:debug("ignoring line")
            end
        end
    end
    logFile:close()
    -- Add a potential segment that hasn't been recorded to the log file yet
    if self.state.activeAt and not self.state.idledAt then
        local lastTime = os.difftime(os.time(), self.state.activeAt)
        self:debug("adding unrecorded time of " .. lastTime)
        totalTime = totalTime + lastTime
    end
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

function obj:writeToLog(s)
    if not self.openLogFile then
        self.openLogFile = assert(io.open(self.options.logFilePath, "a+"))
    end
    self.openLogFile:write(s .. "\n")
    self.openLogFile:flush()
end

function obj:recordIdle()
    self:debug('idling')
    local idledAt = math.max(self.state.activeAt, os.time() - hs.host.idleTime())
    self.state.idledAt = idledAt
    self:writeToLog(self.state.activeAt .. " - " .. self.state.idledAt)
    self.state.activeAt = nil
end

function obj:recordActive()
    self:debug('activating')
    self.state.activeAt = os.time()
    self.state.idledAt = nil
end

function obj:tick()
    if self.state.activeAt and hs.host.idleTime() > self.options.hasIdledWaitSeconds then
        self:recordIdle()
    elseif self.state.idledAt and os.difftime(os.time(), self.state.idledAt) > hs.host.idleTime() then
        self:recordActive()
    end
end

return obj
