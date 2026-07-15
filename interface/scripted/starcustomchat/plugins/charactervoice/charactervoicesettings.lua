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
  
  self.soundVolume = (player.getProperty("scc_sound_volume") or 1)
  self.widget.setSliderRange("sldVolumePitch", 0, 14, 2)
  self.widget.setSliderValue("sldVolumePitch", self.soundVolume * 10)
end

function charactervoice:openTab()
  local soundList = root.assetsByExtension(".ogg")
  self.combobox = self:createCombobox(soundList)
  self:populateScrollArea(self.allRaceSounds, self.selectedSpecies)

  local sound = player.getProperty("scc_charactervoice_custom") or ""
  self.widget.setText("btnCustomSound", sound:match("([^/]+)$"))
end

function charactervoice:createCombobox(soundList)
  return Combobox:bind(self.layoutWidget .. "." .. "btnCustomSound", soundList, function(data)
    self:saveCustomSound(data)
  end, {
    filter = true,
    background = "/interface/scripted/starcustomchatsettings/images/combobox/large/backgroundFilter.png",
    listSchema = {
      listSelected = "/interface/scripted/starcustomchatsettings/images/combobox/large/listselected.png",
      listUnselected = "/interface/scripted/starcustomchatsettings/images/combobox/large/listunselected.png"
    },
    offset = {-50, 15},
    closeOnSelect = true,
    sortKeys = true
  })
end

function charactervoice:openCombobox()
  self.combobox:toggle()
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
      self.widget.setVisible("btnCustomSound", true)
    else
      self.widget.setVisible("btnCustomSound", false)
      self.soundsPool = self.allRaceSounds[newSpecies][player.gender()]
    end
    
    save()
  end
end

function charactervoice:saveCustomSound(data)
  local customSound = data
  if customSound and customSound ~= "" then
    self.widget.setText("btnCustomSound", data:match("([^/]+)$"))
    if root.assetOrigin(customSound) then
      player.setProperty("scc_charactervoice_custom", customSound)
      self.soundsPool = {customSound}
      self:playSound()
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
    volume = self.soundVolume,
    cutoffTime = self.cutoffTime
  }

  world.sendEntityMessage(player.id(), "sccTalkingSound", soundTable)
end

function charactervoice:setTalkingPitch()
  self.soundPitch = math.max(self.widget.getSliderValue("sldSoundPitch") / 10, 0.4)
  self.widget.setSliderValue("sldSoundPitch", self.soundPitch * 10)
  player.setProperty("scc_sound_pitch", self.soundPitch)
  save()
end

function charactervoice:setTalkingVolume()
  self.soundVolume = math.max(self.widget.getSliderValue("sldVolumePitch") / 10, 0.1)
  self.widget.setSliderValue("sldVolumePitch", self.soundVolume * 10)
  player.setProperty("scc_sound_volume", self.soundVolume)
  save()
end

function charactervoice:uninit()
  if self.combobox then
    self.combobox:destroy()
    self.combobox = nil
  end
  if self.soundsPool[1] then
    pane.stopAllSounds(self.soundsPool[1])
  end
end