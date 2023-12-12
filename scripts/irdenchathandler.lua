require "/scripts/messageutil.lua"
require "/scripts/util.lua"

function init()
  self.messageQueue = nil

  self.lastCheckedQueueTimer = 1
  self.lastCheckQueueTime = self.lastCheckedQueueTimer

  message.setHandler( "icc_getMessageQueue", localHandler(function()
    local queue = copy(self.messageQueue)
    self.messageQueue = nil
    self.lastCheckQueueTime = self.lastCheckedQueueTimer
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
  
  message.setHandler( "icc_resetSettings", localHandler(function()
    self.messageQueue = self.messageQueue or {}
    table.insert(self.messageQueue, "RESET_CHAT")
  end))
  
  message.setHandler( "icc_clearHistory", localHandler(function()
    self.messageQueue = self.messageQueue or {}
    table.insert(self.messageQueue, "CLEAR_HISTORY")
  end))
end

-- We will wait self.lastCheckedQueueTimer seconds to check for the message to be read.
-- If we don't receive the request for the message, consider the chat dead.
function update(dt)
  self.lastCheckQueueTime = self.lastCheckQueueTime - dt 
  if self.lastCheckQueueTime < 0 then
    local interfacePath = "/interface/scripted/irdencustomchat/icchatgui.json"
    player.interact("ScriptPane", root.assetJson(interfacePath))
    self.lastCheckQueueTime = self.lastCheckedQueueTimer
  end
end

function uninit()
  
end