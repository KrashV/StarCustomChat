require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"

function init()
  self.emojiList = root.assetJson("/interface/scripted/starcustomchat/plugins/reactions/reactions/reactionlist.json")
  populateReacts()

  local text = config.getParameter("text")
  pane.setTitle(utf8.len(text) > 20 and starcustomchat.utils.utf8Substring(text, 1, 20) .. "..." or text, config.getParameter("nickname"))
  pane.setTitleIcon(string.format("/interface/scripted/starcustomchat/plugins/reactions/reactions/%s.png", self.emojiList[math.random(#self.emojiList)]))
end

function populateReacts(search)
  widget.clearListItems("scrollArea.reactList")

  for _, emoji in ipairs(self.emojiList) do 
    if not search or string.find(emoji, search) then
      local li = widget.addListItem("scrollArea.reactList")
      widget.setImage("scrollArea.reactList." .. li .. ".emoji", string.format("/interface/scripted/starcustomchat/plugins/reactions/reactions/%s.png", emoji))
      widget.setData("scrollArea.reactList." .. li, emoji)
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

    for _, pl in ipairs(world.playerQuery(world.entityPosition(player.id()), 100)) do 
      world.sendEntityMessage(pl, "scc_add_reaction", data)
    end

    pane.dismiss()
  end
end