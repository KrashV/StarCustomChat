require "/interface/scripted/starcustomchat/plugin.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"

typing = PluginClass:new(
  { name = "typing" }
)

function typing:init(chat)
  PluginClass.init(self, chat)

  self.sendTypingIndicatorTime = 0
  self.addTypingEntityMessageName = "scc_add_typing_indicator"
  self.removeTypingEntityMessageName = "scc_remove_typing_indicator"
  
  self.indicatorImageSize = root.imageSize(self.overlayImage .. ":1")
  self.typingPlayers = {}
  self.typingFrameTime = 0
  
  self.typingMessageUUID = nil

end

function typing:registerMessageHandlers()
  starcustomchat.utils.setMessageHandler( self.addTypingEntityMessageName, function(_, _, data)
    if not self.typingPlayers[data.connection] then
      data.time = 0
      self.typingPlayers[data.connection] = data
    else
      self.typingPlayers[data.connection].time = 0
    end
  end)

  starcustomchat.utils.setMessageHandler( self.removeTypingEntityMessageName, function(_, _, data)
    if self.typingPlayers[data.connection] then
      self.typingPlayers[data.connection] = nil
    end
  end)
end


function typing:buildTypingText(typingPlayers)
  local typingPlayerEntries = {}
  local localPosition = world.entityPosition(player.id())

  for connection, playerData in pairs(typingPlayers or {}) do
    local entityId = playerData.id

    if entityId and world.entityExists(entityId) then
      local entityPosition = world.entityPosition(entityId)
      if entityPosition then
        local distance = world.distance(entityPosition, localPosition)
        table.insert(typingPlayerEntries, {
          name = playerData.name or "Unknown",
          distance = distance,
          id = entityId
        })
      end
    end
  end

  table.sort(typingPlayerEntries, function(a, b)
    return a.distance < b.distance
  end)

  local typingPlayerCount = #typingPlayerEntries
  local typingPlayerNames = {}
  for _, entry in ipairs(typingPlayerEntries) do
    table.insert(typingPlayerNames, entry.name)
  end

  if typingPlayerCount == 1 then
    return starcustomchat.utils.getTranslation("chat.typing.typing_one", typingPlayerNames[1])
  elseif typingPlayerCount < 4 then
    local firstNames = {}
    for i = 1, typingPlayerCount - 1 do
      table.insert(firstNames, typingPlayerNames[i])
    end
    return starcustomchat.utils.getTranslation("chat.typing.typing_few", table.concat(firstNames, ", "), typingPlayerNames[typingPlayerCount])
  end

  return starcustomchat.utils.getTranslation("chat.typing.typing_multiple")
end

function typing:onTextboxCallback()
  if self.sendTypingIndicatorTime <= 0 then
    local players = starcustomchat.utils.playersInRadius(self.playerRadius, true, true)

    for _, pl in ipairs(players) do 
      world.sendEntityMessage(pl, self.addTypingEntityMessageName, {
        id = player.id(),
        connection = starcustomchat.utils.entityIdToConnection(player.id()),
        name = player.name()
      })
    end

    self.sendTypingIndicatorTime = self.typingResendInterval
  end
end

function typing:onSendMessage(message)
  local players = starcustomchat.utils.playersInRadius(self.playerRadius, true, true)
  
  for _, pl in ipairs(players) do 
    world.sendEntityMessage(pl, self.removeTypingEntityMessageName, {
      id = player.id(),
      connection = starcustomchat.utils.entityIdToConnection(player.id()),
      name = player.name()
    })
  end
end

function typing:update(dt)

  -- Client part: resend interval for everyone
  self.sendTypingIndicatorTime = math.max(0, self.sendTypingIndicatorTime - dt)

  -- Server part: if the time runs out from the person, remove them from the list
  for playerConn, playerData in pairs(self.typingPlayers) do 
    self.typingPlayers[playerConn].time = self.typingPlayers[playerConn].time + dt

    if self.typingPlayers[playerConn].time > self.typingResendInterval * 2 then
      self.typingPlayers[playerConn] = nil
    end
  end

  if next(self.typingPlayers) ~= nil then
    self.typingFrameTime = self.typingFrameTime + dt
    local typingFrame = (math.floor(self.typingFrameTime / self.dotsSpeed) % 3) + 1

    -- Drawing part: we need to draw the message if the typing is here. It should ALWAYS be the last one, and only in modern mode
    if self.customChat.chatMode == "modern" then

      for i = #self.customChat.drawnMessageIndexes, 1, -1 do 
        local message = self.customChat.messages[self.customChat.drawnMessageIndexes[i]]

        if message.connection and self.typingPlayers[message.connection] and message.avatar then
          
          -- Copied from self.customChat:drawImage
          local size = portraitSizeFromBaseFont(self.customChat.config.fontSize)
          local offset = vec2.add(self.customChat.config.iconImageOffset, {0, message.offset})
          self.customChat.topCanvas:drawImageRect(self.overlayImage .. ":" .. typingFrame, {0, 0, self.indicatorImageSize[1], self.indicatorImageSize[2]}, {offset[1], offset[2], offset[1] + size, offset[2] + size})
        end
      end
    end
    
    -- Text part
    local typingText = self:buildTypingText(self.typingPlayers)
    self.customChat:setInformationalText(typingText .. string.rep(".", typingFrame))

  else
    self.typingFrameTime = 0
    self.customChat:resetInformationalText()
  end
end

function typing:onReceiveMessage(message)
  if self.typingMessageUUID and self.customChat:findMessageByUUID(self.typingMessageUUID) then
    self.customChat:deleteMessage(self.typingMessageUUID)
    self.typingMessageUUID = nil
  end
end

function typing:uninit()
  if self.typingMessageUUID and self.customChat:findMessageByUUID(self.typingMessageUUID) then
    self.customChat:deleteMessage(self.typingMessageUUID)
    self.typingMessageUUID = nil
  end
end