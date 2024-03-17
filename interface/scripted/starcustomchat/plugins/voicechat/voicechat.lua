require "/interface/scripted/starcustomchat/plugin.lua"

voicechat = PluginClass:new(
  { name = "voicechat" }
)

function voicechat:init()
  self:_loadConfig()
  local isEnabled = root.getConfiguration("scc_voice_enabled") or false
  widget.setChecked("btnCkVoice", isEnabled)

  self:setEnabled(isEnabled)
end

function voicechat:setEnabled(enabled)
  -- This code is a little hideous because voice.setEnabled(true) closes the audio device and opens it anew. We don't want stutters in our audio
  if enabled then 
    if not voice.enabled() then
      voice.setEnabled(true)
    end
  else
    voice.setEnabled(false)
  end
end

function voicechat:onModeToggle(button, isChecked)
  if button == "btnCkVoice" then
    root.setConfiguration("scc_voice_enabled", isChecked)
    self:setEnabled(isChecked)
  end
end