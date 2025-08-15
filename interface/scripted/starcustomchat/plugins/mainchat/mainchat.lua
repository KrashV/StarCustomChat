require "/interface/scripted/starcustomchat/plugin.lua"

mainchat = PluginClass:new(
  { name = "mainchat" }
)

function mainchat:init(chat)
  PluginClass.init(self, chat)
  self.ReplyTimer = 5
  self.ReplyTime = 0

  self.pressedDelete = false
  local DMIngToUUID = config.getParameter("DMingTo")

  if DMIngToUUID then
    self.DMingTo = self.customChat:findMessageByUUID(DMIngToUUID)
    if self.DMingTo then
      self.customChat:openSubMenu("DMs", starcustomchat.utils.getTranslation("chat.dming.hint"), self.DMingTo.displayName or self.DMingTo.nickname)
    end
  end

  self.previewPortraits = root.getConfiguration("scc_preview_portraits")
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

local function isMouseOverPortrait(screenPosition, messageOffset, messageHeight)
  local offset = vec2.add(widget.getPosition("chatLog"), self.customChat.config.portraitImageOffset)
  local size = portraitSizeFromBaseFont(self.customChat.config.fontSize)

  offset[2] = offset[2] + messageOffset - math.min(messageHeight, size - messageHeight)
  local rect = {offset[1], offset[2], offset[1] + size, offset[2] + size}
  
  return screenPosition[1] >= rect[1] and screenPosition[1] <= rect[3]
    and screenPosition[2] >= rect[2] and screenPosition[2] <= rect[4]

end


function mainchat:onCursorOverride(screenPosition)
  local selectedMessage = self.customChat:selectMessage()
  if self.previewPortraits and selectedMessage and selectedMessage.connection and 
    (self.customChat.connectionToUuid[tostring(selectedMessage.connection)] or selectedMessage.mode == "RadioMessage" and selectedMessage.portrait) then
    
    local uuid = self.customChat.connectionToUuid[tostring(selectedMessage.connection)]

    if isMouseOverPortrait(screenPosition, selectedMessage.offset, selectedMessage.height) and ((selectedMessage.mode == "RadioMessage" and selectedMessage.portrait) or (self.customChat.savedPortraits[uuid] and type(self.customChat.savedPortraits[uuid].portrait) == "string")) then
      local portrait = self.customChat.savedPortraits[uuid] and self.customChat.savedPortraits[uuid].portrait or selectedMessage.portrait
      
      local portraitSize = starcustomchat.utils.safeImageSize(portrait)
      if portraitSize then
        widget.setImageScale("lblPortraitPreview.background", portraitSize[1] / root.imageSize("/interface/scripted/starcustomchat/base/icons/empty.png")[1] * self.customChat.config.portraitPreviewSize )

        widget.setImageScale("lblPortraitPreview.portrait", self.customChat.config.portraitPreviewSize )
        widget.setImage("lblPortraitPreview.portrait", portrait)
        local frame = self.customChat.savedPortraits[uuid] and self.customChat.savedPortraits[uuid].frame or "/interface/scripted/starcustomchat/base/icons/frame.png"

        widget.setImageScale("lblPortraitPreview.frame", portraitSize[1] / root.imageSize(frame)[1] * self.customChat.config.portraitPreviewSize )
        widget.setImage("lblPortraitPreview.frame", frame)
        widget.setPosition("lblPortraitPreview", screenPosition)
        widget.setVisible("lblPortraitPreview", true)
      end
      return
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
  if message.mode == "Broadcast" or message.mode == "Local" or message.mode == "Party" then
    chat.send(message.text, message.mode, not message.silent, message.data)
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
    elseif buttonName == "confirm_delete" or buttonName == "cancel_delete" then
      return self.pressedDelete
    elseif buttonName == "delete" then
      return true
    elseif buttonName == "dm" then
      return selectedMessage and selectedMessage.connection ~= 0 and selectedMessage.mode ~= "CommandResult" and selectedMessage.nickname
    elseif buttonName == "ping" then
      return selectedMessage and selectedMessage.connection ~= 0 and selectedMessage.mode ~= "CommandResult" and selectedMessage.nickname
        and selectedMessage.connection * -65536 ~= player.id()
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
      clipboard.setText(selectedMessage.text)
      starcustomchat.utils.alert("chat.alerts.copied_to_clipboard")
    elseif buttonName == "dm" then
      self.DMingTo = selectedMessage
      self.customChat:openSubMenu("DMs", starcustomchat.utils.getTranslation("chat.dming.hint"), selectedMessage.displayName or selectedMessage.nickname)
      widget.focus("tbxInput")

    elseif buttonName == "ping" then
      if self.ReplyTime > 0 then
        starcustomchat.utils.alert("chat.alerts.cannot_ping_time", math.ceil(self.ReplyTime))
      else
        
        local target = selectedMessage.connection * -65536
        if target == player.id() then
          starcustomchat.utils.alert("chat.alerts.cannot_ping_yourself")
        else
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