require "/interface/scripted/starcustomchat/plugin.lua"

mainchat = PluginClass:new(
  { name = "mainchat" }
)

function mainchat:init(chat)
  self:_loadConfig()

  self.customChat = chat
  self.ReplyTimer = 5
  self.ReplyTime = 0

  self.DMingTo = config.getParameter("DMingTo")

  if self.DMingTo and not widget.active("lytDMingTo") then
    widget.setPosition("lytCommandPreview", vec2.add(widget.getPosition("lytCommandPreview"), {0, widget.getSize("lytDMingTo")[2]}))
    widget.setPosition("cnvChatCanvas", vec2.add(widget.getPosition("cnvChatCanvas"), {0, widget.getSize("lytDMingTo")[2]}))
    widget.setPosition("cnvHighlightCanvas", vec2.add(widget.getPosition("cnvHighlightCanvas"), {0, widget.getSize("lytDMingTo")[2]}))

    widget.setVisible("lytDMingTo", true)
    widget.setText("lytDMingTo.lblRecepient", self.DMingTo)
  end
end

function mainchat:registerMessageHandlers(shared)

  shared.setMessageHandler( "icc_ping", function(_, _, source)
    starcustomchat.utils.alert("chat.alerts.was_pinged", source)
    pane.playSound(self.pingSound)
  end)

end
function mainchat:onLocaleChange()
  widget.setText("lytDMingTo.lblHint", starcustomchat.utils.getTranslation("chat.dming.hint"))
  widget.setPosition("lytDMingTo.lblRecepient", vec2.add(widget.getPosition("lytDMingTo.lblHint"), {widget.getSize("lytDMingTo.lblHint")[1] + 3, 0}))
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

function mainchat:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)

  if buttonName == "copy" then
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

function mainchat:onTextboxEscape()
  if self.DMingTo then
    self:resetDMLayout()
    widget.focus("tbxInput")
    return true
  end
end

function mainchat:onTextboxEnter(message)
  if message.mode == "Whisper" or self.DMingTo then
    local whisperName
    if self.DMingTo then
      whisperName = self.DMingTo
      self:resetDMLayout()
    else
      local li = widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")
      if not li then starcustomchat.utils.alert("chat.alerts.dm_not_specified") return end

      local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
      if not world.entityExists(data.id) then starcustomchat.utils.alert("chat.alerts.dm_not_found") return end

      whisperName = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")).tooltipMode
    end

    local whisper = string.find(whisperName, "%s") and "/w \"" .. whisperName .. "\" " .. message.text 
      or "/w " .. whisperName .. " " .. message.text

    self.customChat:processCommand(whisper)
    self.customChat.lastWhisper = {
      recipient = whisperName,
      text = message.text
    }
    starcustomchat.utils.saveMessage(whisper)
    return true
  end
end

function mainchat:onBackgroundChange(chatConfig)
  chatConfig.DMingTo = self.DMingTo
end

function mainchat:resetDMLayout()
  if widget.active("lytDMingTo") then
    widget.setPosition("lytCommandPreview", vec2.sub(widget.getPosition("lytCommandPreview"), {0, widget.getSize("lytDMingTo")[2]}))
    widget.setPosition("cnvChatCanvas", vec2.sub(widget.getPosition("cnvChatCanvas"), {0, widget.getSize("lytDMingTo")[2]}))
    widget.setPosition("cnvHighlightCanvas", vec2.sub(widget.getPosition("cnvHighlightCanvas"), {0, widget.getSize("lytDMingTo")[2]}))
  end

  self.DMingTo = nil
  widget.setVisible("lytDMingTo", false)
end

function mainchat:contextMenuButtonClick(buttonName, selectedMessage)
  if selectedMessage then
    if buttonName == "copy" then
      clipboard.setText(selectedMessage.text)
      starcustomchat.utils.alert("chat.alerts.copied_to_clipboard")
    elseif buttonName == "dm" then
      if not widget.active("lytDMingTo") then

        widget.setPosition("lytCommandPreview", vec2.add(widget.getPosition("lytCommandPreview"), {0, widget.getSize("lytDMingTo")[2]}))
        widget.setPosition("cnvChatCanvas", vec2.add(widget.getPosition("cnvChatCanvas"), {0, widget.getSize("lytDMingTo")[2]}))
        widget.setPosition("cnvHighlightCanvas", vec2.add(widget.getPosition("cnvHighlightCanvas"), {0, widget.getSize("lytDMingTo")[2]}))
      end
      widget.setVisible("lytDMingTo", true)

      self.DMingTo = selectedMessage.recipient or selectedMessage.nickname
      widget.setText("lytDMingTo.lblRecepient", self.DMingTo)
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
    end
  end
end

function mainchat:onCustomButtonClick(buttonName, data)
  if buttonName == "resetDMLayout" then
    self:resetDMLayout()
    widget.focus("tbxInput")
  end
end