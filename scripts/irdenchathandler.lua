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
  self.checkChatTimer = 3

  shared.setMessageHandler = message.setHandler
  
  message.setHandler( "icc_request_player_portrait", simpleHandler(function()
    if player.id() and world.entityExists(player.id()) then
      return {
        portrait = world.entityPortrait(player.id(), "full"),
        type = "UPDATE_PORTRAIT",
        entityId = player.id(),
        cropArea = player.getProperty("icc_portrait_frame"),
        uuid = player.uniqueId()
      }
    end
  end))

  local function createCheckingTheInterface()
    promises:add(world.sendEntityMessage(player.uniqueId(), "icc_is_chat_open"), function()
      ChatHandlerTimers:add(self.checkChatTimer, createCheckingTheInterface)
    end, function()
      local interfacePath = "/interface/scripted/irdencustomchat/icchatgui.json"
      player.interact("ScriptPane", root.assetJson(interfacePath))
      ChatHandlerTimers:add(self.checkChatTimer, createCheckingTheInterface)
    end)
  end

  
  ChatHandlerTimers:add(self.checkChatTimer, createCheckingTheInterface)
end

-- We will wait self.lastCheckedQueueTimer seconds to check for the message to be read.
-- If we don't receive the request for the message, consider the chat dead.
function update(dt)
  ChatHandlerTimers:update(dt)
  promises:update()
end

function uninit()
  
end