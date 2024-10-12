require "/scripts/messageutil.lua"
require "/scripts/scctimer.lua"


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
    world.sendEntityMessage(player.id(), "scc_check_uuid", self.hiddenChatUUID)
    promises:add(world.sendEntityMessage(player.id(), "icc_is_chat_open"), function(res)
      if res then pane.dismiss() end
    end)
  end
  ICChatTimer:add(2, checkUUID)
end

function registerCallbacks()
  shared.setMessageHandler("scc_close_revealing_interface", localHandler(function()
    openChat()
  end))

  shared.setMessageHandler("scc_check_uuid", localHandler(function(uuid)
    if uuid ~= self.hiddenChatUUID then
      pane.dismiss()
    end
  end))
end

function openChat(_, _, _, force)
  world.sendEntityMessage(player.id(), "scc_chat_opened", force, config.getParameter("mode"))
  pane.dismiss()
end

function update(dt)
  ICChatTimer:update(dt)
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