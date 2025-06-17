require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

charactervoice = SettingsPluginClass:new(
  { name = "charactervoice" }
)


-- Settings
function charactervoice:init()
  self:_loadConfig()

  self.selectedSpecies = player.getProperty("scc_sound_species") or player.species()
  self.allRaceSounds = root.assetJson("/npcs/base.npctype")["scriptConfig"]["chatSounds"]

  if self.selectedSpecies ~= "custom" then
    self.selectedSpecies = self.allRaceSounds[self.selectedSpecies] and self.selectedSpecies or "human"

    local currentRaceSounds = self.allRaceSounds[self.selectedSpecies]

    self.soundsPool = currentRaceSounds[player.gender()] 
  else
    self.soundsPool = player.getProperty("scc_charactervoice_custom") and {player.getProperty("scc_charactervoice_custom")} or self.allRaceSounds["human"][player.gender()]
  end

  self.soundsEnabled = player.getProperty("scc_sounds_enabled") or false
  self.widget.setChecked("chkEnabled", self.soundsEnabled or false)

  self.soundsWhispersEnabled = player.getProperty("scc_sounds_whisper_enabled") or false
  self.widget.setChecked("chkEnabledWhisper", self.soundsWhispersEnabled or false)

  self.soundPitch = (player.getProperty("scc_sound_pitch") or 1)
  self.widget.setSliderRange("sldSoundPitch", 0, 20, 2)
  self.widget.setSliderValue("sldSoundPitch", self.soundPitch * 10)
  self.widget.setText("tbxCustomSound", player.getProperty("scc_charactervoice_custom") or "")
end

function charactervoice:openTab()
  self:populateScrollArea(self.allRaceSounds, self.selectedSpecies)
end

function charactervoice:populateScrollArea(allRaceSounds, selectedSpecies)
  self.widget.clearListItems("saSpecies.listItems")

  for speciesName, _ in pairs(allRaceSounds) do
    local li = self.widget.addListItem("saSpecies.listItems")
    self.widget.setText("saSpecies.listItems." .. li .. ".name", speciesName)
    self.widget.setData("saSpecies.listItems." .. li, speciesName)
    if speciesName == selectedSpecies then
      self.widget.setListSelected("saSpecies.listItems", li)
    end
  end

-- Add custom option
  local li = self.widget.addListItem("saSpecies.listItems")
  self.widget.setText("saSpecies.listItems." .. li .. ".name", starcustomchat.utils.getTranslation("settings.plugins.charactervoice.customItem"))
  self.widget.setData("saSpecies.listItems." .. li, "custom")
  if selectedSpecies == "custom" then
    self.widget.setListSelected("saSpecies.listItems", li)
  end
end

function charactervoice:changeSpecies()
  local li = self.widget.getListSelected("saSpecies.listItems") 
  if li then
    local newSpecies = self.widget.getData("saSpecies.listItems." .. li)
    player.setProperty("scc_sound_species", newSpecies)
    if newSpecies == "custom" then
      self.widget.setVisible("tbxCustomSound", true)
    else
      self.widget.setVisible("tbxCustomSound", false)
      self.soundsPool = self.allRaceSounds[newSpecies][player.gender()]
    end
    
    save()
  end
end

function charactervoice:saveCustomSound()
  local customSound = self.widget.getText("tbxCustomSound")
  if customSound and customSound ~= "" then
    if root.assetOrigin(customSound) then
      pane.playSound(customSound)
      player.setProperty("scc_charactervoice_custom", customSound)
      self.soundsPool = {customSound}
      save()
    else
      starcustomchat.utils.alert("settings.plugins.charactervoice.soundNotFound")
    end
  end
end

function charactervoice:enableCharacterVoice()
  self.soundsEnabled = self.widget.getChecked("chkEnabled")
  player.setProperty("scc_sounds_enabled", self.soundsEnabled)
  save()
end

function charactervoice:enableWhisperSounds()
  self.soundsWhispersEnabled = self.widget.getChecked("chkEnabledWhisper")
  player.setProperty("scc_sounds_whisper_enabled", self.soundsWhispersEnabled)
  save()
end

function charactervoice:playSound()
  local soundTable = {
    pool = self.soundsPool,
    pitch = self.soundPitch,
    volume = 1.3
  }

  world.sendEntityMessage(player.id(), "sccTalkingSound", soundTable)
end

function charactervoice:setTalkingPitch()
  self.soundPitch = math.max(self.widget.getSliderValue("sldSoundPitch") / 10, 0.4)
  self.widget.setSliderValue("sldSoundPitch", self.soundPitch * 10)
  player.setProperty("scc_sound_pitch", self.soundPitch)
  save()
end