require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

stickers = SettingsPluginClass:new(
  { name = "stickers" }
)


-- Settings
function stickers:init()
  self:_loadConfig()
  self.savedStickers = root.getConfiguration("scc_saved_stickers") or {}
  self.stickerIndexes = {}
  self:populateList()
end

function stickers:populateList(search)
  widget.clearListItems(self.layoutWidget .. ".saSavedStickers.listStickers") 
  self.stickerIndexes = {}
  for name, image in pairs(self.savedStickers) do 
    if not search or string.find(name, search, nil, true) then
      self:addStickerToList(name, image)
    end
  end
end

function stickers:addStickerToList(name, image)
  local li = widget.addListItem(self.layoutWidget .. ".saSavedStickers.listStickers")
  table.insert(self.stickerIndexes, li)
  widget.setImage(self.layoutWidget .. ".saSavedStickers.listStickers." .. li .. ".sticker", image)
  widget.setText(self.layoutWidget .. ".saSavedStickers.listStickers." .. li .. ".name", name)
  widget.setData(self.layoutWidget .. ".saSavedStickers.listStickers." .. li, {
    name = name,
    image = image
  })
end

function stickers:addSticker()
  local directives = widget.getText(self.layoutWidget .. ".tbxStickerDirectives")
  local name = widget.getText(self.layoutWidget .. ".tbxStickerName")
  if not directives or directives == "" or not name or name == "" then
    starcustomchat.utils.alert("settings.plugins.stickers.alerts.name_error")
    return
  end

  if self.savedStickers[name] then
    starcustomchat.utils.alert("settings.plugins.stickers.alerts.already_exists")
    return
  end

  local newImage = "/assetmissing.png" .. directives

  local imageSize = starcustomchat.utils.safeImageSize(newImage)
  if imageSize then
    if imageSize[1] > self.maxSize[1] or imageSize[2] > self.maxSize[2] then
      starcustomchat.utils.alert("settings.plugins.stickers.alerts.size_error", self.maxSize[1], self.maxSize[2])
      widget.setText(self.layoutWidget .. ".tbxStickerDirectives", "")
      return
    end

    self.savedStickers[name] = newImage
    self:addStickerToList(name, newImage)
    widget.setText(self.layoutWidget .. ".tbxStickerDirectives", "")
    widget.setText(self.layoutWidget .. ".tbxStickerName", "")
    save()
  else
    starcustomchat.utils.alert("settings.plugins.stickers.alerts.image_error")
    widget.setText(self.layoutWidget .. ".tbxStickerDirectives", "")
  end
end

function stickers:searchSticker()
  local text = widget.getText(self.layoutWidget .. ".tbxStickerSearch")
  self:populateList(text)
end

function stickers:removeSticker()
  local li = widget.getListSelected(self.layoutWidget .. ".saSavedStickers.listStickers")
  if li then
    local data = widget.getData(self.layoutWidget .. ".saSavedStickers.listStickers." .. li)
    local ind = index(self.stickerIndexes, li)
    if ind then
      widget.removeListItem(self.layoutWidget .. ".saSavedStickers.listStickers", ind - 1)
      self.savedStickers[data.name] = nil
      table.remove(self.stickerIndexes, ind)
      widget.setVisible(self.layoutWidget .. ".btnRemove", false)
      save()
    end
  end
end

function stickers:onStickerSelected()
  local li = widget.getListSelected(self.layoutWidget .. ".saSavedStickers.listStickers")
  if li then
    widget.setVisible(self.layoutWidget .. ".btnRemove", true)
  end
end

function stickers:uninit()
  root.setConfiguration("scc_saved_stickers", self.savedStickers)
end