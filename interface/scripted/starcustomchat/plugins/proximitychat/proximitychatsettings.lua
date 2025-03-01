require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

proximitychat = SettingsPluginClass:new(
  { name = "proximitychat" }
)


-- Settings
function proximitychat:init()
  self:_loadConfig()

  self.proximityRadius = root.getConfiguration("scc_proximity_radius") or self.proximityRadius
  widget.setSliderRange(self.layoutWidget .. ".sldProxRadius", 0, 90, 1)
  widget.setSliderValue(self.layoutWidget .. ".sldProxRadius", self.proximityRadius - 10)
  widget.setText(self.layoutWidget .. ".lblProxRadiusValue", self.proximityRadius)

  widget.setChecked(self.layoutWidget .. ".chkRestrictReceiving", root.getConfiguration("scc_proximity_restricted") or false)
end

function proximitychat:cursorOverride(screenPosition)
  if widget.active(self.layoutWidget) and (widget.inMember(self.layoutWidget .. ".sldProxRadius", screenPosition) 
    or widget.inMember(self.layoutWidget .. ".lblProxRadiusValue", screenPosition) 
    or widget.inMember(self.layoutWidget .. ".lblProxRadiusHint", screenPosition)) then
    
    if player.id() and world.entityPosition(player.id()) then
      starcustomchat.utils.drawCircle(world.entityPosition(player.id()), self.proximityRadius, "green")
    end
  end
end

function proximitychat:updateProxRadius(widgetName)
  self.proximityRadius = widget.getSliderValue(self.layoutWidget .. "." .. widgetName) + 10
  widget.setText(self.layoutWidget .. ".lblProxRadiusValue", self.proximityRadius)
  root.setConfiguration("scc_proximity_radius", self.proximityRadius)
  save()
end

function proximitychat:restrictReceiving()
  root.setConfiguration("scc_proximity_restricted", widget.getChecked(self.layoutWidget .. ".chkRestrictReceiving"))
  save()
end