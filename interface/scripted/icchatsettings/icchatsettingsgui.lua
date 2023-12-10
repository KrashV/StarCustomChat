function init()
  self.cropArea = config.getParameter("portraitFrame")
  self.backImage = config.getParameter("backImage")
  self.frameImage = config.getParameter("frameImage")
  self.locale = config.getParameter("locale")
  self.chatMode = config.getParameter("chatMode")
  
  self.portraitCanvas = widget.bindCanvas("portraitCanvas")
  localeSettings(self.locale)
  drawCharacter()
  self.availableLocales = root.assetJson("/interface/scripted/irdencustomchat/languages/locales.json")
  self.availableModes = {"compact", "full"}
  setCoordinates()
end

function localeSettings(locale)
  local localeConfig = root.assetJson(string.format("/interface/scripted/irdencustomchat/languages/%s.json", locale or "en"))

  pane.setTitle(localeConfig["settings.title"], localeConfig["settings.subtitle"])
  widget.setText("btnLanguage", locale)
  widget.setData("btnLanguage", locale)
  widget.setText("btnMode", localeConfig["settings.modes." .. self.chatMode])
  widget.setData("btnMode", self.chatMode)
  widget.setText("ok", localeConfig["settings.ok"])
  widget.setText("cancel", localeConfig["settings.cancel"])
  widget.setText("lblCrop", localeConfig["settings.crop_area"])
  widget.setText("lblLanguage", localeConfig["settings.locale"])
  widget.setText("lblMode", localeConfig["settings.chat_mode"])
  widget.setText("lblCornersHint", localeConfig["settings.corners_hint"])
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

function setCoordinates()
  widget.setText("xPosition", "X: " .. self.cropArea[widget.getSelectedOption("rgAvatarCorners")])
  widget.setText("yPosition", "Y: " .. self.cropArea[widget.getSelectedOption("rgAvatarCorners") + 1])
end

function moveCorner(btn, direction)
  self.cropArea[widget.getSelectedOption("rgAvatarCorners")] = self.cropArea[widget.getSelectedOption("rgAvatarCorners")] + direction[1]
  self.cropArea[widget.getSelectedOption("rgAvatarCorners") + 1] = self.cropArea[widget.getSelectedOption("rgAvatarCorners") + 1] + direction[2]
  setCoordinates()
  drawCharacter()
end

function changeCorner()
  setCoordinates()
end

function changeLanguage()
  local currentLocale = widget.getData("btnLanguage")
  local i = index(self.availableLocales, currentLocale)
  self.locale = self.availableLocales[(i % #self.availableLocales) + 1]
  localeSettings(self.locale)

  save()
end


function changeMode()
  local currentMode = widget.getData("btnMode")
  local i = index(self.availableModes, currentMode)
  self.chatMode = self.availableModes[(i % #self.availableModes) + 1]
  localeSettings(self.locale)

  save()
end

-- Utility function: return the index of a value in the given array
function index(tab, value)
  for k, v in ipairs(tab) do
    if v == value then return k end
  end
  return 0
end

function save()
  root.setConfiguration("iccLocale", widget.getData("btnLanguage"))
  root.setConfiguration("iccMode", widget.getData("btnMode"))
  player.setProperty("icc_portrait_frame",  self.cropArea)

  world.sendEntityMessage(player.id(), "icc_resetSettings")
end

function ok()
  save()
  pane.dismiss()
end

function cancel()
  pane.dismiss()
end