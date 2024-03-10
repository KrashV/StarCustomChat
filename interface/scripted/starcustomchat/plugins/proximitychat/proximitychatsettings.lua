require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

proximitychat = SettingsPluginClass:new(
  { name = "proximitychat" }
)


-- Settings
function proximitychat:init()
  self:_loadConfig()

  self.proximityRadius = root.getConfiguration("icc_proximity_radius") or self.proximityRadius
  widget.setSliderRange(self.layoutWidget .. ".sldProxRadius", 0, 90, 1)
  widget.setSliderValue(self.layoutWidget .. ".sldProxRadius", self.proximityRadius - 10)
  widget.setText(self.layoutWidget .. ".lblProxRadiusValue", self.proximityRadius)
end

function proximitychat:onLocaleChange()
  widget.setText(self.layoutWidget .. ".lblProxRadiusHint", starcustomchat.utils.getTranslation("settings.prox_radius"))
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.proximitychat"))
end

function proximitychat:cursorOverride(screenPosition)
  if widget.active(self.layoutWidget) and (widget.inMember(self.layoutWidget .. ".sldProxRadius", screenPosition) 
    or widget.inMember(self.layoutWidget .. ".lblProxRadiusValue", screenPosition) 
    or widget.inMember(self.layoutWidget .. ".lblProxRadiusHint", screenPosition)) then
    
    if player.id() and world.entityPosition(player.id()) then
      drawCircle(world.entityPosition(player.id()), self.proximityRadius, "green")
    end
  end
end

function proximitychat:updateProxRadius(widgetName)
  self.proximityRadius = widget.getSliderValue(self.layoutWidget .. "." .. widgetName) + 10
  widget.setText(self.layoutWidget .. ".lblProxRadiusValue", self.proximityRadius)
  root.setConfiguration("icc_proximity_radius", self.proximityRadius)
  save()
end

function drawCircle(center, radius, color, sections)
  sections = sections or 20
  for i = 1, sections do
    local startAngle = math.pi * 2 / sections * (i-1)
    local endAngle = math.pi * 2 / sections * i
    local startLine = vec2.add(center, {radius * math.cos(startAngle), radius * math.sin(startAngle)})
    local endLine = vec2.add(center, {radius * math.cos(endAngle), radius * math.sin(endAngle)})
    interface.drawDrawable({
      line = {camera.worldToScreen(startLine), camera.worldToScreen(endLine)},
      width = 1,
      color = color
    }, {0, 0}, 1, color)
  end
end