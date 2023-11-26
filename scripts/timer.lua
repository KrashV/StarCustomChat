TimerKeeper = {}
TimerKeeper.__index = TimerKeeper

function TimerKeeper.new()
  local self = setmetatable({}, TimerKeeper)
  self.timers = {}
  return self
end

function TimerKeeper:add(duration, fun)
  self.timers[#self.timers+1] = {
      duration = duration * 60,
      fun = fun
    }
end

function TimerKeeper:empty()
  return #self.timers == 0
end

-- Remove finished timers, calling their callbacks.
function TimerKeeper:update()
  local timers = self.timers
  -- Ensure timers made while processing callbacks are kept
  self.timers = {}
  for _,timer in pairs(timers) do
    timer.duration = timer.duration - 1
    if timer.duration <= 0 then
      timer.fun()
    else
      self.timers[#self.timers+1] = timer
    end
  end
end

timers = TimerKeeper.new()
