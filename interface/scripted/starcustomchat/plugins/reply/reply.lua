require "/interface/scripted/starcustomchat/plugin.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"

reply = PluginClass:new(
  { name = "reply" }
)

function reply:init(chat)
  self:_loadConfig()

  self.customChat = chat
  self.replyingToMessage = config.getParameter("replyingToMessage")

  if self.replyingToMessage then
    self.customChat:openSubMenu("reply", starcustomchat.utils.getTranslation("chat.reply.recipient", self.replyingToMessage.nickname), self:cropMessage(self.replyingToMessage.text))
  end
  self.messagesToReply = {}

  self.highlightMessageInd = nil
  self.desaturateTime = 0
end

function reply:registerMessageHandlers(shared)
  shared.setMessageHandler( "icc_message_reply", function(_, _, data)
    if data and data.originalMessageUUID  then
      local oldMessageInd = self.customChat:findMessageByUUID(data.originalMessageUUID)
      local newMessageInd = self.customChat:findMessageByUUID(data.newMessageUUID)

      if newMessageInd and oldMessageInd then
        self.customChat.messages[newMessageInd].replyUUID = data.originalMessageUUID
        self.customChat:processQueue()
      elseif oldMessageInd then
        self.messagesToReply[data.newMessageUUID] = data.originalMessageUUID
      end
    end
  end)
end

function reply:onReceiveMessage(message)
  if self.messagesToReply[message.uuid] then
    message.replyUUID = self.messagesToReply[message.uuid]
    self.messagesToReply[message.uuid] = nil
  end
end

function reply:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)
  if selectedMessage and buttonName == "reply" then
    return selectedMessage.mode ~= "CommandResult"
  end
end

function reply:contextMenuButtonClick(buttonName, selectedMessage)
  if selectedMessage and selectedMessage.uuid and buttonName == "reply" then
    self.replyingToMessage = selectedMessage
    self.customChat:openSubMenu("reply", starcustomchat.utils.getTranslation("chat.reply.recipient", selectedMessage.nickname), self:cropMessage(selectedMessage.text))
    widget.focus("tbxInput")
  end
end

function reply:cropMessage(text)
  return utf8.len(text) < self.trimLength and text or starcustomchat.utils.utf8Substring(text, 1, self.trimLength) .. "..."
end

function reply:onCustomButtonClick(buttonName, data)
  if self.replyingToMessage then
    self.customChat:closeSubMenu()
    self.replyingToMessage = nil
  end
end

function reply:onTextboxEnter()
  local function calculateNewMessageUUID(connection, text, mode, nickname)
    local tempMessage = self.customChat.callbackPlugins("formatIncomingMessage", {
      connection = connection,
      text = text,
      mode = mode,
      nickname = nickname
    })
    return util.hashString(tempMessage.connection .. tempMessage.text)
  end

  if self.replyingToMessage then
    local dataToSend = {
      message = "replying", 
      originalMessageUUID = self.replyingToMessage.uuid,
      newMessageUUID = calculateNewMessageUUID(player.id() // -65536, widget.getText("tbxInput"), 
        widget.getSelectedData("rgChatMode").mode, player.name()) 
  }
    if self.stagehandType then
      starcustomchat.utils.createStagehandWithData(self.stagehandType, dataToSend)
    else
      for _, pl in ipairs(world.playerQuery(world.entityPosition(player.id()), self.messageRadius)) do 
        world.sendEntityMessage(pl, "icc_message_reply", dataToSend)
      end
    end

    self.customChat:closeSubMenu()
    self.replyingToMessage = nil
    return false
  end
end

function reply:onTextboxEscape()
  if self.replyingToMessage then
    self.customChat:closeSubMenu()
    self.replyingToMessage = nil
    return false
  end
end

function lerpColor(hex1, hex2, t)
  local function hexToRGBA(hex)
      local r, g, b, a = hex:match("#?(..)(..)(..)(..)")
      return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), tonumber(a, 16)
  end

  local function rgbaToHex(r, g, b, a)
      return string.format("#%02x%02x%02x%02x", r, g, b, a)
  end

  if 1 - t < 0.000001 then return hex2 end

  local r1, g1, b1, a1 = hexToRGBA(hex1)
  local r2, g2, b2, a2 = hexToRGBA(hex2)
  
  local r = r1 + (r2 - r1) * t
  local g = g1 + (g2 - g1) * t
  local b = b1 + (b2 - b1) * t
  local a = a1 + (a2 - a1) * t
  
  return rgbaToHex(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
end

function reply:update(dt)
  if self.replyingToMessage then
    self.customChat:highlightMessage(self.replyingToMessage, self.highlightReplyColor)
  end

  if self.highlightMessageInd then
    local newColor = lerpColor(self.highlightReplyColor, "#00000000", self.desaturateTime / self.desaturateTimer)

    self.customChat:highlightMessage(self.customChat.messages[self.highlightMessageInd], newColor)
    self.desaturateTime = self.desaturateTime + dt 
    if newColor == "#00000000" then
      self.highlightMessageInd = nil
      self.desaturateTime = 0 
    end
  end
end

function reply:onBackgroundChange(chatConfig)
  chatConfig.replyingToMessage = self.replyingToMessage
  return chatConfig
end

function reply:onSubMenuReopen(type)
  if type ~= "reply" then
    self.replyingToMessage = nil
  end
end

function reply:onCanvasClick(screenPosition, button, isButtonDown)
  if button == 0 and isButtonDown then
    local selectedMessage = self.customChat:selectMessage()
    if selectedMessage and selectedMessage.replyUUID then
      if selectedMessage.height - (screenPosition[2] - selectedMessage.offset) < self.customChat.config.replyOffsetHeight then
        local originalMessage = self.customChat:findMessageByUUID(selectedMessage.replyUUID)
        if originalMessage then
          self.customChat:scrollToMessage(originalMessage)
          self.highlightMessageInd = originalMessage
        end
        return true
      end
    end
  end
end