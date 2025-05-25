require"/interface/scripted/starcustomchatsettings/colorpicker/widget.lua"
require"/scripts/vec2.lua"
require"/scripts/messageutil.lua"

function init()
  self.picker = colorpicker.new"colorCanvas"
  self.currentColor = ""
  self.cursorCanvas = widget.bindCanvas("coursorCanvas")
  createCheckClosure()
end

function setColor(btnName, data)
  self.picker:updateColor(data.position)
end

function resetColor(_, data)
  world.sendEntityMessage(player.id(), "bigger_chat_set_color", "reset")
end

function update()
  promises:update()
  self.cursorCanvas:clear()
  self.picker:update()
  local cursorPos = vec2.sub(self.picker.mouse, 2)
  if self.currentColor ~= self.picker:hex() then
    self.currentColor = self.picker:hex()
    widget.setFontColor("prevText", "#" .. self.currentColor)
    world.sendEntityMessage(player.id(), "bigger_chat_set_color", self.currentColor)
  end
  self.cursorCanvas:drawImage("/interface/easel/spectrumcursor.png", cursorPos, 1)
end

function createCheckClosure()
  local function checkPicker(toClose)
    if toClose then
      pane.dismiss()
    end
    promises:add(world.sendEntityMessage(player.id(), "bigger_chat_check_picker"), checkPicker)
  end

  promises:add(world.sendEntityMessage(player.id(), "bigger_chat_check_picker"), checkPicker)
end