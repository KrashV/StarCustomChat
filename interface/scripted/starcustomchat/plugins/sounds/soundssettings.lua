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

  self.selectedSpecies = player.getProperty("scc_sound_species") or player.species()
  self.allRaceSounds = root.assetJson("/npcs/base.npctype")["scriptConfig"]["chatSounds"]
  self.selectedSpecies = self.allRaceSounds[self.selectedSpecies] and self.selectedSpecies or "human"

  local currentRaceSounds = self.allRaceSounds[self.selectedSpecies]

  self.soundsPool = currentRaceSounds[player.gender()] 

  self.soundsEnabled = player.getProperty("scc_sounds_enabled") or false
  widget.setChecked(self.layoutWidget .. ".chkEnabled", self.soundsEnabled or false)

  self.soundsWhispersEnabled = player.getProperty("scc_sounds_whisper_enabled") or false
  widget.setChecked(self.layoutWidget .. ".chkEnabledWhisper", self.soundsWhispersEnabled or false)

  self.soundPitch = (player.getProperty("scc_sound_pitch") or 1)
  widget.setSliderRange(self.layoutWidget .. ".sldSoundPitch", 0, 20, 2)
  widget.setSliderValue(self.layoutWidget .. ".sldSoundPitch", self.soundPitch * 10)

  self:populateScrollArea(self.allRaceSounds, self.selectedSpecies)
end

function sounds:populateScrollArea(allRaceSounds, selectedSpecies)
  widget.clearListItems(self.layoutWidget .. ".saSpecies.listItems")

  for speciesName, _ in pairs(allRaceSounds) do
    local li = widget.addListItem(self.layoutWidget .. ".saSpecies.listItems")
    widget.setText(self.layoutWidget .. ".saSpecies.listItems." .. li .. ".name", speciesName)
    widget.setData(self.layoutWidget .. ".saSpecies.listItems." .. li, speciesName)
    if speciesName == selectedSpecies then
      widget.setListSelected(self.layoutWidget .. ".saSpecies.listItems", li)
    end
  end
end

function sounds:changeSpecies()
  local li = widget.getListSelected(self.layoutWidget .. ".saSpecies.listItems") 
  if li then
    local newSpecies = widget.getData(self.layoutWidget .. ".saSpecies.listItems." .. li)
    player.setProperty("scc_sound_species", newSpecies)
    self.soundsPool = self.allRaceSounds[newSpecies][player.gender()]
    save()
  end
end

function sounds:enableSounds()
  self.soundsEnabled = widget.getChecked(self.layoutWidget .. ".chkEnabled")
  player.setProperty("scc_sounds_enabled", self.soundsEnabled)
  save()
end

function sounds:enableWhisperSounds()
  self.soundsWhispersEnabled = widget.getChecked(self.layoutWidget .. ".chkEnabledWhisper")
  player.setProperty("scc_sounds_whisper_enabled", self.soundsWhispersEnabled)
  save()
end

function sounds:playSound()
  local soundTable = {
    pool = self.soundsPool,
    pitch = self.soundPitch,
    volume = 1.3
  }
  if xsb then
    if not world.getGlobal("SCC::TalkingSound") then
      status.addPersistentEffect("scctalking", "scctalking")
    end
    world.sendEntityMessage(player.id(), "SCC::TalkingSound", soundTable)
  else
    if not shared.sccTalkingSound then
      status.addPersistentEffect("scctalking", "scctalking")
    end
    shared.sccTalkingSound(soundTable)
  end
end

function sounds:setTalkingPitch()
  self.soundPitch = math.max(widget.getSliderValue(self.layoutWidget .. ".sldSoundPitch") / 10, 0.4)
  widget.setSliderValue(self.layoutWidget .. ".sldSoundPitch", self.soundPitch * 10)
  player.setProperty("scc_sound_pitch", self.soundPitch)
  save()
end