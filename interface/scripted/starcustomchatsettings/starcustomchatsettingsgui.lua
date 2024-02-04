require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/interface/scripted/degscustomchat/base/starcustomchatutils.lua"

function init()
  self.cropAreaRestrictions = {17, 23, 24, 30}
  self.sizeRestrictions = {15, 25}

  self.cropArea = config.getParameter("portraitFrame")
  self.defaultCropArea = config.getParameter("defaultCropArea")
  self.backImage = config.getParameter("backImage")
  self.frameImage = config.getParameter("frameImage")
  self.chatMode = config.getParameter("chatMode")
  self.proximityRadius = config.getParameter("proximityRadius")
  self.fontSize = config.getParameter("fontSize")
  self.maxCharactersAllowed = config.getParameter("maxCharactersAllowed")

  self.portraitCanvas = widget.bindCanvas("portraitCanvas")

  self.localePluginConfig = {}
  local plugins = {}

  -- Load plugins
  for i, pluginName in ipairs(config.getParameter("enabledPlugins", {})) do 
    local pluginConfig = root.assetJson(string.format("/interface/scripted/degscustomchat/plugins/%s/%s.json", pluginName, pluginName))

    if pluginConfig.script then
      require(pluginConfig.script)

      local classInstance = _ENV[pluginName]:new()
      table.insert(plugins, classInstance)
    end

    if pluginConfig.localeKeys then
      self.localePluginConfig = sb.jsonMerge(self.localePluginConfig, pluginConfig.localeKeys)
    end
  end

  self.runCallbackForPlugins = function(method, ...)
    -- The logic here is actually strange and might need some more customisation
    local result = nil
    for _, plugin in ipairs(plugins) do 
      result = plugin[method](plugin, ...)
    end
    return result
  end


  localeSettings(self.localePluginConfig)
  self.runCallbackForPlugins("settings_init", starcustomchat.locale)
  
  drawCharacter()
  self.availableLocales = root.assetJson("/interface/scripted/degscustomchat/languages/locales.json")
  self.availableModes = {"compact", "modern"}

  
  widget.setSliderRange("sldFontSize", 0, 4, 1)
  widget.setSliderValue("sldFontSize", self.fontSize - 6)

  self.maxCharactersStep = 300
  widget.setSliderRange("sldMessageLength", 0, 10, 1)
  widget.setSliderValue("sldMessageLength", self.maxCharactersAllowed // self.maxCharactersStep)

  widget.setText("lblFontSizeValue", self.fontSize)
  widget.setText("lblMessageLengthValue", self.maxCharactersAllowed)

end

function localeSettings(localePluginConfig)
  starcustomchat.utils.buildLocale(localePluginConfig)
  pane.setTitle(starcustomchat.utils.getTranslation("settings.title"), starcustomchat.utils.getTranslation("settings.subtitle"))
  widget.setText("btnLanguage", starcustomchat.utils.getTranslation("name"))
  widget.setData("btnLanguage", starcustomchat.currentLocale)
  widget.setText("btnMode", starcustomchat.utils.getTranslation("settings.modes." .. self.chatMode))
  widget.setData("btnMode", self.chatMode)
  widget.setText("lblFontSizeHint", starcustomchat.utils.getTranslation("settings.font_size"))
  widget.setText("lblMessageLengthHint", starcustomchat.utils.getTranslation("settings.chat_collapse"))
  widget.setText("btnDeleteChat", starcustomchat.utils.getTranslation("settings.clear_chat_history"))
  widget.setText("btnResetAvatar", starcustomchat.utils.getTranslation("settings.reset_avatar"))
end

function resetAvatar()
  self.cropArea = copy(self.defaultCropArea)
  drawCharacter()
  save()
end

function drawCharacter()
  self.portraitCanvas:clear()
  local canvasPosition = widget.getPosition("portraitCanvas")
  local canvasSize =  self.portraitCanvas:size()
  local backImageSize = root.imageSize(self.backImage)
  self.portraitCanvas:drawImageRect(self.backImage, {0, 0, backImageSize[1], backImageSize[2]}, 
    {0, 0, canvasSize[1], canvasSize[2]})

  local portrait = world.entityPortrait(player.id(), "bust")
  for _, layer in ipairs(portrait) do
    self.portraitCanvas:drawImageRect(layer.image, self.cropArea, {0, 0, canvasSize[1], canvasSize[2]})
  end
  self.portraitCanvas:drawImageRect(self.frameImage, {0, 0, backImageSize[1], backImageSize[2]}, 
    {0, 0, canvasSize[1], canvasSize[2]})
end

function movePortrait(btn, direction)
  if self.cropArea[1] + direction[1] > self.cropAreaRestrictions[1] or self.cropArea[3] + direction[1] < self.cropAreaRestrictions[3] 
  or self.cropArea[2] + direction[2] > self.cropAreaRestrictions[2] or self.cropArea[4] + direction[2] < self.cropAreaRestrictions[4] then
    return
  end

  self.cropArea[1] = self.cropArea[1] + direction[1]
  self.cropArea[2] = self.cropArea[2] + direction[2]
  self.cropArea[3] = self.cropArea[3] + direction[1]
  self.cropArea[4] = self.cropArea[4] + direction[2]
  drawCharacter()

  save()
end

function zoom(btn, zoom)
  local newDiff = self.cropArea[3] - zoom - self.cropArea[1] - zoom
  if newDiff < self.sizeRestrictions[1] or newDiff > self.sizeRestrictions[2] then
    return
  end
  self.cropArea[1] = self.cropArea[1] + zoom
  self.cropArea[2] = self.cropArea[2] + zoom
  self.cropArea[3] = self.cropArea[3] - zoom
  self.cropArea[4] = self.cropArea[4] - zoom
  drawCharacter()

  save()
end

function changeLanguage()
  local currentLocale = widget.getData("btnLanguage")
  local i = index(self.availableLocales, currentLocale)
  local locale = self.availableLocales[(i % #self.availableLocales) + 1]
  root.setConfiguration("iccLocale", locale)
  localeSettings(self.localePluginConfig)

  save()
end


function changeMode()
  local currentMode = widget.getData("btnMode")
  local i = index(self.availableModes, currentMode)
  self.chatMode = self.availableModes[(i % #self.availableModes) + 1]
  localeSettings(self.localePluginConfig)

  save()
end

function updateFontSize(widgetName)
  self.fontSize = widget.getSliderValue(widgetName) + 6
  widget.setText("lblFontSizeValue", self.fontSize)
  save()
end

function updateMessageLength(widgetName)
  self.maxCharactersAllowed = widget.getSliderValue(widgetName) * self.maxCharactersStep
  widget.setText("lblMessageLengthValue", self.maxCharactersAllowed)
  save()
end

function clearHistory()
  world.sendEntityMessage(player.id(), "icc_clear_history")
end

-- Utility function: return the index of a value in the given array
function index(tab, value)
  for k, v in ipairs(tab) do
    if v == value then return k end
  end
  return 0
end

function save()
  root.setConfiguration("iccMode", widget.getData("btnMode"))
  root.setConfiguration("icc_font_size", self.fontSize)
  root.setConfiguration("icc_max_allowed_characters", self.maxCharactersAllowed)
  player.setProperty("icc_portrait_frame",  self.cropArea)

  world.sendEntityMessage(player.id(), "icc_reset_settings")
  self.runCallbackForPlugins("settings_onSave", starcustomchat.locale)
end

function ok()
  save()
  pane.dismiss()
end

function cancel()
  pane.dismiss()
end


function update()

end

function cursorOverride(screenPosition)
  self.runCallbackForPlugins("settings_onCursorOverride", screenPosition)
end