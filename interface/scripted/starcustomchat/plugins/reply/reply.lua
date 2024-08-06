require "/interface/scripted/starcustomchat/plugin.lua"

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

function reply:update(dt)
  if self.replyingToMessage then
    self.customChat:highlightMessage(self.replyingToMessage, self.highlightReplyColor)
  end
  sb.setLogMap("Replying", sb.print(self.messagesToReply))
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