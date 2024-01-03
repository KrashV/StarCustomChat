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
end


function update(dt)
  if not shared.chatIsOpen then
    local interfacePath = "/interface/scripted/irdencustomchat/icchatgui.json"
    player.interact("ScriptPane", root.assetJson(interfacePath))
    shared.chatIsOpen = true
  end
end

function uninit()
end