require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

sounds = SettingsPluginClass:new(
  { name = "sounds" }
)


-- Settings
function sounds:init()
  self:_loadConfig()

  local allRaceSounds = root.assetJson("/npcs/base.npctype")["scriptConfig"]["chatSounds"]
  local currentRaceSounds = allRaceSounds[player.species()] or allRaceSounds["human"]

  self.soundsPool = currentRaceSounds[player.gender()] 

  self.soundsEnabled = root.getConfiguration("scc_sounds_enabled") or false
  widget.setChecked(self.layoutWidget .. ".chkEnabled", self.soundsEnabled or false)

  self.soundPitch = (player.getProperty("scc_sound_pitch") or 1)
  widget.setSliderRange(self.layoutWidget .. ".sldSoundPitch", 4, 20, 2)
  widget.setSliderValue(self.layoutWidget .. ".sldSoundPitch", self.soundPitch * 10)
end

function sounds:onLocaleChange()
  widget.setText(self.layoutWidget .. ".lblSoundsDescription", starcustomchat.utils.getTranslation("settings.plugins.sounds.description"))
  widget.setText(self.layoutWidget .. ".lblSoundsEnabled", starcustomchat.utils.getTranslation("settings.plugins.sounds.enable"))
  widget.setText(self.layoutWidget .. ".lblSoundPitch", starcustomchat.utils.getTranslation("settings.plugins.sounds.pitch"))
  widget.setText(self.layoutWidget .. ".btnPlay", starcustomchat.utils.getTranslation("settings.plugins.sounds.test"))
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.sounds"))
end

function sounds:enableSounds()
  self.soundsEnabled = widget.getChecked(self.layoutWidget .. ".chkEnabled")
  root.setConfiguration("scc_sounds_enabled", self.soundsEnabled)
  save()
end

function sounds:playSound()
  local soundTable = {
    pool = self.soundsPool,
    pitch = self.soundPitch
  }
  shared.sccTalkingSound(soundTable)
end

function sounds:setTalkingPitch()
  self.soundPitch = widget.getSliderValue(self.layoutWidget .. ".sldSoundPitch") / 10
  player.setProperty("scc_sound_pitch", self.soundPitch)
  save()
end