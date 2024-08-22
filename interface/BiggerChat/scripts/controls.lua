function startSelection()
  if self.shiftHeld then
    self.selectionStart = self.selectionStart or self.carriagePosition
  else
    self.selectionStart = nil
    self.selectionEnd = nil
  end
end

function removeSelection()
  if self.selectionEnd and self.selectionStart then
    self.carriagePosition = math.min(self.selectionEnd, self.selectionStart)
    for i = 1, math.abs(self.selectionEnd - self.selectionStart) do 
      table.remove(self.text, self.carriagePosition + 1)
    end
    self.selectionEnd = nil
    self.selectionStart = nil
    return true
  end
end

function handleInput()
  local events = input.events()
  local rows = (#self.text * self.letterSpace[1]) // self.textCanvas:size()[1]
  for _, event in ipairs(events) do
    local ctrlHeld = event.data.mods and event.data.mods["LCtrl"]

    --[[
    if event.data.mouseWheel and self.shiftHeld then
      if event.data.mouseWheel < 0 then
        moveCarriage("down")
      else
        moveCarriage("up")
      end
    end
    ]]

    if event.data.key then
      local key = event.data.key
      if key == "LShift" or key == "RShift" then
        self.shiftHeld = event.type == "KeyDown"
      end

      if event.type == "KeyDown" then
        if key == "C" and ctrlHeld then
          if self.selectionStart and self.selectionEnd then
            local str = table.toString(self.text, self.selectionStart + 1, self.selectionEnd)
            if str ~= "" then
              clipboard.setText(str)
            end
          end
        elseif key == "A" and ctrlHeld then
          self.selectionStart = 0
          self.selectionEnd = #self.text
        elseif key == "X" and ctrlHeld then
          if self.selectionStart and self.selectionEnd then
            local str = table.toString(self.text, self.selectionStart + 1, self.selectionEnd)
            if str ~= "" then
              clipboard.setText(str)
            end          
          end
          removeSelection()
          self.toRedrawText = true
        elseif key == "Backspace" then
          if removeSelection() then
            -- Skip
          elseif ctrlHeld then
            local curr = self.carriagePosition
            local moved = false
            while (curr > 0) do 
              if curr - 1 == 0 then table.remove(self.text, self.carriagePosition) self.carriagePosition = 0 break end
              local char = self.text[curr].char
              if string.find(char, "[%p%s]") and moved then
                break
              end
              table.remove(self.text, self.carriagePosition)
              moveCarriage("left")
              curr = self.carriagePosition
              moved = true
            end
          else
            if self.carriagePosition <= #self.text and self.carriagePosition ~= 0 then 
              table.remove(self.text, self.carriagePosition)
              moveCarriage("left")
            end
          end
          self.toRedrawText = true

        elseif key == "Left" then
          startSelection()
          if ctrlHeld then
            local curr = self.carriagePosition
            local moved = false
            while (curr > 0) do 
              if curr - 1 == 0 then self.carriagePosition = 0 break end
              local char = self.text[curr].char
              if string.find(char, "[%p%s]") and moved then
                break
              end
              moveCarriage("left")
              curr = self.carriagePosition
              moved = true
            end
          else
            moveCarriage("left")
          end
          if self.shiftHeld then
            self.selectionEnd = self.carriagePosition
          end
        elseif key == "Right" then
          startSelection()
          if ctrlHeld then
            local curr = self.carriagePosition
            while (curr < #self.text) do 
              moveCarriage("right")
              curr = self.carriagePosition
              if curr + 1 == #self.text then self.carriagePosition = #self.text break end
              local char = self.text[curr].char
              if string.find(char, "[%p%s$]") then
                break
              end
            end
          else
            moveCarriage("right")
          end
          if self.shiftHeld then
            self.selectionEnd = self.carriagePosition
          end
        elseif key == "Home" then
          startSelection()
          if ctrlHeld then
            self.carriagePosition = 0
            self.lineOffset = 0
            self.toRedrawText = true
          else
            local currPos = getTextPositionByCarriage(self.carriagePosition)
            if currPos[2] == 0 then
              self.carriagePosition = 0
            else
              currPos[1] = 1
              self.carriagePosition = getCarriageByTextPosition(currPos)
            end
          end
          if self.shiftHeld then
            self.selectionEnd = self.carriagePosition
          end
        elseif key == "End" then
          startSelection()
          if ctrlHeld then
            self.carriagePosition = #self.text
            self.lineOffset = math.max(#self.lines - self.maxRows - 1, 0)
            self.toRedrawText = true
          else
            if #self.text == 0 then return end
            local currPos = getTextPositionByCarriage(self.carriagePosition)
            
            currPos[1] = math.max(lineLength(currPos[2] + 1 + self.lineOffset), 1)
            self.carriagePosition = getCarriageByTextPosition(currPos)
          end
          if self.shiftHeld then
            self.selectionEnd = self.carriagePosition
          end
        elseif key == "Del" then
          if removeSelection() then
            -- Skip
          elseif ctrlHeld then
            local curr = self.carriagePosition + 1
            while (curr <= #self.text) do
              local char = self.text[curr].char
              table.remove(self.text, curr)

              if string.find(char, "[%p%s$]") then
                break
              end
            end      
          else
            if self.carriagePosition < #self.text + 1 then
              table.remove(self.text, self.carriagePosition + 1)
            end
          end
          self.toRedrawText = true
        elseif key == "Up" then
          startSelection()
          moveCarriage("up")
          if self.shiftHeld then
            self.selectionEnd = self.carriagePosition
          end
        elseif key == "Down" then
          startSelection()
          moveCarriage("down")
          if self.shiftHeld then
            self.selectionEnd = self.carriagePosition
          end
        end
      end
    end
  end
end

function moveCarriage(direction)
  self.carriageTime = self.carriageTimer
  self.toDrawCarriage = true
  
  if direction == "left" then
    if self.carriagePosition > 0 then
      self.carriagePosition = self.carriagePosition - 1
      if self.lineOffset > 0 then
        local currPos = getTextPositionByCarriage(self.carriagePosition)
        if currPos[1] == 0 and currPos[2] == 0 then
          self.lineOffset = self.lineOffset - 1
          self.toRedrawText = true
        end
      end
      return true
    else
      return false
    end

  elseif direction == "right" then
    if self.carriagePosition < #self.text then
      self.carriagePosition = self.carriagePosition + 1
      return true
    else
      return false
    end
  elseif direction == "up" then
    local currPos = getTextPositionByCarriage(self.carriagePosition)
    if currPos[2] > 0 then
      currPos[2] = math.min(currPos[2] - 1, self.maxRows)
      currPos[1] = math.min(currPos[1], lineLength(currPos[2] + 1))
      self.carriagePosition = getCarriageByTextPosition(currPos)
      return true
    elseif #self.lines - 1 > self.maxRows and self.lineOffset > 0 then
      self.lineOffset = math.max(self.lineOffset - 1, 0)
      self.toRedrawText = true
      moveCarriage("up")
    elseif currPos[2] == 0  then
      self.carriagePosition = 0  
    end

  elseif direction == "down" then
    local currPos = getTextPositionByCarriage(self.carriagePosition)
    if currPos[2] < math.min(self.maxRows, #self.lines - 1) then
      currPos[2] = currPos[2] + 1
      currPos[1] = math.min(math.max(currPos[1], 1), lineLength(currPos[2] + 1 + self.lineOffset))
      self.carriagePosition = getCarriageByTextPosition(currPos)
      return true
    elseif #self.lines > self.maxRows + 1 and currPos[2] == self.maxRows and currPos[2] ~= #self.lines - 1 - self.lineOffset then
      self.lineOffset = self.lineOffset + 1
      self.toRedrawText = true
      moveCarriage("down")
    elseif currPos[2] == #self.lines - 1 - self.lineOffset then
      self.carriagePosition = #self.text
    end
  end
  return false
end