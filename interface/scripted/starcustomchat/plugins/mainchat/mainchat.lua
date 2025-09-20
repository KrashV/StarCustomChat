require "/interface/scripted/starcustomchat/plugin.lua"

mainchat = PluginClass:new(
  { name = "mainchat" }
)

function mainchat:init(chat)
  PluginClass.init(self, chat)
  self.ReplyTimer = 5
  self.ReplyTime = 0

  self.pressedDelete = false
  self.pressedCopy = false
  local DMIngToUUID = config.getParameter("DMingTo")

  if DMIngToUUID then
    self.DMingTo = self.customChat:findMessageByUUID(DMIngToUUID)
    if self.DMingTo then
      self.customChat:openSubMenu("DMs", starcustomchat.utils.getTranslation("chat.dming.hint"), self.DMingTo.displayName or self.DMingTo.nickname)
    end
  end

  self.previewPortraits = root.getConfiguration("scc_preview_portraits")
  self.previewPlayerCanvas = widget.bindCanvas("lblPortraitPreview.playerCanvas")
  self.backImageSize = root.imageSize("/interface/scripted/starcustomchat/base/icons/empty.png")
end

function mainchat:registerMessageHandlers()

  starcustomchat.utils.setMessageHandler( "icc_ping", function(_, _, source)
    starcustomchat.utils.alert("chat.alerts.was_pinged", source)
    if type(self.pingSound) == "table" then
      pane.playSound(self.pingSound[math.random(1, #self.pingSound)])
    else
      pane.playSound(self.pingSound)
    end
  end)

end

function mainchat:onLocaleChange()
  if self.DMingTo then
    self.customChat:setSubMenuTexts(starcustomchat.utils.getTranslation("chat.dming.hint"), self.DMingTo.displayName or self.DMingTo.nickname)
  end
end

function mainchat:formatOutcomingMessage(message)
  message.text = message.text:gsub("\\n", "\n")
  return message
end

local function isMouseOverPortrait(screenPosition, message)
  local messageOffset = message.offset
  local messageHeight = message.height
  local offset = vec2.add(widget.getPosition("chatLog"), self.customChat.config.portraitImageOffset)
  if pane.getPosition then
    offset = vec2.add(offset, pane.getPosition())
  end

  local size = portraitSizeFromBaseFont(self.customChat.config.fontSize)

  offset[2] = offset[2] + messageOffset - math.min(messageHeight, size - messageHeight) + self.customChat.config.nameOffset[2] + self.customChat.config.fontSize + 1
  if message.replyUUID then
    offset[2] = offset[2] - self.customChat.config.replyOffsetHeight * self.customChat.config.fontSize / 10
  end
  
  return rect.contains({offset[1], offset[2], offset[1] + size, offset[2] + size}, screenPosition)
end


function mainchat:onCursorOverride(screenPosition)
  local selectedMessage = self.customChat:selectMessage()
  if self.previewPortraits and selectedMessage and selectedMessage.connection and 
    (self.customChat.connectionToUuid[tostring(selectedMessage.connection)] or selectedMessage.mode == "RadioMessage" and selectedMessage.portrait) then
    
    local uuid = self.customChat.connectionToUuid[tostring(selectedMessage.connection)]

    if isMouseOverPortrait(screenPosition, selectedMessage) and ((selectedMessage.mode == "RadioMessage" and selectedMessage.portrait) or self.customChat.savedPortraits[uuid]) then
      local portrait = self.customChat.savedPortraits[uuid] and self.customChat.savedPortraits[uuid].portrait or selectedMessage.portrait
      
      if type(portrait) == "string" then
        self.previewPlayerCanvas:clear()

        local portraitSize = starcustomchat.utils.safeImageSize(portrait)
        if portraitSize then
          widget.setImageScale("lblPortraitPreview.background", portraitSize[1] / self.backImageSize[1] * self.customChat.config.portraitPreviewSize )

          widget.setImageScale("lblPortraitPreview.portrait", self.customChat.config.portraitPreviewSize )
          widget.setImage("lblPortraitPreview.portrait", portrait)
          local frame = self.customChat.savedPortraits[uuid] and self.customChat.savedPortraits[uuid].frame or "/interface/scripted/starcustomchat/base/icons/frame.png"

          widget.setImageScale("lblPortraitPreview.frame", portraitSize[1] / root.imageSize(frame)[1] * self.customChat.config.portraitPreviewSize )
          widget.setImage("lblPortraitPreview.frame", frame)

        end
      else--if table
        self.previewPlayerCanvas:clear()
        widget.setImage("lblPortraitPreview.portrait", "")
        widget.setImageScale("lblPortraitPreview.background", self.customChat.config.defaultPortraitScale )
        widget.setImage("lblPortraitPreview.frame", "/interface/scripted/starcustomchat/base/icons/frame.png")
        widget.setImageScale("lblPortraitPreview.frame", self.customChat.config.defaultPortraitScale )

        for _, layer in ipairs(portrait) do
          self.previewPlayerCanvas:drawImage(layer.image, 
            self.customChat.savedPortraits[uuid].settings and self.customChat.savedPortraits[uuid].settings.offset or self.customChat.config.defaultPortraitOffset, 
            self.customChat.savedPortraits[uuid].settings and self.customChat.savedPortraits[uuid].settings.scale or self.customChat.config.defaultPortraitScale)
        end
      end

        local layoutPosition = screenPosition
        if pane.getPosition then
          layoutPosition = vec2.sub(layoutPosition, pane.getPosition())
        end
        
        if layoutPosition[2] > widget.getSize("chatLog")[2] * self.customChat.config.portraitFlipCanvasPart then
          layoutPosition[2] = layoutPosition[2] - widget.getSize("lblPortraitPreview.background")[2]
        end


        widget.setPosition("lblPortraitPreview", layoutPosition)
        widget.setVisible("lblPortraitPreview", true)
    end
  end
end

function mainchat:update(dt)
  local id = findButtonByMode("Party")
  if #player.teamMembers() == 0 then
    widget.setButtonEnabled("rgChatMode." .. id, false)
    if widget.getSelectedData("rgChatMode").mode == "Party" then
      widget.setSelectedOption("rgChatMode", 1)
    end
  else
    widget.setButtonEnabled("rgChatMode." .. id, true)
  end

  self.ReplyTime = math.max(self.ReplyTime - dt, 0)

  widget.setVisible("lblPortraitPreview", false)
end

function mainchat:getTime(timezoneOffset)
  if os.date then
    local time = os.date("*t")
    return string.format("%02d:%02d", time.hour, time.min)
  else
    local timestamp = os.time()
    -- Adjust timestamp by timezone offset (in seconds)
    local adjusted = timestamp + (timezoneOffset * 3600)

    local secondsInDay = adjusted % 86400
    local hour = math.floor(secondsInDay / 3600)
    local minute = math.floor((secondsInDay % 3600) / 60)

    return string.format("%02d:%02d", hour, minute)
  end
end


function mainchat:formatIncomingMessage(message)
  if message.mode == "CommandResult" then
    message.portrait = self.modeIcons.console
    message.nickname = "Console"
    message.color = self.customChat:getColor("servertext")
  elseif message.mode == "RadioMessage" then
    message.portrait = message.portrait or self.modeIcons.server
    message.nickname = message.nickname or "Server"
  elseif message.mode == "Whisper" or message.mode == "Local" or message.mode == "Broadcast" or message.mode == "Party" or message.mode == "World" then
    if message.connection == 0 then
      message.portrait = message.portrait or self.modeIcons.server
      message.nickname = message.nickname or "Server"
      message.color = self.customChat:getColor("servertext")
    else
      message.portrait = message.portrait and message.portrait ~= "" and message.portrait or message.connection
      message.nickname = message.nickname or ""
    end
  end

  message.time = self:getTime(self.customChat.timezoneOffset)
  return message
end

function mainchat:onSendMessage(message)
  local silent = message.silent
  if message.mode == "Broadcast" or message.mode == "Local" or message.mode == "Party" then
    chat.send(message.text, message.mode, not silent, message.data)
  end
end

function mainchat:onModeChange(mode)
  widget.setVisible("lytCharactersToDM", mode == "Whisper")
end

--[[
  Context menu items
]]

function mainchat:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)

  if selectedMessage then
    if buttonName == "copy" then
      return not selectedMessage.image
    elseif buttonName == "copy_noformatting" then
      return not selectedMessage.image and self.pressedCopy
    elseif buttonName == "confirm_delete" or buttonName == "cancel_delete" then
      return self.pressedDelete
    elseif buttonName == "delete" then
      return true
    elseif buttonName == "dm" then
      return selectedMessage and selectedMessage.connection ~= 0 and selectedMessage.mode ~= "CommandResult" and selectedMessage.nickname
    elseif buttonName == "ping" then
      local playerId = player.id()
      -- FezzedOne: Checks if the given player ID is within the entity ID space allotted for the client's connection ID.
      -- If so, the player is controlled by that client.
      local clientMatchesPlayer = playerId >= selectedMessage.connection * -65536 and playerId < (selectedMessage.connection - 1) * -65536
      return selectedMessage and selectedMessage.connection ~= 0 and selectedMessage.mode ~= "CommandResult" and selectedMessage.nickname
        and not clientMatchesPlayer
    elseif buttonName == "collapse" then
      local allowCollapse = self.customChat.maxCharactersAllowed ~= 0 and selectedMessage.isLong

      if allowCollapse then
        widget.setButtonImages("lytContext.collapse", {
          base = string.format("/interface/scripted/starcustomchat/base/contextmenu/%s.png:base", selectedMessage.collapsed and "uncollapse" or "collapse"),
          hover = string.format("/interface/scripted/starcustomchat/base/contextmenu/%s.png:hover", selectedMessage.collapsed and "uncollapse" or "collapse")
        })
        widget.setData("lytContext.collapse", {
          displayText = string.format("chat.commands.%s", selectedMessage.collapsed and "uncollapse" or "collapse")
        })
      end
    
      return widget.inMember("lytContext", screenPosition) and allowCollapse
    end
  end
end

function mainchat:onTextboxEscape()
  if self.DMingTo then
    self.customChat:closeSubMenu()
    if widget.getText("tbxInput") == "" then
      widget.blur("tbxInput")
    end
    self.DMingTo = nil
    return true
  end
end

function mainchat:onTextboxEnter(message)
  if self.DMingTo then
    local whisperName = self.DMingTo.nickname
    self.customChat:closeSubMenu()

    local whisper = string.find(whisperName, "%s") and "/w \"" .. whisperName .. "\" " .. message.text 
      or "/w " .. whisperName .. " " .. message.text

    self.customChat:processCommand(whisper)
    self.customChat.lastWhisper = {
      recipient = self.DMingTo.displayName or self.DMingTo.nickname,
      text = message.text
    }
    starcustomchat.utils.saveMessage(whisper)
    self.DMingTo = nil
    return true
  end
end

function mainchat:onBackgroundChange(chatConfig)
  chatConfig.DMingTo = self.DMingTo and self.DMingTo.uuid or nil
  return chatConfig
end

function mainchat:onSubMenuReopen(type)
  if type ~= "DMs" then
    self.DMingTo = nil
  end
end

function mainchat:contextMenuButtonClick(buttonName, selectedMessage)
  if selectedMessage then
    if buttonName == "copy" then
      if not self.pressedCopy then
        self.pressedCopy = true
      else
        self.pressedCopy = false
        clipboard.setText(selectedMessage.text)
        starcustomchat.utils.alert("chat.alerts.copied_to_clipboard")
      end
    elseif buttonName == "copy_noformatting" then
        self.pressedCopy = false
        clipboard.setText(starcustomchat.utils.clearMetatags(selectedMessage.text))
        starcustomchat.utils.alert("chat.alerts.copied_to_clipboard")
    elseif buttonName == "dm" then
      self.DMingTo = selectedMessage
      self.customChat:openSubMenu("DMs", starcustomchat.utils.getTranslation("chat.dming.hint"), selectedMessage.displayName or selectedMessage.nickname)
      widget.focus("tbxInput")

    elseif buttonName == "ping" then
      if self.ReplyTime > 0 then
        starcustomchat.utils.alert("chat.alerts.cannot_ping_time", math.ceil(self.ReplyTime))
      else
        local playerId = player.id()
        local target = selectedMessage.connection * -65536
        local clientMatchesPlayer = playerId >= selectedMessage.connection * -65536 and playerId < (selectedMessage.connection - 1) * -65536
        if clientMatchesTarget then
          starcustomchat.utils.alert("chat.alerts.cannot_ping_yourself")
        else
          -- FezzedOne: Ensures an xStarbound client can always be pinged if any player controlled by it is rendered.
          target = (selectedMessage.senderId and world.entityExists(selectedMessage.senderId)) and selectedMessage.senderId
            or starcustomchat.utils.getPlayerIdFromConnection(selectedMessage.connection)
          promises:add(world.sendEntityMessage(target, "icc_ping", player.name()), function()
            starcustomchat.utils.alert("chat.alerts.pinged", selectedMessage.nickname)
          end, function()
            starcustomchat.utils.alert("chat.alerts.ping_failed", selectedMessage.nickname)
          end)

          self.ReplyTime = self.ReplyTimer
        end
      end
    elseif buttonName == "collapse" then
      self.customChat:collapseMessage({0, selectedMessage.offset + 1})
    elseif buttonName == "delete" then
      if self.pressedDelete then
        self.pressedDelete = false
        widget.setButtonImages("lytContext.delete", {
          base = "/interface/scripted/starcustomchat/base/contextmenu/delete.png:base",
          hover = "/interface/scripted/starcustomchat/base/contextmenu/delete.png:hover"
        })
        widget.setData("lytContext.delete", {
          displayText = "chat.commands.delete"
        })
      else
        self.pressedDelete = true
        widget.setButtonImages("lytContext.delete", {
          base = "/interface/scripted/starcustomchat/base/contextmenu/cancel.png:base",
          hover = "/interface/scripted/starcustomchat/base/contextmenu/cancel.png:hover"
        })
        widget.setData("lytContext.delete", {
          displayText = "chat.commands.cancel_delete"
        })
      end

    elseif buttonName == "confirm_delete" then
      self.customChat:deleteMessage(selectedMessage.uuid)
      self.pressedDelete = false
      widget.setButtonImages("lytContext.delete", {
        base = "/interface/scripted/starcustomchat/base/contextmenu/delete.png:base",
        hover = "/interface/scripted/starcustomchat/base/contextmenu/delete.png:hover"
      })
      widget.setData("lytContext.delete", {
        displayText = "chat.commands.delete"
      })
    end
  end
end

function mainchat:contextMenuReset()
  self.pressedDelete = false
  self.pressedCopy = false
  widget.setButtonImages("lytContext.delete", {
    base = "/interface/scripted/starcustomchat/base/contextmenu/delete.png:base",
    hover = "/interface/scripted/starcustomchat/base/contextmenu/delete.png:hover"
  })
  widget.setData("lytContext.delete", {
    displayText = "chat.commands.delete"
  })
end

function mainchat:onCustomButtonClick(buttonName, data)
  if self.DMingTo then
    self.customChat:closeSubMenu()
    self.DMingTo = nil
    if widget.getText("tbxInput") ~= "" then
      widget.focus("tbxInput")
    end
  end
end

function mainchat:onSettingsUpdate()
  self.customChat.timezoneOffset = root.getConfiguration("scc_timezone_offset") or 0
  self.previewPortraits = root.getConfiguration("scc_preview_portraits")
end