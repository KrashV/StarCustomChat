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

  self.portraitCanvas = self.widget.bindCanvas("lytBase.portraitCanvas")

  self.customPortraits = player.getProperty("icc_custom_portrait")

  if self.customPortraits then
    if type(self.customPortraits) == "string" then
      self.customPortraits = {customPortraits}
    end
    
    local selectedPortrait = player.getProperty("icc_custom_portrait_selected")
    if selectedPortrait and selectedPortrait == 0 then
      self.customImage = nil
    else
      self.customImage = self.customPortraits[selectedPortrait or #self.customPortraits]
      self.customImageSize = starcustomchat.utils.safeImageSize(self.customImage)
      if not self.customImageSize then
        self.customImage = nil
      end
      self.widget.setVisible("lytBase.btnResetAvatar", false)
    end
  else
    self.customPortraits = {}
  end

  self:drawCharacter()
  
  self.widget.setSliderRange("lytBase.sldFontSize", 0, 4, 1)
  self.widget.setSliderValue("lytBase.sldFontSize", self.fontSize - 6)

  self.maxCharactersStep = 300
  self.widget.setSliderRange("lytBase.sldMessageLength", 0, 10, 1)
  self.widget.setSliderValue("lytBase.sldMessageLength", self.maxCharactersAllowed // self.maxCharactersStep)

  self.widget.setText("lytBase.lblFontSizeValue", self.fontSize)
  self.widget.setText("lytBase.lblMessageLengthValue", self.maxCharactersAllowed)

  self.portraitAnchor = false
  self.timezoneOffset = root.getConfiguration("scc_timezone_offset") or 0

  if os.date then
    self.widget.setVisible("lytBase.spnUTCOffset", false)
    self.widget.setVisible("lytBase.lblUTCOffset", false)
    self.widget.setVisible("lytBase.lblUTCHint", false)
  else
    self.widget.setText("lytBase.lblUTCOffset", self:formatOffset(self.timezoneOffset))
  end

  self.widget.registerMemberCallback("lytPortraitSelection.saSavedPortraits.listPortraits", "removePortrait", function(_, data)
    self:removePortrait(_, data)
  end)  
  self.widget.registerMemberCallback("lytPortraitSelection.saSavedPortraits.listPortraits", "selectPortrait", function(_, data)
    self:selectPortrait(_, data)
  end)
end

function mainchat:onLocaleChange()
  self.widget.setText("lytBase.btnMode", starcustomchat.utils.getTranslation("settings.modes." .. self.chatMode))
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
      if event.type == "MouseWheel" and self.widget.inMember("lytBase.portraitCanvas", screenPosition) then
        self.portraitSettings.scale = util.clamp(self.portraitSettings.scale + event.data.mouseWheel / 2, 2, 4)
        save()
        self:drawCharacter()
      end
    end
  end
end

function mainchat:formatOffset(offset)
    local sign = offset >= 0 and "+" or "-"
    local absOffset = math.abs(offset)
    local hours = math.floor(absOffset)
    local minutes = math.floor((absOffset - hours) * 60)

    return string.format("%s%02d:%02d", sign, hours, minutes)
end

function mainchat:changeMode()
  local i = index(self.availableModes, self.chatMode)
  self.chatMode = self.availableModes[(i % #self.availableModes) + 1]
  root.setConfiguration("sccMode", self.chatMode)
  
  self.widget.setText("lytBase.btnMode", starcustomchat.utils.getTranslation("settings.modes." .. self.chatMode))
  save()
end

function mainchat:save()
  player.setProperty("icc_portrait_settings", {
    offset = self.portraitSettings.offset,
    scale = self.portraitSettings.scale
  })
  if self.customPortraits and #self.customPortraits > 0 then
    player.setProperty("icc_custom_portrait", self.customPortraits)
  else
    player.setProperty("icc_custom_portrait", nil)
  end
end

function mainchat:resetAvatar()
  self.portraitSettings.offset = self.defaultPortraitSettings.offset
  self.portraitSettings.scale = self.defaultPortraitSettings.scale

  self.widget.setText("lytBase.tbxCustomPortrait", "")
  self:drawCharacter()
  save()
end

function mainchat:drawCharacter()
  self.portraitCanvas:clear()

  local canvasPosition = self.widget.getPosition("lytBase.portraitCanvas")
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
    self.portraitCanvas:drawImageRect(self.customImage, {0, 0, self.customImageSize[1], self.customImageSize[2]}, {0, 0, canvasSize[1], canvasSize[2]})
  end
  self.portraitCanvas:drawImageRect(self.frameImage, {0, 0, backImageSize[1], backImageSize[2]}, 
    {0, 0, canvasSize[1], canvasSize[2]})
end

function mainchat:updateFontSize(widgetName)
  self.fontSize = self.widget.getSliderValue("lytBase." .. widgetName) + 6
  self.widget.setText("lytBase.lblFontSizeValue", self.fontSize)
  root.setConfiguration("icc_font_size", self.fontSize)
  save()
end

function mainchat:update()
  self.widget.setVisible("lytBase.btnSetCustomPortrait", self.widget.getText("tbxCustomPortrait") ~= "")
end

function mainchat:updateMessageLength(widgetName)
  self.maxCharactersAllowed = self.widget.getSliderValue("lytBase." .. widgetName) * self.maxCharactersStep
  self.widget.setText("lytBase.lblMessageLengthValue", self.maxCharactersAllowed)
  root.setConfiguration("icc_max_allowed_characters", self.maxCharactersAllowed)
  save()
end

function mainchat:clearHistory()
  world.sendEntityMessage(player.id(), "icc_clear_history")
end

mainchat.utcOffsetSpinner = {}

function mainchat.utcOffsetSpinner.up(self)
  self.timezoneOffset = self.timezoneOffset + 0.5
  self.widget.setText("lytBase.lblUTCOffset", self:formatOffset(self.timezoneOffset))
  root.setConfiguration("scc_timezone_offset", self.timezoneOffset)
  save()
end

function mainchat.utcOffsetSpinner.down(self)
  self.timezoneOffset = self.timezoneOffset - 0.5
  self.widget.setText("lytBase.lblUTCOffset", self:formatOffset(self.timezoneOffset))

  root.setConfiguration("scc_timezone_offset", self.timezoneOffset)
  save()
end



function mainchat:clickCanvasCallback(position, button, isDown)
  if button == 0 then
    self.portraitAnchor = isDown and vec2.sub(position, self.portraitSettings.offset) or nil
    save()
  end
end

function mainchat:setPortrait(widgetName, data)
  local text = self.widget.getText("lytBase.tbxCustomPortrait")
  if text == "" then
    self.customImage = nil
  else
    local imageSize = starcustomchat.utils.safeImageSize("/assetmissing.png" .. text)
    if imageSize then
      if imageSize[1] <= 64 and imageSize[2] <= 64 then
        self.widget.setText("lytBase.tbxCustomPortrait", "")
        self.customImage = "/assetmissing.png" .. text
        self.customImageSize = imageSize

        table.insert(self.customPortraits, self.customImage)
        player.setProperty("icc_custom_portrait_selected", #self.customPortraits)
        self:drawCharacter()
        save()
      else
        self.widget.setText("lytBase.tbxCustomPortrait", "")
        starcustomchat.utils.alert("settings.mainchat.alerts.size_error")
      end
    else
      self.widget.setText("lytBase.tbxCustomPortrait", "")
      starcustomchat.utils.alert("settings.mainchat.alerts.image_error")
    end
  end
end

function mainchat:togglePortraitSelection()

  self.widget.setVisible("lytBase", false)
  self.widget.setVisible("lytPortraitSelection", true)

  self:populatePortraitList()
end

function mainchat:populatePortraitList()
  self.widget.clearListItems("lytPortraitSelection.saSavedPortraits.listPortraits")

  -- Set our portrait as the first item
  local li = self.widget.addListItem("lytPortraitSelection.saSavedPortraits.listPortraits")
  local playerCanvas = self.widget.bindCanvas("lytPortraitSelection.saSavedPortraits.listPortraits." .. li .. ".portrait")
  local portrait = starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(player.id(), "full"))

  local ratio = self.portraitCanvas:size()[1] / playerCanvas:size()[1]
  for _, layer in ipairs(portrait) do
    playerCanvas:drawImage(layer.image, vec2.div(self.portraitSettings.offset, ratio), self.portraitSettings.scale / ratio)
  end

  self.widget.setText("lytPortraitSelection.saSavedPortraits.listPortraits." .. li .. ".name", starcustomchat.utils.getTranslation("settings.mainchat.portraits.default"))
  self.widget.removeChild("lytPortraitSelection.saSavedPortraits.listPortraits." .. li, "btnRemove")


  for i, portrait in ipairs(self.customPortraits or {}) do
    local li = self.widget.addListItem("lytPortraitSelection.saSavedPortraits.listPortraits")
    local playerCanvas = self.widget.bindCanvas("lytPortraitSelection.saSavedPortraits.listPortraits." .. li .. ".portrait")
    playerCanvas:drawImage(portrait, {0, 0}, playerCanvas:size()[1] / root.imageSize(portrait)[1])
    
    self.widget.setData("lytPortraitSelection.saSavedPortraits.listPortraits." .. li, {
      name = portrait.name,
      image = portrait,
      index = i
    })
  end
end

function mainchat:selectPortrait()
  local li = self.widget.getListSelected("lytPortraitSelection.saSavedPortraits.listPortraits")


  if li then
    local data = self.widget.getData("lytPortraitSelection.saSavedPortraits.listPortraits." .. li)
    if data then
      self.customImage = data.image
      self.customImageSize = root.imageSize(data.image)
      self.widget.setVisible("lytBase.btnResetAvatar", false)
      player.setProperty("icc_custom_portrait_selected", data.index)
    else
      self.customImage = nil
      self.widget.setVisible("lytBase.btnResetAvatar", true)
      player.setProperty("icc_custom_portrait_selected", 0)
    end

    self:drawCharacter()
    save()

    for _, pl in ipairs(world.playerQuery(world.entityPosition(player.id()), 100)) do 
      world.sendEntityMessage(pl, "icc_send_player_portrait", {
        portrait = self.customImage or starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(player.id(), "full")),
        type = "UPDATE_PORTRAIT",
        entityId = player.id(),
        connection = player.id() // -65536,
        settings = {
          offset = self.portraitSettings.offset,
          scale =  self.portraitSettings.scale 
        },
        uuid = player.uniqueId()
      })
    end
    


    self.widget.setVisible("lytBase", true)
    self.widget.setVisible("lytPortraitSelection", false)
  end
end


function mainchat:removePortrait()
  local li = self.widget.getListSelected("lytPortraitSelection.saSavedPortraits.listPortraits")

  if li then
    local data = self.widget.getData("lytPortraitSelection.saSavedPortraits.listPortraits." .. li)

    local dialogConfig = {
      paneLayout = "/interface/windowconfig/simpleconfirmation.config:paneLayout",
      title = starcustomchat.utils.getTranslation("settings.stickers.dialogs.remove.title"),
      subtitle = starcustomchat.utils.getTranslation("settings.stickers.dialogs.remove.subtitle"),
      message = starcustomchat.utils.getTranslation("settings.stickers.dialogs.remove.message"),
      okCaption = starcustomchat.utils.getTranslation("settings.stickers.dialogs.remove.ok"),
      cancelCaption = starcustomchat.utils.getTranslation("settings.stickers.dialogs.remove.cancel")
    }

    promises:add(player.confirm(dialogConfig), function(confirmed)
      if confirmed then
        self.widget.removeListItem("lytPortraitSelection.saSavedPortraits.listPortraits", data.index)
        table.remove(self.customPortraits, data.index)
        player.setProperty("icc_custom_portrait_selected", 0)
        save()
      end
    end)
  end
end