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
    if not search or string.find(name, search) then
      self:addStickerToList(name, image)
    end
  end
end

function stickers:onLocaleChange()
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.stickers"))
  widget.setText(self.layoutWidget .. ".btnAdd", starcustomchat.utils.getTranslation("settings.plugins.stickers.add"))
  widget.setText(self.layoutWidget .. ".btnRemove", starcustomchat.utils.getTranslation("settings.plugins.stickers.remove"))
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
  if pcall(function() root.imageSize(newImage) end) then
    local imageSize = root.imageSize(newImage)

    if imageSize[1] > 32 or imageSize[2] > 32 then
      starcustomchat.utils.alert("settings.plugins.stickers.alerts.size_error")
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