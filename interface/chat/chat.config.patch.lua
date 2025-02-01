function require(path)
  loadstring(assets.bytes(path), path)()
end

require "/interface/scripted/starcustomchat/chatbuilder.lua"

function patch(config)
  local newChat = buildChatInterface()
  newChat.config = config.config
  newChat.gui.background = newChat.gui.backgroundImage
  newChat.gui.backgroundImage = nil
  return newChat
end