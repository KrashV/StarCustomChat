require "/scripts/messageutil.lua"


local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

ICChatTimer = TimerKeeper.new()

function init()
  self.hiddenChatUUID = sb.makeUuid()

  ICChatTimer:add(0.5, registerCallbacks)

  ICChatTimer:add(2, checkUUID)
end

function checkUUID()
  if player.id() then
    world.sendEntityMessage(player.id(), "scc_reveal_check_uuid", self.chatUUID)
  end
  ICChatTimer:add(2, checkUUID)
end

function registerCallbacks()
  shared.setMessageHandler("scc_close_revealing_interface", localHandler(function()
    openChat()
  end))

  shared.setMessageHandler("scc_reveal_check_uuid", localHandler(function(uuid)
    if uuid ~= self.hiddenChatUUID then
      pane.dismiss()
    end
  end))
end

function openChat(_, _, _, force)
  world.sendEntityMessage(player.id(), "scc_chat_opened", force)
  pane.dismiss()
end

function update()
  if not player.id() or not world.entityExists(player.id()) then
    pane.dismiss()
    return
  end

  for _, event in ipairs(input.events()) do
    if event.type == "KeyDown" and event.data.key == "Return" then
      openChat(_, _, _, true)
    end
  end
end

function uninit()

end