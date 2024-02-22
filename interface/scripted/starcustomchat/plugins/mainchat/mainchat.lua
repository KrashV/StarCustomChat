require "/interface/scripted/starcustomchat/plugin.lua"

mainchat = PluginClass:new(
  { name = "mainchat" }
)

function mainchat:init()
  self:_loadConfig()
end

function mainchat:update()
  local id = findButtonByMode("Party")
  if #player.teamMembers() == 0 then
    widget.setButtonEnabled("rgChatMode." .. id, false)
    if widget.getSelectedData("rgChatMode").mode == "Party" then
      widget.setSelectedOption("rgChatMode", 1)
    end
  else
    widget.setButtonEnabled("rgChatMode." .. id, true)
  end
end

function mainchat:formatIncomingMessage(message)
  if message.mode == "CommandResult" then
    message.portrait = self.modeIcons.console
    message.nickname = "Console"    
  elseif message.mode == "RadioMessage" then
    message.portrait = message.portrait or self.modeIcons.server
    message.nickname = message.nickname or "Server"
  elseif message.mode == "Whisper" or message.mode == "Local" or message.mode == "Broadcast" or message.mode == "Party" or message.mode == "World" then
    if message.connection == 0 then
      message.portrait = message.portrait or self.modeIcons.server
      message.nickname = message.nickname or "Server"
    else
      message.portrait = message.portrait and message.portrait ~= "" and message.portrait or message.connection
      message.nickname = message.nickname or ""
    end
  end

  return message
end

function mainchat:onSendMessage(data)
  if data.mode == "Broadcast" or data.mode == "Local" or data.mode == "Party" then
    chat.send(data.text, data.mode)
  end
end

function mainchat:onModeChange(mode)
  widget.setVisible("lytCharactersToDM", mode == "Whisper")
end



--[[
  Context menu items
]]


function ctxCopyFilter()
  return true
end

function ctxCopy()
  if self.selectedMessage then
    clipboard.setText(self.selectedMessage.text)
    starcustomchat.utils.alert("chat.alerts.copied_to_clipboard")
  end
end

function ctxDMFilter(chat, screenPosition, selectedMessage)
  return selectedMessage and selectedMessage.connection ~= 0 and selectedMessage.mode ~= "CommandResult" and selectedMessage.nickname
end

function ctxDM()
  if self.selectedMessage then
    if self.selectedMessage.connection == 0 then
      starcustomchat.utils.alert("chat.alerts.cannot_dm_server")
    elseif self.selectedMessage.mode == "CommandResult" then
      starcustomchat.utils.alert("chat.alerts.cannot_dm_command_result")
    elseif self.selectedMessage.connection and self.selectedMessage.nickname then
      if not widget.active("lytDMingTo") then
        widget.setPosition("lytCommandPreview", vec2.add(widget.getPosition("lytCommandPreview"), {0, widget.getSize("lytDMingTo")[2]}))
        widget.setPosition(self.canvasName, vec2.add(widget.getPosition(self.canvasName), {0, widget.getSize("lytDMingTo")[2]}))
        widget.setPosition(self.highlightCanvasName, vec2.add(widget.getPosition(self.highlightCanvasName), {0, widget.getSize("lytDMingTo")[2]}))
      end
      widget.setVisible("lytDMingTo", true)
      self.DMingTo = self.selectedMessage.recipient or self.selectedMessage.nickname
      widget.setText("lytDMingTo.lblRecepient", self.DMingTo)
      widget.focus("tbxInput")
    end
  end
end

function ctxPingFilter(chat, screenPosition, selectedMessage)
  return selectedMessage and selectedMessage.connection ~= 0 and selectedMessage.mode ~= "CommandResult" 
    and selectedMessage.connection * -65536 ~= player.id()
    and selectedMessage.nickname
end

function ctxPing()
  if self.selectedMessage then
    local message = copy(self.selectedMessage)
    if message.connection == 0 then
      starcustomchat.utils.alert("chat.alerts.cannot_ping_server")
    elseif message.mode == "CommandResult" then
      starcustomchat.utils.alert("chat.alerts.cannot_ping_command")
    elseif message.connection and message.nickname then
      if self.ReplyTime > 0 then
        starcustomchat.utils.alert("chat.alerts.cannot_ping_time", math.ceil(self.ReplyTime))
      else
        
        local target = message.connection * -65536
        if target == player.id() then
          starcustomchat.utils.alert("chat.alerts.cannot_ping_yourself")
        else
          promises:add(world.sendEntityMessage(target, "icc_ping", player.name()), function()
            starcustomchat.utils.alert("chat.alerts.pinged", message.nickname)
          end, function()
            starcustomchat.utils.alert("chat.alerts.ping_failed", message.nickname)
          end)

          self.ReplyTime = self.ReplyTimer
        end
      end
    end
  end
end

function ctxCollapseFilter(chat, screenPosition, selectedMessage)
  local allowCollapse = chat.maxCharactersAllowed ~= 0 and selectedMessage.isLong

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

function ctxCollapse()
  if self.selectedMessage then
    self.customChat:collapseMessage({0, self.selectedMessage.offset + 1})
  end
end