require "/interface/scripted/starcustomchat/plugin.lua"

voicechat = PluginClass:new(
  { name = "voicechat" }
)

function voicechat:init()
  self:_loadConfig()
  local isEnabled = root.getConfiguration("scc_voice_enabled") or false
  widget.setChecked("btnCkVoice", isEnabled)
  voice.setEnabled(isEnabled)
end

function voicechat:onModeToggle(button, isChecked)
  if button == "btnCkVoice" then
    root.setConfiguration("scc_voice_enabled", isChecked)
    voice.setEnabled(isChecked)
  end
end