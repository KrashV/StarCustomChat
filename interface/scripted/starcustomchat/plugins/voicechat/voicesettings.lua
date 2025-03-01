require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

voicechat = SettingsPluginClass:new(
  { name = "voicechat" }
)


-- Settings
function voicechat:init()
  self:_loadConfig()

  self.isOSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")
  self.enabled = root.getConfiguration("scc_voice_enabled") or false
  widget.setChecked(self.layoutWidget .. ".chkEnableDefault", self.enabled)

  if self.isOSB then
    widget.setVisible(self.layoutWidget .. ".btnOpenVoiceSettings", false)
    widget.setVisible(self.layoutWidget .. ".btnBinds", false)
    widget.setVisible(self.layoutWidget .. ".lblOpenStarbound", true)
    widget.setVisible(self.layoutWidget .. ".lblStarExtentions", false)
  end
  
end

function voicechat:openVoiceSettings()
  chat.command("/voice")
end

function voicechat:binds()
  chat.command("/binds")
end

function voicechat:uninit()
  if self.isOSB then
    root.setConfiguration("scc_voice_enabled", voice.getSettings()["enabled"])
  else
    root.setConfiguration("scc_voice_enabled", voice.enabled())
  end
end