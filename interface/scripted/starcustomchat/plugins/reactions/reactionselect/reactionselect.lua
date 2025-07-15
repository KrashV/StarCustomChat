require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"

function init()
  self.maxLength = 50

  self.emojiList = root.assetJson("/interface/scripted/starcustomchat/plugins/reactions/reactionlist.json")
  self.stagehandType = config.getParameter("stagehandType")
  populateReacts()

  pane.setTitle(getTitle(config.getParameter("text")), config.getParameter("nickname"))
  pane.setTitleIcon(string.format("/emotes/%s.emote.png", self.emojiList[math.random(#self.emojiList)]))

end


function clearMetatags(text)
  return text:gsub("%^.-;", "")
end

function getTitle(text)
  local cleanText = clearMetatags(text)
  return utf8.len(cleanText) > self.maxLength and starcustomchat.utils.utf8Substring(cleanText, 1, self.maxLength) .. "..." or text
end

function populateReacts(search)
  widget.clearListItems("scrollArea.reactList")

  for _, emoji in ipairs(self.emojiList) do 
    if not search or string.find(emoji, search, nil, true) then
      local li = widget.addListItem("scrollArea.reactList")
      widget.setImage("scrollArea.reactList." .. li .. ".emoji", string.format("/emotes/%s.emote.png", emoji))
      widget.setData("scrollArea.reactList." .. li, emoji)
      widget.setData("scrollArea.reactList." .. li .. ".emoji", emoji)
    end
  end
end

function searchEmoji()
  populateReacts(widget.getText("tbxSearch"))
end

function onEmojiSelect()
  local li = widget.getListSelected("scrollArea.reactList")
  if li then
    local data = {
      nickname = player.name(),
      reaction = widget.getData("scrollArea.reactList." .. li),
      uuid = config.getParameter("messageUUID")
    }

    
    if self.stagehandType and self.stagehandType ~= "" then
      starcustomchat.utils.createStagehandWithData(self.stagehandType, {message = "addReaction", data = data})
    else
      for _, pl in ipairs(world.playerQuery(world.entityPosition(player.id()), 100)) do 
        world.sendEntityMessage(pl, "scc_add_reaction", data)
      end
    end

    pane.dismiss()
  end
end

function createTooltip(screenPosition)
  local wid = widget.getChildAt(screenPosition)
  if wid then
    local data = widget.getData(wid:sub(2))
    if data then return data end
  end
end