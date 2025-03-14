require "/scripts/scctimer.lua"
function init()
  self.defaultColor = "161616bc"
  self.toSwap = true 

  local function setEffect()
    local color = status.statusProperty("afkcolor") or self.defaultColor
    if self.toSwap then
      effect.setParentDirectives("?scanlines=" .. color .. ";0.4;00000000;0.4")
    else
      effect.setParentDirectives("?scanlines=00000000;0.4;" .. color .. ";0.4")
    end

    self.toSwap = not self.toSwap
    timers:add(1, setEffect)
  end
  
  setEffect()
end

function update(dt)
  timers:update(dt)
end

function uninit()
  effect.setParentDirectives("")
end