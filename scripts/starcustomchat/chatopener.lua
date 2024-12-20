require "/interface/scripted/starcustomchat/chatbuilder.lua"
require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/scctimer.lua"

SCChatTimer = TimerKeeper.new()

local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

local innerHandlerCutter = nil

function init()
  local reasonToNotStart = checkSEAndControls()
  if reasonToNotStart then
    local sewarningConfig = root.assetJson("/interface/scripted/starcustomchat/sewarning/sewarning.json")
    sewarningConfig.reason = reasonToNotStart
    player.interact("ScriptPane", sewarningConfig)
  else
    self.interface = buildChatInterface()
    shared.setMessageHandler = message.setHandler
    self.chatHidden = root.getConfiguration("scc_chat_hidden") or false
    if self.chatHidden then
      hideChat()
    end
    SCChatTimer:add(0.5, function() innerHandlerCutter = setChatMessageHandler(receiveMessage) end)
    self.storedMessages = root.getConfiguration("scc_stored_messages") or {}
  end

  message.setHandler("scc_chat_hidden", localHandler(hideChat))
  message.setHandler("scc_chat_opened", localHandler(openChat))
end

function checkSEAndControls()
  if not _ENV["starExtensions"] then
    return "se_not_found"
  elseif not root.assetData or not root.assetData("/scripts/starextensions/lib/chat_callback.lua") then
    return "se_version"
  else
    require("/scripts/starextensions/lib/chat_callback.lua")
    if not setChatMessageHandler then
      return "se_version"
    else
      local bindings = root.getConfiguration("bindings")
      if #bindings["ChatBegin"] > 0 or #bindings["ChatBeginCommand"] > 0 or #bindings["InterfaceRepeatCommand"] > 0 then
        return "unbind_controls"
      end
    end
  end
end

function receiveMessage(message)
  if self.chatHidden then
    table.insert(self.storedMessages, message)
    if message.connection and (message.connection ~= 0 or not root.getConfiguration("scc_autohide_ignore_server_messages")) then
      world.sendEntityMessage(player.id(), "scc_close_revealing_interface")
    end
  end
end

function hideChat(mode)
  shared.chatIsOpen = false
  self.chatHidden = true
  root.setConfiguration("scc_chat_hidden", self.chatHidden)
  message.setHandler("icc_sendToUser", simpleHandler(receiveMessage))
  
  local revealAssets = root.assetJson("/interface/scripted/starcustomchatreveal/chatreveal.json")
  revealAssets.mode = mode
  player.interact("ScriptPane", revealAssets)
end

function openChat(forceFocus, mode)
  self.chatHidden = false
  root.setConfiguration("scc_chat_hidden", self.chatHidden)
  self.interface.storedMessages = self.storedMessages
  self.interface.forceFocus = forceFocus
  self.interface.currentMessageMode = mode

  player.interact("ScriptPane", self.interface)
  self.storedMessages = {}
  shared.chatIsOpen = true
end

function update(dt)
  SCChatTimer:update(dt)

  if not shared.chatIsOpen and self.interface and not self.chatHidden then
    openChat()
  end
end

function uninit()
  if innerHandlerCutter then
    innerHandlerCutter()
  end

  if root.setConfiguration then 
    root.setConfiguration("scc_stored_messages", self.storedMessages)
  end
end