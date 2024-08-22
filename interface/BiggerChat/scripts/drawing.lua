function setColours()
  self.selectColour = "#b7ffdacc"
  self.carriageColour = "#bbbbbb"
  self.fontColor = "white"
end

function drawText()
  --self.lineOffset = math.max(0, #self.lines - self.maxRows - 1)

  local canvasSize = self.textCanvas:size()
  
  local i = 1
  for l = self.lineOffset + 1, #self.lines do
    local offset = l > 1 and self.lines[l - 1] or 0
    for x = 1, lineLength(l) do
      self.textCanvas:drawText(self.text[offset + x].char, {
        position = {(x - 1) * self.letterSpace[1], canvasSize[2] - (i - 1) * self.letterSpace[2]},
        horizontalAnchor = "left", -- left, mid, right
        verticalAnchor = "top" -- top, mid, bottom
      }, self.fontSize, self.text[offset + x].color or self.fontColor)
    end
    
    if i > self.maxRows then
      break
    end
    i = i + 1
  end
end

function drawCarriage(dt)
  self.carriageTime = self.carriageTime - dt 
  if self.carriageTime <= 0 then
    self.carriageTime = self.carriageTimer
    self.toDrawCarriage = not self.toDrawCarriage
  end

  if self.toDrawCarriage then
    local canvasSize = self.selectionCanvas:size()
    local pos = getTextPositionByCarriage(self.carriagePosition)
    if pos then
      -- Since we're going from up to down, invert Y
      pos[2] = math.max(canvasSize[2] - pos[2] * self.letterSpace[2], 0)
      pos[1] = pos[1] * self.letterSpace[1]
      self.selectionCanvas:drawLine(pos, vec2.sub(pos, {0, self.carriageHeight - self.spaceBetweenLines}), self.carriageColour, self.carriageWidth)
    else
      sb.setLogMap("TextIndex", "Unknown position")
    end
  end
end

function drawSelection()
  if self.isSelecting or self.selectionEnd then
    local cell = translateToCell(self.selectionCanvas:mousePosition())
    local newCarr = self.selectionEnd or getCarriageByTextPosition(cell)
    self.carriagePosition = newCarr or self.carriagePosition
    if newCarr and self.selectionStart and newCarr ~= self.selectionStart then
      
      local canvasSize = self.textCanvas:size()

      self.carriagePosition = newCarr
      -- Since we're going from up to down, invert Y
      local start = math.min(newCarr, self.selectionStart)
      local finish = math.max(newCarr, self.selectionStart)

      local startCell = getTextPositionByCarriage(start)
      local endCell = getTextPositionByCarriage(finish)

      local rect
      for i = startCell[2], endCell[2] do
        local height = math.max(canvasSize[2] - (i + 1) * self.letterSpace[2], 0)
        -- First line: from start to the end (or the end of the line)
        if i == startCell[2] then
          local len = lineLength(i + 1 + self.lineOffset)
          local endPos = endCell[2] == startCell[2] and endCell[1] or len
          rect = {startCell[1] * self.letterSpace[1], height, self.letterSpace[1] * endPos, height + self.letterSpace[2]}

        -- Last line: from 0 to the end
        elseif i == endCell[2] then
          rect = {0, height, self.letterSpace[1] * endCell[1], height + self.letterSpace[2]}

        -- Middle lines: all the lines
        else
          local len = lineLength(i + 1 + self.lineOffset)
          rect = {0, height, self.letterSpace[1] * len, height + self.letterSpace[2]}
        end
        self.selectionCanvas:drawRect(rect, self.selectColour)
      end
    end
  end
end