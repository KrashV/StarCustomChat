require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/util.lua"

function init()
  self.cropArea = config.getParameter("portraitFrame")
  self.defaultCropArea = config.getParameter("defaultCropArea")
  self.backImage = config.getParameter("backImage")
  self.frameImage = config.getParameter("frameImage")
  self.locale = config.getParameter("locale")
  self.chatMode = config.getParameter("chatMode")
  self.proximityRadius = config.getParameter("proximityRadius")
  self.fontSize = config.getParameter("fontSize")

  self.portraitCanvas = widget.bindCanvas("portraitCanvas")
  localeSettings(self.locale)
  drawCharacter()
  self.availableLocales = root.assetJson("/interface/scripted/irdencustomchat/languages/locales.json")
  self.availableModes = {"compact", "modern"}

  widget.setSliderRange("sldProxRadius", 0, 90, 1)
  widget.setSliderValue("sldProxRadius", self.proximityRadius - 10)

  
  widget.setSliderRange("sldFontSize", 0, 5, 1)
  widget.setSliderValue("sldFontSize", self.fontSize - 5)

  
  widget.setText("lblFontSizeValue", self.fontSize)
  widget.setText("lblProxRadiusValue", self.proximityRadius)
end

function localeSettings(locale)
  local localeConfig = root.assetJson(string.format("/interface/scripted/irdencustomchat/languages/%s.json", locale or "en"))

  pane.setTitle(localeConfig["settings.title"], localeConfig["settings.subtitle"])
  widget.setText("btnLanguage", localeConfig["name"])
  widget.setData("btnLanguage", locale)
  widget.setText("btnMode", localeConfig["settings.modes." .. self.chatMode])
  widget.setData("btnMode", self.chatMode)
  widget.setText("ok", localeConfig["settings.ok"])
  widget.setText("cancel", localeConfig["settings.cancel"])
  widget.setText("lblCornersHint", localeConfig["settings.corners_hint"])
  widget.setText("lblProxRadiusHint", localeConfig["settings.prox_radius"])
  widget.setText("lblFontSizeHint", localeConfig["settings.font_size"])
  widget.setText("btnDeleteChat", localeConfig["settings.clear_chat_history"])
  widget.setText("btnResetAvatar", localeConfig["settings.reset_avatar"])
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

function moveCorner(btn, direction)
  self.cropArea[1] = self.cropArea[1] + direction[1]
  self.cropArea[2] = self.cropArea[2] + direction[2]
  self.cropArea[3] = self.cropArea[3] + direction[1]
  self.cropArea[4] = self.cropArea[4] + direction[2]
  drawCharacter()

  save()
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

function updateProxRadius(widgetName)
  self.proximityRadius = widget.getSliderValue(""..widgetName) + 10
  widget.setText("lblProxRadiusValue", self.proximityRadius)
  save()
end

function updateFontSize(widgetName)
  self.fontSize = widget.getSliderValue(widgetName) + 5
  widget.setText("lblFontSizeValue", self.fontSize)
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
  root.setConfiguration("iccLocale", widget.getData("btnLanguage"))
  root.setConfiguration("iccMode", widget.getData("btnMode"))
  root.setConfiguration("icc_proximity_radius", self.proximityRadius)
  root.setConfiguration("icc_font_size", self.fontSize)
  player.setProperty("icc_portrait_frame",  self.cropArea)

  world.sendEntityMessage(player.id(), "icc_reset_settings")
end

function ok()
  save()
  pane.dismiss()
end

function cancel()
  pane.dismiss()
end


function update()
  local nPoints = 100
	local points = {}
	
  if player.id() and world.entityPosition(player.id()) then
    for i = 1, nPoints do
      local angle = math.pi / 2 + 2 * math.pi * i / nPoints;
      table.insert(points, vec2.add(world.entityPosition(player.id()), vec2.rotate({self.proximityRadius, 0}, angle)))
    end
    world.debugPoly(points, "blue")
  end
end