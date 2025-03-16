-- base.lua

PluginClass = {
  name = ""
}

function PluginClass:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function PluginClass:init(chat)
  self.customChat = chat
  self:_loadConfig()
end

function PluginClass:_loadConfig()
  local parms = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", self.name, self.name)).parameters
  if parms then
    for name, value in pairs(parms) do 
      self[name] = value
    end
  end
end

function PluginClass:update(dt)

end

function PluginClass:openSettings(settingsConfig)
  return settingsConfig
end

function PluginClass:registerMessageHandlers()

end

function PluginClass:onChatScroll(screenPosition)
  return false
end

function PluginClass:onCanvasClick(screenPosition, button, isButtonDown)
  return false
end

function PluginClass:addCustomCommandPreview(availableCommands, substr)

end

function PluginClass:onSendMessage(data)

end

function PluginClass:onReceiveMessage(message)

end

function PluginClass:onModeChange(mode)

end

function PluginClass:onModeToggle(mode, isChecked)

end

function PluginClass:onTextboxCallback()

end

function PluginClass:afterTextboxPressed()

end

function PluginClass:preventTextboxCallback(message)
  return false
end

function PluginClass:onTextboxEscape()
  -- Do nothing
  return false
end

function PluginClass:onTextboxEnter(message)
  -- Do nothing
  return false
end

function PluginClass:formatIncomingMessage(message)
  return message
end

function PluginClass:formatOutcomingMessage(message)
  return message
end

function PluginClass:onSettingsUpdate(data)

end

function PluginClass:onLocaleChange()

end

function PluginClass:onCursorOverride(screenPosition)
  
end

function PluginClass:onCreateTooltip(screenPosition)
  
end

function PluginClass:onProcessCommand(text)
  return false
end

function PluginClass:onBackgroundChange(chatConfig)
  return chatConfig
end

function PluginClass:onCustomButtonClick(buttonName, data)

end

function PluginClass:onSubMenuReopen(type)

end

function PluginClass:uninit()

end

--[[
  Context menu
]]
function PluginClass:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)
  return false
end

function PluginClass:contextMenuReset()

end

function PluginClass:contextMenuButtonClick(buttonName, selectedMessage)

end