require "/interface/scripted/starcustomchat/plugin.lua"

voicechat = PluginClass:new(
  { name = "voicechat" }
)

function voicechat:init()
  self.isOSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")

  self:_loadConfig()
  local isEnabled = root.getConfiguration("scc_voice_enabled") or false
  widget.setChecked("btnCkVoice", isEnabled)

  self:setEnabled(isEnabled)
end

function voicechat:setEnabled(enabled)
  -- Avoid audio stutters by checking and setting voice settings efficiently
  if self.isOSB or xsb then
    local voiceSettings = voice.getSettings()
    voiceSettings["enabled"] = enabled
    voice.mergeSettings(voiceSettings)
  else
    if voice.enabled() ~= enabled then
      voice.setEnabled(enabled)
    end
  end
end


function voicechat:onModeToggle(button, isChecked)
  if button == "btnCkVoice" then
    root.setConfiguration("scc_voice_enabled", isChecked)
    self:setEnabled(isChecked)
  end
end