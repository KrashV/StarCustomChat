require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/icctimer.lua"

ChatHandlerTimers = TimerKeeper.new()
local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end


function init()
  self.checkChatTimer = 0

  shared.setMessageHandler = message.setHandler
  
  message.setHandler( "icc_request_player_portrait", simpleHandler(function()
    if player.id() and world.entityExists(player.id()) then
      return {
        portrait = world.entityPortrait(player.id(), "bust"),
        type = "UPDATE_PORTRAIT",
        entityId = player.id(),
        connection = player.id() // -65536,
        cropArea = player.getProperty("icc_portrait_frame"),
        uuid = player.uniqueId()
      }
    end
  end))

  ChatHandlerTimers:add(self.checkChatTimer, function()
    if not shared.chatIsOpen then
      local interfacePath = "/interface/scripted/irdencustomchat/icchatgui.json"
      player.interact("ScriptPane", root.assetJson(interfacePath))
    end
  end)
end

-- We will wait self.lastCheckedQueueTimer seconds to check for the message to be read.
-- If we don't receive the request for the message, consider the chat dead.
function update(dt)
  ChatHandlerTimers:update(dt)
  promises:update()
end

function uninit()
end