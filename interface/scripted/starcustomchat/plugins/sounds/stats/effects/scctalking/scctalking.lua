require "/scripts/messageutil.lua"

local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

function sccTalkingSound(soundData)
  if type(soundData) == "string" then
    animator.setSoundPool(self.soundName, {soundData})
    animator.setSoundVolume(self.soundName, 1)
    animator.setSoundPitch(self.soundName, 1)
    animator.playSound(self.soundName)
  elseif type(soundData) == "table" then
    animator.setSoundPool(self.soundName, soundData.pool or {})
    animator.setSoundVolume(self.soundName, soundData.volume or 1)
    animator.setSoundPitch(self.soundName, soundData.pitch or 1)
    animator.playSound(self.soundName)
  end
end

function init()
  self.soundName = "ouch"

  if xsb then
    message.setHandler("SCC::TalkingSound", localHandler(sccTalkingSound))
    world.setGlobal("SCC::TalkingSound", true)
  else
    shared.sccTalkingSound = sccTalkingSound
  end
end

function uninit()
  if xsb then
    world.setGlobal("SCC::TalkingSound", nil)
  else
    shared.sccTalkingSound = nil
  end
end