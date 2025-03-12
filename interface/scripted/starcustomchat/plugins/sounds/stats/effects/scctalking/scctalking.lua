require "/scripts/messageutil.lua"

function init()
  self.soundName = "ouch"
  message.setHandler("sccTalkingSound", localHandler(sccTalkingSound))
end


function sccTalkingSound(soundData)
  if type(soundData) == "string" then
    animator.setSoundPool(self.soundName, {soundData})
    animator.setSoundVolume(self.soundName, 1)
    animator.setSoundPitch(self.soundName, 1)
  elseif type(soundData) == "table" then
    animator.setSoundPool(self.soundName, soundData.pool or {})
    animator.setSoundVolume(self.soundName, soundData.volume or 1)
    animator.setSoundPitch(self.soundName, soundData.pitch or 1)
  end
  animator.playSound(self.soundName)
end

function uninit()

end