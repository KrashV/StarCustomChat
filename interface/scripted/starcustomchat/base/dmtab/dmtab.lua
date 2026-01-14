function checkDMs(dmingTo)
  self.DMTimer = 2

  if widget.getSelectedData("rgChatMode").mode == "Whisper" then
    populateList(dmingTo)
  else
    self.contacts = {}
    widget.clearListItems("lytCharactersToDM.saPlayers.lytPlayers")
  end
  ICChatTimer:add(self.DMTimer, checkDMs)
end

function populateList(dmingTo)
  local function drawCharacters(players, toRemovePlayers)
    local mode =  "avatar" -- #players > 7 and "letter" or "avatar"

    local idTable = {}  -- This table will store only the 'id' values

    for _, player in ipairs(players) do
      table.insert(idTable, player.id)

      if index(self.contacts, player.id) == 0 and player.data then
        local li = widget.addListItem("lytCharactersToDM.saPlayers.lytPlayers")
        if mode == "letter" or not player.data.portrait then
          local trimmedName = starcustomchat.utils.utf8Substring(starcustomchat.utils.clearNick(player.name), 1, 2)
          trimmedName = utf8.len(trimmedName) == 1 and trimmedName .. " " or (utf8.len(trimmedName) == 0 and "  ") or trimmedName
          drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", trimmedName)
        elseif player.data.portrait then
          drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", player.data.portrait)
        end

        widget.setData("lytCharactersToDM.saPlayers.lytPlayers." .. li, {
          id = player.id,
          tooltipMode = player.name
        })
        self.tooltipFields["lytCharactersToDM.saPlayers.lytPlayers." .. li] = player.name
        table.insert(self.contacts, player.id)


        if dmingTo and dmingTo == player.id then
          self.ignoreSettingList = true
          widget.setListSelected("lytCharactersToDM.saPlayers.lytPlayers", li)
        end
      end
    end


    if toRemovePlayers then
      for i, id in ipairs(self.contacts) do
        if index(idTable, id) == 0 then
          self.ignoreSettingList = true
          widget.removeListItem("lytCharactersToDM.saPlayers.lytPlayers", i - 1)
          table.remove(self.contacts, i)
        end
      end
    end
  end

  local playersAround = {}

  if player.id() and world.entityPosition(player.id()) then
    for _, player in ipairs(starcustomchat.utils.playersInRadius(40)) do
      table.insert(playersAround, {
        id = player,
        name = world.entityName(player) or "Unknown",
        data = {
          portrait = world.entityPortrait(player, "full")
        }
      })
    end
  end

  drawCharacters(playersAround, not self.receivedMessageFromStagehand)
end

function selectPlayer()
  local li = widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")
  if li then 
    local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)

    self.DMingPlayerID = data.id 
  end

  if not self.ignoreSettingList then
    widget.focus("tbxInput")
  end

  self.ignoreSettingList = nil
end

function drawIcon(canvasName, args)
	local playerCanvas = widget.bindCanvas(canvasName)
  playerCanvas:clear()

  if type(args) == "number" then
    local playerPortrait = world.entityPortrait(args, "full")
    for _, layer in ipairs(playerPortrait) do
      playerCanvas:drawImage(layer.image, {-14, -18})
    end
  elseif type(args) == "table" then
    for _, layer in ipairs(args) do
      playerCanvas:drawImage(layer.image, {-14, -18})
    end
  elseif type(args) == "string" and utf8.len(args) == 2 then
    playerCanvas:drawText(args, {
      position = {8, 3},
      horizontalAnchor = "mid", -- left, mid, right
      verticalAnchor = "bottom", -- top, mid, bottom
      wrapWidth = nil -- wrap width in pixels or nil
    }, self.customChat.config.fontSize + 1)
  elseif type(args) == "string" then
    playerCanvas:drawImage(args, {-1, 0})
  end
end