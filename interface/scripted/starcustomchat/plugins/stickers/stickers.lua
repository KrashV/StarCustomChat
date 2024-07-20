require "/interface/scripted/starcustomchat/plugin.lua"

stickers = PluginClass:new(
  { name = "stickers" }
)

function stickers:init()
  self:_loadConfig()
  self.savedStickers = root.getConfiguration("scc_saved_stickers") or {}
end

function stickers:onProcessCommand(text)
  local stripped = text:gsub("/", ""):gsub(" ", "")
  if stripped and stripped ~= "" and self.savedStickers[stripped] then

    local message = {
      image = self.savedStickers[stripped],
      mode = widget.getSelectedData("rgChatMode").mode,
      connection = player.id() // -65536,
      nickname = player.name(),
      text = stripped
    }

    if message.mode == "Whisper" then
        local li = widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")
        if not li then 
          starcustomchat.utils.alert("chat.alerts.dm_not_found")
          return true
        end
  
        local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
        if not world.entityExists(data.id) then starcustomchat.utils.alert("chat.alerts.dm_not_found") return end
        world.sendEntityMessage(data.id, "icc_sendToUser", message)
        world.sendEntityMessage(player.id(), "icc_sendToUser", message)
    elseif message.mode == "Party" then
      for _, pl in ipairs(player.teamMembers()) do 
        world.sendEntityMessage(pl.entity, "icc_sendToUser", message)
      end
    else
      for _, pl in ipairs(world.playerQuery(world.entityPosition(player.id()), 100)) do 
        world.sendEntityMessage(pl, "icc_sendToUser", message)
      end
    end
    return true
  end
  return false
end


function stickers:addCustomCommandPreview(availableCommands, substr)
  for name, _ in pairs(self.savedStickers) do 
    if string.find("/" .. name, substr, nil, true) then
      table.insert(availableCommands, {
        name = "/" .. name,
        color = "stickercommands"
      })
    end
  end
end


function stickers:onReceiveMessage(message)
  if message and (message.image and string.find(message.image, "^/%w+%.png"))
    or (message.text and string.find(message.text, "^/%w+%.png")) then

    local imageSize = root.imageSize(message.image or message.text)
    if imageSize[1] > self.maxSize[1] or imageSize[2] > self.maxSize[2] then
      starcustomchat.utils.alert("settings.mainchat.alerts.size_error")
    else
      message.image = message.image or message.text
      message.imageSize = imageSize
    end
  end
end

function stickers:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)
  if selectedMessage and buttonName == "save_sticker" then
    return selectedMessage.image and not self.savedStickers[selectedMessage.text]
  end
end

function stickers:contextMenuButtonClick(buttonName, selectedMessage)
  if selectedMessage and buttonName == "save_sticker" and selectedMessage.image then
    local name = selectedMessage.text
    if name then
      if self.savedStickers[name] then
        starcustomchat.utils.alert("settings.plugins.stickers.alerts.already_exists")
        return
      else
        starcustomchat.utils.alert("chat.commands.alerts.saved", name)
        self.savedStickers[name] = selectedMessage.image
        root.setConfiguration("scc_saved_stickers", self.savedStickers)
      end
    end
  end
end

function stickers:onSettingsUpdate()
  self.savedStickers = root.getConfiguration("scc_saved_stickers") or {}
end