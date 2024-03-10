require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

voicechat = SettingsPluginClass:new(
  { name = "voicechat" }
)


-- Settings
function voicechat:init()
  self:_loadConfig()
end

function voicechat:onLocaleChange()
  widget.setText(self.layoutWidget .. ".openVoiceSettings", starcustomchat.utils.getTranslation("settings.voice_button"))
  widget.setText(self.layoutWidget .. ".lblBindsDesc", starcustomchat.utils.getTranslation("settings.push_to_talk_description"))
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.voicechat"))
end

function voicechat:openVoiceSettings()
  chat.command("/voice")
end