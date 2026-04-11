require "/scripts/vec2.lua"
require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/utf8.lua"

-- Define TimedPromiseKeeper as a subclass of PromiseKeeper
TimedPromiseKeeper = {}
TimedPromiseKeeper.__index = TimedPromiseKeeper

setmetatable(TimedPromiseKeeper, {__index = PromiseKeeper})

function TimedPromiseKeeper:new()
  local instance = PromiseKeeper:new()
  setmetatable(instance, TimedPromiseKeeper)
  return instance
end

function TimedPromiseKeeper:update(dt)
  local promises = self.promises
  -- Ensure promises made while processing callbacks are kept
  self.promises = {}
  for _,promise in pairs(promises) do
    if promise.promise:finished(dt) then
      if promise.promise:succeeded() then
        if promise.onSuccess then promise.onSuccess(promise.promise:result()) end
      else
        if promise.onError then promise.onError(promise.promise:error()) end
      end
    else
      self.promises[#self.promises+1] = promise
    end
  end
end

-- RPC Promise Mock
RPCPromise = {}

function RPCPromise:new(o)
  local obj = o or {}
  obj.hasSucceeded = false
  obj.processingTime = 0

  setmetatable(obj, self)
  self.__index = self
  return obj
end

function RPCPromise:finished(dt)
end

function RPCPromise:succeeded()
  return self.hasSucceeded
end

function RPCPromise:result()
  return nil
end

-- Move Promise - subclass of RPCPromise
-- We only need the :finished method to rewrite, as it is called every tick

MovePromise = RPCPromise:new()

function MovePromise:finished(dt)
  self.processingTime = self.processingTime + dt
  local t = math.min(self.processingTime / self.duration, 1)
  
  widget.setPosition(self.name, vec2.lerp(t, self.start, self.destination))
  
  if t >= 1 then self.hasSucceeded = true; return true end
end

-- ProcessPromise - subclass of RPCPromise
-- Again, we only need the :finish method to rewrite

ProcessPromise = RPCPromise:new()

function ProcessPromise:finished(dt)
  self.processingTime = self.processingTime + dt
  local t = math.min(self.processingTime / self.duration, 1)

  widget.setProgress(self.name, util.lerp(t, self.startValue, self.endValue))

  if t >= 1 then self.hasSucceeded = true; return true end
end

-- Rotate the promise widget
RotateImagePromise = RPCPromise:new()

function RotateImagePromise:finished(dt)
  self.processingTime = self.processingTime + dt
  local t = math.min(self.processingTime / self.duration, 1)
  local angle = util.lerp(t, self.startValue, self.endValue)

  if self.rotationCenter then
    widget.setPosition(self.name, vec2.add(self.startPosition, vec2.sub(self.rotationCenter, vec2.rotate(self.rotationCenter, angle))))
  end

  widget.setImageRotation(self.name, angle)
  if t >= 1 then self.hasSucceeded = true; return true end
end

-- Scale the promise widget
ScaleImagePromise = RPCPromise:new()

function ScaleImagePromise:finished(dt)
  self.processingTime = self.processingTime + dt
  local t = math.min(self.processingTime / self.duration, 1)
  local size = util.lerp(t, self.startValue, self.endValue)

  if self.scalingCenter then
    widget.setPosition(self.name, vec2.add(self.startPosition, vec2.sub(self.scalingCenter, vec2.mul(self.scalingCenter, size))))
  end

  widget.setImageScale(self.name, size)
  if t >= 1 then self.hasSucceeded = true; return true end
end

-- Scale the promise widget
SetSizePromise = RPCPromise:new()

function SetSizePromise:finished(dt)
  self.processingTime = self.processingTime + dt
  local t = math.min(self.processingTime / self.duration, 1)
  local size = {util.lerp(t, self.startSize[1], self.endSize[1]), util.lerp(t, self.startSize[2], self.endSize[2])}

  widget.setSize(self.name, size)
  if t >= 1 then self.hasSucceeded = true; return true end
end

-- Scale the promise widget
SetPaneSizePromise = RPCPromise:new()

function SetPaneSizePromise:finished(dt)
  self.processingTime = self.processingTime + dt
  local t = math.min(self.processingTime / self.duration, 1)
  local size = {util.lerp(t, self.startSize[1], self.endSize[1]), util.lerp(t, self.startSize[2], self.endSize[2])}

  pane.setSize(size)
  if t >= 1 then self.hasSucceeded = true; return true end
end


-- Set text letter by letter
SetTextPromise = RPCPromise:new()

function SetTextPromise:finished(dt)
  self.processingTime = self.processingTime + dt
  local t = math.min(self.processingTime / self.duration, 1)
  local len = math.floor(util.lerp(t, 0, utf8.len(self.text)))

  widget.setText(self.name, utf8.sub(self.text, 1, len))
  if t >= 1 then self.hasSucceeded = true; return true end
end





-- Animated Widget wrapper
AnimatedWidget = {}
AnimatedWidget.__index = AnimatedWidget


function AnimatedWidget:bind(wid)
  local awid = {}
  setmetatable(awid, AnimatedWidget)
  awid.name = wid
  return awid
end

function AnimatedWidget:move(destination, duration)
  return MovePromise:new{ name = self.name, start = widget.getPosition(self.name), destination = destination, duration = duration }
end

function AnimatedWidget:process(oldValue, newValue, duration)
  return ProcessPromise:new{ name = self.name, startValue = oldValue, endValue = newValue, duration = duration}
end

function AnimatedWidget:rotate(oldValue, newValue, duration, rotationCenter)
  return RotateImagePromise:new{ name = self.name, startValue = oldValue, endValue = newValue, duration = duration, rotationCenter = rotationCenter, startPosition = widget.getPosition(self.name)}
end

function AnimatedWidget:scale(oldValue, newValue, duration, scalingCenter)
  return ScaleImagePromise:new{ name = self.name, startValue = oldValue, endValue = newValue, duration = duration, scalingCenter = scalingCenter, startPosition = widget.getPosition(self.name)}
end

function AnimatedWidget:setSize(newSize, duration)
  return SetSizePromise:new{ name = self.name, startSize = widget.getSize(self.name), endSize = newSize, duration = duration}
end

function AnimatedWidget:setPaneSize(newSize, duration)
  return SetPaneSizePromise:new{ startSize = pane.getSize(), endSize = newSize, duration = duration}
end

function AnimatedWidget:setText(text, duration)
  return SetTextPromise:new{ name = self.name, text = text, duration = duration }
end

animatedWidgets = TimedPromiseKeeper.new()