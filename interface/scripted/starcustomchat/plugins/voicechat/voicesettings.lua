require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

voicechat = SettingsPluginClass:new(
  { name = "voicechat" }
)


-- Settings
function voicechat:init()
  self:_loadConfig()
  self.enabledDefault = root.getConfiguration("scc_voice_enable_by_default") or false
  widget.setChecked(self.layoutWidget .. ".chkEnableDefault", self.enabledDefault)
end

function voicechat:onLocaleChange()
  widget.setText(self.layoutWidget .. ".btnOpenVoiceSettings", starcustomchat.utils.getTranslation("settings.voice.settings"))
  widget.setText(self.layoutWidget .. ".btnBinds", starcustomchat.utils.getTranslation("settings.voice.binds_button"))
  widget.setText(self.layoutWidget .. ".lblBindsDesc", starcustomchat.utils.getTranslation("settings.voice.binds_label"))
  widget.setText(self.layoutWidget .. ".lblEnableDefault", starcustomchat.utils.getTranslation("settings.voice.default_enable"))
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.voicechat"))
end

function voicechat:openVoiceSettings()
  chat.command("/voice")
end

function voicechat:binds()
  chat.command("/binds")
end

function voicechat:setEnabled()
  self.enabledDefault = widget.getChecked(self.layoutWidget .. ".chkEnableDefault")
  root.setConfiguration("scc_voice_enable_by_default", self.enabledDefault)
end