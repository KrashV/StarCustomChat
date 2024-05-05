local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

function init()
  self.soundName = "ouch"

  shared.sccTalkingSound = sccTalkingSound
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