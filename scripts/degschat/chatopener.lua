require "/interface/scripted/degscustomchat/chatbuilder.lua"
require("/scripts/starextensions/lib/chat_callback.lua")

local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

function init()
  local reasonToNotStart = checkSEAndControls()
  if reasonToNotStart then
    local sewarningConfig = root.assetJson("/interface/scripted/degscustomchat/sewarning/sewarning.json")
    sewarningConfig.reason = reasonToNotStart
    player.interact("ScriptPane", sewarningConfig)
  else
    self.interface = buildChatInterface()
    shared.setMessageHandler = message.setHandler
  end
end

function checkSEAndControls()
  if not _ENV["starExtensions"] then
    return "se_not_found"
  elseif not setChatMessageHandler then
    return "se_version"
  else
    local bindings = root.getConfiguration("bindings")
    if #bindings["ChatBegin"] > 0 or #bindings["ChatBeginCommand"] > 0 or #bindings["InterfaceRepeatCommand"] > 0 then
      return "unbind_controls"
    end
  end
end

function update(dt)
  if not shared.chatIsOpen and self.interface then
    player.interact("ScriptPane", self.interface)
    shared.chatIsOpen = true
  end
end

function uninit()
end