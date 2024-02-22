function processContextMenu(screenPosition)
  widget.setVisible("lytContext", not not self.selectedMessage)

  if widget.inMember(self.highlightCanvasName, screenPosition) then
    self.selectedMessage = self.customChat:selectMessage(widget.inMember("lytContext", screenPosition) and self.selectedMessage and {0, self.selectedMessage.offset + 1})
  else
    self.selectedMessage = nil
  end

  if widget.inMember("lytContext", screenPosition) then
    widget.setVisible("lytContext.btnDM", true)
    widget.setVisible("lytContext.btnCopy", true)
    widget.setVisible("lytContext.btnPing", true)
    widget.setVisible("lytContext.dots", false)
    widget.setSize("lytContext", {60, 15})
  else
    widget.setVisible("lytContext.dots", true)
    widget.setVisible("lytContext.btnDM", false)
    widget.setVisible("lytContext.btnCopy", false)
    widget.setVisible("lytContext.btnPing", false)
    widget.setSize("lytContext", {20, 15})
  end

  if self.selectedMessage then
    local allowCollapse = self.customChat.maxCharactersAllowed ~= 0 and self.selectedMessage.isLong
    widget.setVisible("lytContext.btnCollapse", widget.inMember("lytContext", screenPosition) and allowCollapse)

    if allowCollapse then
      widget.setButtonImages("lytContext.btnCollapse", {
        base = string.format("/interface/scripted/starcustomchat/base/contextmenu/%s.png:base", self.selectedMessage.collapsed and "uncollapse" or "collapse"),
        hover = string.format("/interface/scripted/starcustomchat/base/contextmenu/%s.png:hover", self.selectedMessage.collapsed and "uncollapse" or "collapse")
      })
      widget.setData("lytContext.btnCollapse", {
        displayText = string.format("chat.commands.%s", self.selectedMessage.collapsed and "uncollapse" or "collapse")
      })
    end
    
    local canvasPosition = widget.getPosition(self.highlightCanvasName)
    local xOffset = canvasPosition[1] + widget.getSize(self.highlightCanvasName)[1] - widget.getSize("lytContext")[1]
    local yOffset = self.selectedMessage.offset + self.selectedMessage.height + canvasPosition[2]
    local newOffset = vec2.add({xOffset, yOffset}, self.customChat.config.contextMenuOffset)

    -- And now we don't want the context menu to fly away somewhere else: we always want to draw it within the canvas
    newOffset[2] = math.min(newOffset[2], self.customChat.canvas:size()[2] + widget.getPosition(self.canvasName)[2] - widget.getSize("lytContext")[2])
    widget.setPosition("lytContext", newOffset)
  end
end

function copyMessage()
  if self.selectedMessage then
    clipboard.setText(self.selectedMessage.text)
    starcustomchat.utils.alert("chat.alerts.copied_to_clipboard")
  end
end

function enableDM()
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

function ping()
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

function collapse()
  if self.selectedMessage then
    self.customChat:collapseMessage({0, self.selectedMessage.offset + 1})
  end
end