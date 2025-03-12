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
  self.isOpenSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")
  self.isOSBXSB = self.isOpenSB or xsb

  self.chatUUID = sb.makeUuid()

  local reasonToNotStart = checkSEAndControls()

  if reasonToNotStart then
    local sewarningConfig = root.assetJson("/interface/scripted/starcustomchat/sewarning/sewarning.json")
    sewarningConfig.reason = reasonToNotStart
    player.interact("ScriptPane", sewarningConfig)
  else

    self.storedMessages = root.getConfiguration("scc_stored_messages") or {}
    self.chatHidden = root.getConfiguration("scc_chat_hidden") or false

    if not xsb then shared.setMessageHandler = message.setHandler end

    if not self.isOSBXSB then
      self.interface = buildChatInterface()
      SCChatTimer:add(0.5, function() innerHandlerCutter = setChatMessageHandler(receiveMessage) end)
      openChat()
    end

    if self.chatHidden and not self.isOSBXSB then
      hideChat()
    end
  end

  message.setHandler("scc_chat_hidden", localHandler(hideChat))
  message.setHandler("scc_chat_opened", localHandler(openChat))
  message.setHandler("scc_uuid", localHandler(function() return self.chatUUID end))

end

function checkSEAndControls()
  if not _ENV["starExtensions"] and not self.isOSBXSB then
    return "se_osb_xsb_not_found"
  elseif not root.assetData and (not root.assetData("/scripts/starextensions/lib/chat_callback.lua") and not player.questIds) then
    return "se_version"
  else
    if not self.isOSBXSB then
      require("/scripts/starextensions/lib/chat_callback.lua")
      if not setChatMessageHandler then
        return "se_version"
      end

      local bindings = root.getConfiguration("bindings")
      if #bindings["ChatBegin"] > 0 or #bindings["ChatBeginCommand"] > 0 or #bindings["InterfaceRepeatCommand"] > 0 then
        return "unbind_controls"
      end
    else
      if not world.loungingEntities then
        return "osb_xsb_version"
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
  if not self.isOSBXSB then
    self.chatHidden = false
    root.setConfiguration("scc_chat_hidden", self.chatHidden)
    self.interface.storedMessages = self.storedMessages
    self.interface.forceFocus = forceFocus
    self.interface.currentMessageMode = mode

    player.interact("ScriptPane", self.interface)
    self.storedMessages = {}
    shared.chatIsOpen = true
  end
end

function update(dt)
  SCChatTimer:update(dt)
  promises:update()
end

function uninit()
  if innerHandlerCutter then
    innerHandlerCutter()
  end

  if root.setConfiguration then 
    root.setConfiguration("scc_stored_messages", self.storedMessages)
  end

  if not self.isOSBXSB and shared.dismissPane then
    shared.dismissPane()
  end
end