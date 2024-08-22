function getTextPositionByCarriage(carriage)
  if carriage == 0 then
    return {0, 0}
  end
  local textIndex = 1
  
  for l = 1, self.lineOffset do
    for j = 1, lineLength(l) do
      textIndex = textIndex + 1
    end
  end

  local i = 1
  for l = self.lineOffset + 1, #self.lines do
    for j = 1, lineLength(l) do
      if textIndex == carriage then 
        return {j, i - 1} 
      else
        textIndex = textIndex + 1
      end
    end
    i = i + 1
  end
  return {0, 0}
end

function getCarriageByTextPosition(position)
  if position[1] == 0 and position[2] == 0 then return 0 end
  local textIndex = 1
  
  for l = 1, self.lineOffset do 
    for j = 1, lineLength(l) do
      textIndex = textIndex + 1
    end
  end

  local i = 1
  for l = self.lineOffset + 1, #self.lines do
    for j = 1, lineLength(l) do
      if position[1] == j and position[2] == i - 1 then 
        return textIndex
      else
        textIndex = textIndex + 1
      end
    end
    i = i + 1
  end
end

function correctBreakV2(position, max, text)
  local startPosition = position
  local tries = 1
  repeat 
    if tries >= max - 1 then
      return startPosition
    end
    position = position - 1
    if position == 1 then
      break
    end
    tries = tries + 1
  until text[position].char:match("[%p%s]")
  return position
end

function splitTextIntoLinesv2(start, finish, text, lines)
  local length = finish - start
  local max = self.maxCharactersInRow - 1
  if length > max then
    local lineBreak = correctBreakV2(start + max, max, text)
    table.insert(lines, lineBreak)
    lines = splitTextIntoLinesv2(lineBreak, finish, text, lines)
  else
    table.insert(lines, finish)    
  end
  return lines
end

function lineLength(index)
  if index == 1 then
    return self.lines[1]
  else
    return self.lines[index] - self.lines[index - 1]
  end
end