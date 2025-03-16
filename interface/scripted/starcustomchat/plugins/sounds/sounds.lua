require "/interface/scripted/starcustomchat/plugin.lua"

sounds = PluginClass:new(
  { name = "sounds" }
)

function sounds:init()
  self:_loadConfig()

  self.allRaceSounds = root.assetJson("/npcs/base.npctype")["scriptConfig"]["chatSounds"]
  self:resetSoundPool()
  self.soundsEnabled = player.getProperty("scc_sounds_enabled") or false
  self.soundsWhispersEnabled = player.getProperty("scc_sounds_whisper_enabled") or false
  self.soundPitch = player.getProperty("scc_sound_pitch") or 1
  status.addPersistentEffect("scctalking", "scctalking")
end

function sounds:resetSoundPool()
  local selectedSpecies = player.getProperty("scc_sound_species") or player.species()
  local currentRaceSounds = self.allRaceSounds[selectedSpecies] or self.allRaceSounds["human"]

  self.soundsPool = currentRaceSounds[player.gender()]
end

function sounds:onSendMessage()
  self:playSound()
end

function sounds:playSound()
  if self.soundsEnabled then
    local soundTable = {
      pool = self.soundsPool,
      pitch = self.soundPitch,
      volume = 1.3
    }
    world.sendEntityMessage(player.id(), "sccTalkingSound", soundTable)
  end
end

function sounds:onProcessCommand(text)
  if string.sub(text, 1, 3) == "/w " and self.soundsWhispersEnabled then
    self:playSound()
    player.emote("blabbering")
  end
end

function sounds:onSettingsUpdate()
  self.soundsEnabled = player.getProperty("scc_sounds_enabled") or false
  self.soundsWhispersEnabled = player.getProperty("scc_sounds_whisper_enabled") or false
  self.soundPitch = player.getProperty("scc_sound_pitch") or 1
  self:resetSoundPool()
end

function sounds:uninit()
  status.clearPersistentEffects("scctalking")
end