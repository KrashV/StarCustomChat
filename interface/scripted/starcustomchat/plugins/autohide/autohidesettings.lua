require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

autohide = SettingsPluginClass:new(
  { name = "autohide" }
)


-- Settings
function autohide:init()
  self:_loadConfig()

  self.autohideTimer = root.getConfiguration("scc_autohide_timer") or 0
  widget.setText(self.layoutWidget .. ".lblAutohideTimer", self.autohideTimer)
  widget.setData(self.layoutWidget .. ".lblAutohideTimer", self.autohideTimer)

  widget.setData(self.layoutWidget .. ".autohideTimerSpinner.up", widget.getData(self.layoutWidget .. ".autohideTimerSpinner"))
  widget.setData(self.layoutWidget .. ".autohideTimerSpinner.down", widget.getData(self.layoutWidget .. ".autohideTimerSpinner"))
  widget.setChecked(self.layoutWidget .. ".chkIgnoreServerMessages", root.getConfiguration("scc_autohide_ignore_server_messages") or false)
  widget.setChecked(self.layoutWidget .. ".chkIgnoreInspectMessages", root.getConfiguration("scc_autohide_ignore_inspect_messages") or false)
  
  self.isOpenSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")

  if not self.isOpenSB then
    widget.setVisible(self.layoutWidget .. ".chkIgnoreInspectMessages", false)
    widget.setVisible(self.layoutWidget .. ".lblIgnoreInspectMessages", false)
  end
end

function autohide:onLocaleChange()
  widget.setText(self.layoutWidget .. ".lblAutohide", starcustomchat.utils.getTranslation("settings.autohide.after"))
  widget.setText(self.layoutWidget .. ".lblAutohideTimerMin", starcustomchat.utils.getTranslation("settings.autohide.sec"))
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.autohide"))
  widget.setText(self.layoutWidget .. ".lblAutohide0Warning", starcustomchat.utils.getTranslation("settings.autohide.description"))
  widget.setText(self.layoutWidget .. ".lblIgnoreServerMessages", starcustomchat.utils.getTranslation("settings.autohide.ignore_server_messages"))
  widget.setText(self.layoutWidget .. ".lblIgnoreInspectMessages", starcustomchat.utils.getTranslation("settings.autohide.ignore_inspect_messages"))
end

autohide.autohideTimerSpinner = {}

function autohide.autohideTimerSpinner.up(self)
  local secs = tonumber(widget.getData(self.layoutWidget .. ".lblAutohideTimer")) or 0
  secs = math.min(secs + 5, 90)
  widget.setText(self.layoutWidget .. ".lblAutohideTimer", secs)
  widget.setData(self.layoutWidget .. ".lblAutohideTimer", secs)
  root.setConfiguration("scc_autohide_timer", tonumber(widget.getData(self.layoutWidget .. ".lblAutohideTimer")) or 0)
  save()
end

function autohide.autohideTimerSpinner.down(self)
  local secs = tonumber(widget.getData(self.layoutWidget .. ".lblAutohideTimer")) or 0
  secs = math.max(secs - 5, 0)
  widget.setText(self.layoutWidget .. ".lblAutohideTimer", secs)
  widget.setData(self.layoutWidget .. ".lblAutohideTimer", secs)
  root.setConfiguration("scc_autohide_timer", tonumber(widget.getData(self.layoutWidget .. ".lblAutohideTimer")) or 0)
  save()
end

function autohide:setIgnoreMessages()
  root.setConfiguration("scc_autohide_ignore_server_messages", widget.getChecked(self.layoutWidget .. ".chkIgnoreServerMessages"))
  root.setConfiguration("scc_autohide_ignore_inspect_messages", widget.getChecked(self.layoutWidget .. ".chkIgnoreInspectMessages"))
  save()
end