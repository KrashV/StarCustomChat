function init()
  self.defaultColor = "161616bc"
  self.color = status.statusProperty("afkcolor") or self.defaultColor

  local color, vis = splitColor(self.color)
  effect.setParentDirectives("?fade=" .. color .. "=" .. vis)
end

function splitColor(color)
  local rrgGBBAA = tonumber(color, 16)
  local rrggbb = math.floor(rrgGBBAA / 0x100)
  local aa = rrgGBBAA % 0x100
  local vis = aa / 255
  return string.format("%06X", rrggbb), vis
end

function update(dt)
  local newColor = status.statusProperty("afkcolor")
  if newColor ~= self.color then
    local color, vis = splitColor(newColor)
    effect.setParentDirectives("?fade=" .. color .. "=" .. vis)
    self.color = newColor
  end
end

function uninit()
  effect.setParentDirectives("")
end