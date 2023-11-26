require "/scripts/messageutil.lua"
require "/scripts/util.lua"

function init()
  if not player.getProperty("irdenCustomChatIsOpen") then
    local interfacePath = "/interface/scripted/irdencustomchat/irdencustomchatgui.json"
    player.interact("ScriptPane", root.assetJson(interfacePath))
  end

  self.messageQueue = nil

  message.setHandler( "icc_getMessageQueue", localHandler(function()
    local queue = copy(self.messageQueue)
    self.messageQueue = nil
    return queue
  end))

  message.setHandler( "icc_sendToUser", simpleHandler(function(data)
    self.messageQueue = self.messageQueue or {}
    table.insert(self.messageQueue, data)
  end))

  message.setHandler( "newChatMessage", localHandler(function(message)
    self.messageQueue = self.messageQueue or {}
    table.insert(self.messageQueue, message)
  end))
end

function update()

end

function uninit()
end