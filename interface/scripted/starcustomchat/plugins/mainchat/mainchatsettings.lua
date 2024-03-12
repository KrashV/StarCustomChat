require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

mainchat = SettingsPluginClass:new(
  { name = "mainchat" }
)

function mainchat:init()
  self:_loadConfig()

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

  self.portraitCanvas = widget.bindCanvas(self.layoutWidget .. ".portraitCanvas")

  self.customImage = player.getProperty("icc_custom_portrait") or nil
  if self.customImage then
    self.customImageSize = root.imageSize(self.customImage)
  end

  self:drawCharacter()
  
  widget.setSliderRange(self.layoutWidget .. ".sldFontSize", 0, 4, 1)
  widget.setSliderValue(self.layoutWidget .. ".sldFontSize", self.fontSize - 6)

  self.maxCharactersStep = 300
  widget.setSliderRange(self.layoutWidget .. ".sldMessageLength", 0, 10, 1)
  widget.setSliderValue(self.layoutWidget .. ".sldMessageLength", self.maxCharactersAllowed // self.maxCharactersStep)

  widget.setText(self.layoutWidget .. ".lblFontSizeValue", self.fontSize)
  widget.setText(self.layoutWidget .. ".lblMessageLengthValue", self.maxCharactersAllowed)

  self.portraitAnchor = false
end

function mainchat:cursorOverride(screenPosition)
  if widget.active(self.layoutWidget) and not self.customImage then
    if self.portraitAnchor then
      local currentPos = self.portraitCanvas:mousePosition()
      local diff = vec2.sub(currentPos, self.portraitAnchor)

      -- We believe that both the canvas and the crop area are squares

      self.portraitSettings.offset = {
        util.clamp(math.floor(diff[1]), -120, 120),
        util.clamp(math.floor(diff[2]), -120, 120)
      }
      self:drawCharacter()
    end
    
    for _, event in ipairs(input.events()) do
      if event.type == "MouseWheel" and widget.inMember(self.layoutWidget .. ".portraitCanvas", screenPosition) then
        self.portraitSettings.scale = util.clamp(self.portraitSettings.scale + event.data.mouseWheel / 2, 3, 4)
        save()
        self:drawCharacter()
      end
    end
  end
end

function mainchat:save()
  player.setProperty("icc_portrait_settings", {
    offset = self.portraitSettings.offset,
    scale = self.portraitSettings.scale
  })
end

function mainchat:onLocaleChange(localeConfig)
  widget.setText(self.layoutWidget .. ".lblFontSizeHint", starcustomchat.utils.getTranslation("settings.font_size"))
  widget.setText(self.layoutWidget .. ".lblMessageLengthHint", starcustomchat.utils.getTranslation("settings.chat_collapse"))
  widget.setText(self.layoutWidget .. ".btnDeleteChat", starcustomchat.utils.getTranslation("settings.clear_chat_history"))
  widget.setText(self.layoutWidget .. ".btnResetAvatar", starcustomchat.utils.getTranslation("settings.reset_avatar"))
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.mainchat"))
  widget.setText(self.layoutWidget .. ".lblCustomPortrait", starcustomchat.utils.getTranslation("settings.mainchat.customavatar"))
  widget.setText(self.layoutWidget .. ".btnSetCustomPortrait", starcustomchat.utils.getTranslation("settings.mainchat.setportrait"))
end

function mainchat:resetAvatar()
  
  self.portraitSettings.offset = self.defaultPortraitSettings.offset
  self.portraitSettings.scale = self.defaultPortraitSettings.scale
  player.setProperty("icc_custom_portrait", nil)
  self.customImage = nil
  widget.setText(self.layoutWidget .. ".tbxCustomPortrait", "")
  self:drawCharacter()
  save()
end

function mainchat:drawCharacter()
  self.portraitCanvas:clear()
  local canvasPosition = widget.getPosition(self.layoutWidget .. ".portraitCanvas")
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
  self.fontSize = widget.getSliderValue(self.layoutWidget .. "." .. widgetName) + 6
  widget.setText(self.layoutWidget .. ".lblFontSizeValue", self.fontSize)
  root.setConfiguration("icc_font_size", self.fontSize)
  save()
end

function mainchat:updateMessageLength(widgetName)
  self.maxCharactersAllowed = widget.getSliderValue(self.layoutWidget .. "." .. widgetName) * self.maxCharactersStep
  widget.setText(self.layoutWidget .. ".lblMessageLengthValue", self.maxCharactersAllowed)
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
  local text = widget.getText(self.layoutWidget .. ".tbxCustomPortrait")
  if text == "" then
    player.setProperty("icc_custom_portrait", nil)
    self.customImage = nil
  else
    if pcall(function() root.imageSize("/assetmissing.png" .. text) end) then
      local imageSize = root.imageSize("/assetmissing.png" .. text)
      if imageSize[1] <= 64 and imageSize[2] <= 64 then
        widget.setText(self.layoutWidget .. ".tbxCustomPortrait", "")
        self.customImage = "/assetmissing.png" .. text
        self.customImageSize = imageSize
        player.setProperty("icc_custom_portrait", "/assetmissing.png" .. text)
        self:drawCharacter()
      else
        widget.setText(self.layoutWidget .. ".tbxCustomPortrait", "")
        starcustomchat.utils.alert("settings.mainchat.alerts.size_error")
      end
    else
      widget.setText(self.layoutWidget .. ".tbxCustomPortrait", "")
      starcustomchat.utils.alert("settings.mainchat.alerts.image_error")
    end
  end
end