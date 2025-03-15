require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

mainchat = SettingsPluginClass:new(
  { name = "mainchat" }
)

function mainchat:init()
  self:_loadConfig()
  self.availableModes = {"compact", "modern"}

  self.chatMode = root.getConfiguration("sccMode") or "modern"

  self.backImage = self.chatConfig.icons.empty
  self.frameImage = self.chatConfig.icons.frame
  self.proximityRadius = self.chatConfig.proximityRadius
  self.defaultPortraitSettings = {
    offset = self.chatConfig.defaultPortraitOffset,
    scale = self.chatConfig.defaultPortraitScale
  }
  self.portraitSettings = player.getProperty("icc_portrait_settings") or self.defaultPortraitSettings

  self.fontSize = root.getConfiguration("icc_font_size") or self.chatConfig.fontSize
  self.maxCharactersAllowed = root.getConfiguration("icc_max_allowed_characters") or 0

  self.portraitCanvas = self.widget.bindCanvas("portraitCanvas")

  self.customImage = player.getProperty("icc_custom_portrait") or nil
  if self.customImage then
    self.customImageSize = starcustomchat.utils.safeImageSize(self.customImage)
    if not self.customImageSize then
      self.customImage = nil
    end
  end

  self:drawCharacter()
  
  self.widget.setSliderRange("sldFontSize", 0, 4, 1)
  self.widget.setSliderValue("sldFontSize", self.fontSize - 6)

  self.maxCharactersStep = 300
  self.widget.setSliderRange("sldMessageLength", 0, 10, 1)
  self.widget.setSliderValue("sldMessageLength", self.maxCharactersAllowed // self.maxCharactersStep)

  self.widget.setText("lblFontSizeValue", self.fontSize)
  self.widget.setText("lblMessageLengthValue", self.maxCharactersAllowed)

  self.portraitAnchor = false

end

function mainchat:onLocaleChange()
  self.widget.setText("btnMode", starcustomchat.utils.getTranslation("settings.modes." .. self.chatMode))
end

function mainchat:cursorOverride(screenPosition)
  if widget.active(self.layoutWidget) and not self.customImage then
    if self.portraitAnchor then
      local currentPos = self.portraitCanvas:mousePosition()
      local diff = vec2.sub(currentPos, self.portraitAnchor)

      -- We believe that both the canvas and the crop area are squares

      self.portraitSettings.offset = {
        util.clamp(math.floor(diff[1]), -180, 180),
        util.clamp(math.floor(diff[2]), -180, 180)
      }
      self:drawCharacter()
    end
    
    for _, event in ipairs(input.events()) do
      if event.type == "MouseWheel" and self.widget.inMember("portraitCanvas", screenPosition) then
        self.portraitSettings.scale = util.clamp(self.portraitSettings.scale + event.data.mouseWheel / 2, 2, 4)
        save()
        self:drawCharacter()
      end
    end
  end
end



function mainchat:changeMode()
  local i = index(self.availableModes, self.chatMode)
  self.chatMode = self.availableModes[(i % #self.availableModes) + 1]
  root.setConfiguration("sccMode", self.chatMode)
  
  self.widget.setText("btnMode", starcustomchat.utils.getTranslation("settings.modes." .. self.chatMode))
  save()
end

function mainchat:save()
  player.setProperty("icc_portrait_settings", {
    offset = self.portraitSettings.offset,
    scale = self.portraitSettings.scale
  })
end

function mainchat:resetAvatar()
  
  self.portraitSettings.offset = self.defaultPortraitSettings.offset
  self.portraitSettings.scale = self.defaultPortraitSettings.scale
  player.setProperty("icc_custom_portrait", nil)
  self.customImage = nil
  self.widget.setText("tbxCustomPortrait", "")
  self:drawCharacter()
  save()
end

function mainchat:drawCharacter()
  self.portraitCanvas:clear()
  local canvasPosition = self.widget.getPosition("portraitCanvas")
  local canvasSize =  self.portraitCanvas:size()
  local backImageSize = root.imageSize(self.backImage)
  self.portraitCanvas:drawImageRect(self.backImage, {0, 0, backImageSize[1], backImageSize[2]}, 
    {0, 0, canvasSize[1], canvasSize[2]})

  if not self.customImage then
    local portrait = starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(player.id(), "full"))

    for _, layer in ipairs(portrait) do
      self.portraitCanvas:drawImage(layer.image, self.portraitSettings.offset, self.portraitSettings.scale)
    end
  else
    self.portraitCanvas:drawImageRect(self.customImage, {0,0,self.customImageSize[1],self.customImageSize[2]}, {0, 0, canvasSize[1], canvasSize[2]})
  end
  self.portraitCanvas:drawImageRect(self.frameImage, {0, 0, backImageSize[1], backImageSize[2]}, 
    {0, 0, canvasSize[1], canvasSize[2]})
end

function mainchat:updateFontSize(widgetName)
  self.fontSize = self.widget.getSliderValue("" .. widgetName) + 6
  self.widget.setText("lblFontSizeValue", self.fontSize)
  root.setConfiguration("icc_font_size", self.fontSize)
  save()
end

function mainchat:updateMessageLength(widgetName)
  self.maxCharactersAllowed = self.widget.getSliderValue("" .. widgetName) * self.maxCharactersStep
  self.widget.setText("lblMessageLengthValue", self.maxCharactersAllowed)
  root.setConfiguration("icc_max_allowed_characters", self.maxCharactersAllowed)
  save()
end

function mainchat:clearHistory()
  world.sendEntityMessage(player.id(), "icc_clear_history")
end

function mainchat:clickCanvasCallback(position, button, isDown)
  if button == 0 then
    self.portraitAnchor = isDown and vec2.sub(position, self.portraitSettings.offset) or nil
    save()
  end
end

function mainchat:setPortrait(widgetName, data)
  local text = self.widget.getText("tbxCustomPortrait")
  if text == "" then
    player.setProperty("icc_custom_portrait", nil)
    self.customImage = nil
  else
    local imageSize = starcustomchat.utils.safeImageSize("/assetmissing.png" .. text)
    if imageSize then
      if imageSize[1] <= 64 and imageSize[2] <= 64 then
        self.widget.setText("tbxCustomPortrait", "")
        self.customImage = "/assetmissing.png" .. text
        self.customImageSize = imageSize
        player.setProperty("icc_custom_portrait", "/assetmissing.png" .. text)
        self:drawCharacter()
      else
        self.widget.setText("tbxCustomPortrait", "")
        starcustomchat.utils.alert("settings.mainchat.alerts.size_error")
      end
    else
      self.widget.setText("tbxCustomPortrait", "")
      starcustomchat.utils.alert("settings.mainchat.alerts.image_error")
    end
  end
end