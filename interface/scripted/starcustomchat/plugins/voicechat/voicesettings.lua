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
end

function voicechat:onLocaleChange()
  widget.setText(self.layoutWidget .. ".btnOpenVoiceSettings", starcustomchat.utils.getTranslation("settings.voice.settings"))
  widget.setText(self.layoutWidget .. ".btnBinds", starcustomchat.utils.getTranslation("settings.voice.binds_button"))
  widget.setText(self.layoutWidget .. ".lblBindsDesc", starcustomchat.utils.getTranslation("settings.voice.binds_label"))
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.voicechat"))
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