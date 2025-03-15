require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

sounds = SettingsPluginClass:new(
  { name = "sounds" }
)


-- Settings
function sounds:init()
  self:_loadConfig()

  self.selectedSpecies = player.getProperty("scc_sound_species") or player.species()
  self.allRaceSounds = root.assetJson("/npcs/base.npctype")["scriptConfig"]["chatSounds"]
  self.selectedSpecies = self.allRaceSounds[self.selectedSpecies] and self.selectedSpecies or "human"

  local currentRaceSounds = self.allRaceSounds[self.selectedSpecies]

  self.soundsPool = currentRaceSounds[player.gender()] 

  self.soundsEnabled = player.getProperty("scc_sounds_enabled") or false
  self.widget.setChecked("chkEnabled", self.soundsEnabled or false)

  self.soundsWhispersEnabled = player.getProperty("scc_sounds_whisper_enabled") or false
  self.widget.setChecked("chkEnabledWhisper", self.soundsWhispersEnabled or false)

  self.soundPitch = (player.getProperty("scc_sound_pitch") or 1)
  self.widget.setSliderRange("sldSoundPitch", 0, 20, 2)
  self.widget.setSliderValue("sldSoundPitch", self.soundPitch * 10)

  self:populateScrollArea(self.allRaceSounds, self.selectedSpecies)
end

function sounds:populateScrollArea(allRaceSounds, selectedSpecies)
  self.widget.clearListItems("saSpecies.listItems")

  for speciesName, _ in pairs(allRaceSounds) do
    local li = self.widget.addListItem("saSpecies.listItems")
    self.widget.setText("saSpecies.listItems." .. li .. ".name", speciesName)
    self.widget.setData("saSpecies.listItems." .. li, speciesName)
    if speciesName == selectedSpecies then
      self.widget.setListSelected("saSpecies.listItems", li)
    end
  end
end

function sounds:changeSpecies()
  local li = self.widget.getListSelected("saSpecies.listItems") 
  if li then
    local newSpecies = self.widget.getData("saSpecies.listItems." .. li)
    player.setProperty("scc_sound_species", newSpecies)
    self.soundsPool = self.allRaceSounds[newSpecies][player.gender()]
    save()
  end
end

function sounds:enableSounds()
  self.soundsEnabled = self.widget.getChecked("chkEnabled")
  player.setProperty("scc_sounds_enabled", self.soundsEnabled)
  save()
end

function sounds:enableWhisperSounds()
  self.soundsWhispersEnabled = self.widget.getChecked("chkEnabledWhisper")
  player.setProperty("scc_sounds_whisper_enabled", self.soundsWhispersEnabled)
  save()
end

function sounds:playSound()
  local soundTable = {
    pool = self.soundsPool,
    pitch = self.soundPitch,
    volume = 1.3
  }

  world.sendEntityMessage(player.id(), "sccTalkingSound", soundTable)
end

function sounds:setTalkingPitch()
  self.soundPitch = math.max(self.widget.getSliderValue("sldSoundPitch") / 10, 0.4)
  self.widget.setSliderValue("sldSoundPitch", self.soundPitch * 10)
  player.setProperty("scc_sound_pitch", self.soundPitch)
  save()
end