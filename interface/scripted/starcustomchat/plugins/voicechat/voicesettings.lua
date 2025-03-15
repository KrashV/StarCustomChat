require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

voicechat = SettingsPluginClass:new(
  { name = "voicechat" }
)


-- Settings
function voicechat:init()
  self:_loadConfig()

  self.isOpenSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")
  self.isOSBXSB = self.isOpenSB or xsb

  self.enabled = root.getConfiguration("scc_voice_enabled") or false
  widget.setChecked(self.layoutWidget .. ".chkEnableDefault", self.enabled)
end

function voicechat:isAvailable()
  return not (root.assetOrigin and root.assetOrigin("/opensb/coconut.png") or xsb)
end

function voicechat:openVoiceSettings()
  chat.command("/voice")
end

function voicechat:binds()
  chat.command("/binds")
end

function voicechat:uninit()
  if self.isOSBXSB then
    root.setConfiguration("scc_voice_enabled", voice.getSettings()["enabled"])
  else
    root.setConfiguration("scc_voice_enabled", voice.enabled())
  end
end