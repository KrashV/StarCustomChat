function contextMenu_init(buttonsConfig)
  self.contextMenu = {}
  self.contextMenu.buttonConfigs = {}
  self.contextMenu.dotsSize = root.imageSize(config.getParameter("gui")["lytContext"]["children"]["dots"]["base"])

  local position = {0, 0}
  for _, btnConfig in ipairs(buttonsConfig) do 
    local buttonSize = root.imageSize(btnConfig["base"])

    widget.addChild("lytContext", {
      type = "button",
      base = btnConfig["base"],
      hover = btnConfig["hover"],
      callback = "contextMenuButtonClick",
      visible = false,
      data = {
        displayText = btnConfig["tooltip"]
      }
    }, btnConfig.name)

    table.insert(self.contextMenu.buttonConfigs, {
      name = btnConfig.name,
      size = buttonSize
    })
  end
end

function processContextMenu(screenPosition)
  widget.setVisible("lytContext", not not self.selectedMessage)

  if widget.inMember(self.highlightCanvasName, screenPosition) then
    self.selectedMessage = self.customChat:selectMessage(widget.inMember("lytContext", screenPosition) and self.selectedMessage and {0, self.selectedMessage.offset + 1})
  else
    self.selectedMessage = nil
  end


  if widget.inMember("lytContext", screenPosition) then
    local layoutSize = {0, self.contextMenu.dotsSize[2]}

    for _, btnConfig in ipairs(self.contextMenu.buttonConfigs) do 

      if self.runCallbackForPlugins("contextMenuButtonFilter", btnConfig.name, screenPosition, self.selectedMessage) then
        widget.setPosition("lytContext." .. btnConfig.name, {layoutSize[1], 0})
        widget.setVisible("lytContext." .. btnConfig.name, true)
        layoutSize[1] = layoutSize[1] + btnConfig.size[1]
      end
    end
    widget.setVisible("lytContext.dots", false)

    widget.setSize("lytContext", layoutSize)
  else
    widget.setVisible("lytContext.dots", true)
    for _, btnConfig in ipairs(self.contextMenu.buttonConfigs) do 
      widget.setVisible("lytContext." .. btnConfig.name, false)
    end

    widget.setSize("lytContext", self.contextMenu.dotsSize)
  end

  if self.selectedMessage then
  
    local canvasPosition = widget.getPosition(self.highlightCanvasName)
    local xOffset = canvasPosition[1] + widget.getSize(self.highlightCanvasName)[1] - widget.getSize("lytContext")[1]
    local yOffset = self.selectedMessage.offset + self.selectedMessage.height + canvasPosition[2]
    local newOffset = vec2.add({xOffset, yOffset}, self.customChat.config.contextMenuOffset)

    -- And now we don't want the context menu to fly away somewhere else: we always want to draw it within the canvas
    newOffset[2] = math.min(newOffset[2], self.customChat.canvas:size()[2] + widget.getPosition(self.canvasName)[2] - widget.getSize("lytContext")[2])
    widget.setPosition("lytContext", newOffset)
  end
end

function contextMenuButtonClick(buttonName)
  self.runCallbackForPlugins("contextMenuButtonClick", buttonName, self.selectedMessage)
end