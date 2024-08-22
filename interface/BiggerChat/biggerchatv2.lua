require "/interface/BiggerChat/scripts/utf8.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/messageutil.lua"
require "/interface/BiggerChat/scripts/controls.lua"
require "/interface/BiggerChat/scripts/drawing.lua"
require "/interface/BiggerChat/scripts/text.lua"


function init()
  self.isHoldingMouse = false
	self.maxCharacters = 50
  self.text = {}
  self.lines = {}
  self.fontSize = 8

  self.shiftHeld = false
  self.textCanvas = widget.bindCanvas("printCanvas")
  self.selectionCanvas = widget.bindCanvas("selectionCanvas")
  self.canvasSize = self.textCanvas:size()
  setVariables(self.fontSize)
  setColours()
  self.lineOffset = 0
  self.carriageOffset = 0

  self.carriagePosition = 0

  self.carriageTimer = 0.6
  self.carriageTime = self.carriageTimer
  self.toDrawCarriage = true
  self.toRedrawText = true

  self.isSelecting = false
  self.selectionStart = nil
  player.setProperty("biggerChatOpen", true)
  --createColorQueue()

  if config.getParameter("initialText") then
    widget.setText("totallyFakeTextbox", config.getParameter("initialText"))
  end

  self.fontColor = config.getParameter("fontColor")
end

function setVariables(fontSize)
  self.spaceBetweenLines = 4
  self.letterSpace = {fontSize, fontSize + self.spaceBetweenLines}
  self.maxCharactersInRow = self.textCanvas:size()[1] // self.letterSpace[1]
  self.maxRows = self.textCanvas:size()[2] // self.letterSpace[2] - 1
  self.carriageHeight = self.letterSpace[2]
  self.carriageWidth = 3
end

function createColorQueue()
  local function getColor(color)
    if color and color ~= self.fontColor then
      if self.selectionStart and self.selectionEnd then
        local start = math.min(self.selectionStart, self.selectionEnd)
        local fin = math.max(self.selectionStart, self.selectionEnd)
        for i = start + 1, fin do
          self.text[i].color = color ~= "reset" and "#" .. color or nil
        end
        self.toRedrawText = true
      end
    end
    promises:add(world.sendEntityMessage(player.id(), "bigger_chat_get_color"), getColor)
  end

  promises:add(world.sendEntityMessage(player.id(), "bigger_chat_get_color"), getColor)
end

function update(dt)
  promises:update()

  if self.toRedrawText then
    self.textCanvas:clear()
    self.lines = splitTextIntoLinesv2(0, #self.text, self.text, {})
    drawText()
    self.toRedrawText = false
  end
  handleInput()

  self.selectionCanvas:clear()
  drawCarriage(dt)
  drawSelection()
end

function fontUp()
  self.fontSize = self.fontSize + 1
  setVariables(self.fontSize)
  widget.focus("totallyFakeTextbox")
  self.toRedrawText = true
end

function fontDown()
  self.fontSize = math.max(self.fontSize - 1, 1)
  setVariables(self.fontSize)
  widget.focus("totallyFakeTextbox")
  self.toRedrawText = true
end

function changeColor()
  player.interact("ScriptPane", root.assetJson("/interface/BiggerChat/colorpick/colorpick.json"))
  widget.focus("totallyFakeTextbox")
end

function translateToCell(vector)
  --To Do: instead of ugly monospace, calculate the carette position in a smart way! :nerd:
  --[[
  widget.setText("totallyFakeLabel", table.toString(self.text))
  chat.addMessage(sb.print(widget.getSize("totallyFakeLabel")))
  widget.setText("totallyFakeLabel", table.toString(self.text))
  ]]
  local canvasSize = self.textCanvas:size()
  local cell =  {math.ceil(vector[1] / self.letterSpace[1]), math.max(math.ceil((canvasSize[2] - vector[2]) / self.letterSpace[2]) - 1, 0)}
  cell[2] = math.min(cell[2], math.min(#self.lines - 1, self.maxRows))
  cell[1] = math.min(cell[1], lineLength(cell[2] + 1))
  return cell
end

function table.toString(t,start,finish)
  start = start and start > 0 and start or 1
  local str = ""
  for l = start or 1, finish or #t do
    str = str .. t[l].char
  end
  return str
end

function canvasClickEvent(position, button, isButtonDown)
  if button == 0 and isButtonDown then
    self.isHoldingMouse = true
    local cell = translateToCell(position)
    local carr = getCarriageByTextPosition(cell)

    if self.shiftHeld then
      self.selectionEnd = carr
      self.selectionStart = self.selectionStart or (carr and self.carriagePosition) or nil
    else
      self.carriagePosition = carr and carr or self.carriagePosition
      self.selectionStart = self.carriagePosition
      self.isSelecting = true
      self.selectionEnd = nil
    end
  elseif button == 0 and not isButtonDown and self.isHoldingMouse then
    self.isSelecting = false
    self.selectionEnd = self.carriagePosition ~= self.selectionStart and self.carriagePosition or nil
    self.selectionStart = self.selectionEnd and self.selectionStart or nil
    self.isHoldingMouse = false
  end
  widget.focus("totallyFakeTextbox")
end

function setTextboxText(start, finish)
  widget.setText("totallyFakeTextbox", table.toString(self.text, start + 1 > 0 and start + 1 or 1, finish))
end

function fakeInput(textbox)
  local text = widget.getText(textbox)
  local len = utf8.len(text)
  self.toRedrawText = len > 0 and true or self.toRedrawText

  if len > 0 then removeSelection() end

  -- If it's a long command that starts with /, take it all and paste into the normal chat and close the thing.
  if len > 0 and #self.text == 0 and string.sub(text, 1, 1) == "/" then 
    chat.setInput(text, true)
    pane.dismiss()
    return
  end

  for i, c in utf8.codes(text) do
    table.insert(self.text, self.carriagePosition + 1, {char = utf8.char(c), color = nil})
    moveCarriage("right")
  end

  self.lines = splitTextIntoLinesv2(0, #self.text, self.text, {})
  if len > 0 and self.carriagePosition == #self.text and #self.lines > self.maxRows then
    self.lineOffset = math.max(#self.lines - self.maxRows - 1, 0)
    self.toRedrawText = true
  end
  widget.setText(textbox, "")
end


function prepareColoredTextToSend(t)
  local currentColor = self.fontColor
  local str = ""
  local colorChanged = false
  for l = 1, #t do
    if (t[l].color or colorChanged) and t[l].color ~= currentColor then
      local color = t[l].color or "reset"
      str = str .. "^" .. color .. ";"
      currentColor = t[l].color
      colorChanged = true
    end
    str = str .. t[l].char
  end
  return str
end

function send()
  --if self.shiftHeld then 
  --  table.insert(self.lines, #self.lines + 1, {})
  --  moveCarriage("right")
  --else
    local text = prepareColoredTextToSend(self.text)
    if #text > 0 then
      world.sendEntityMessage(player.id(), "scc_set_message_bigchat", text)
      self.text = {}
      self.carriagePosition = 0
      self.toRedrawText = true
      uninit()
    end
  --end
end

function uninit()
  player.setProperty("biggerChatOpen", nil)
  local text = prepareColoredTextToSend(self.text)
  world.sendEntityMessage(player.id(), "scc_set_message_bigchat")
  world.sendEntityMessage(player.id(), "bigger_chat_close_picker")
  pane.dismiss()
end