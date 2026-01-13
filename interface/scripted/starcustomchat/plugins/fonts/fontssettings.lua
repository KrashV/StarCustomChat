require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

fonts = SettingsPluginClass:new(
  { name = "fonts" }
)


-- Settings
function fonts:init(chat)
  self:_loadConfig()
  self.chat = chat

  self.currentFonts = root.getConfiguration("scc_custom_fonts") or {}
end

function fonts:isAvailable()
  return root.assetsByExtension
end

function fonts:openTab()
  self.combobox = Combobox:bind(self.layoutWidget .. "." .. "btnSelectFont", config.getParameter("allFontsTable"), function(data)
    self:selectedCombobox(data)
  end, {
    filter = true,
    size = root.imageSize("/interface/scripted/combobox/background.png"),
    offset = {0, 10},
    closeOnSelect = true
  })
  self:populateList()
end

function fonts:populateList()
  self.widget.clearListItems("saScrollArea.listItems")

  self.currentListItem = nil
  self.currentItemName = nil
  self.currentLabel = nil

  self.widget.setVisible("btnDropToDefault", false)

  for _, item in ipairs(self.items) do 
    local li = self.widget.addListItem("saScrollArea.listItems")
    local newListItem = "saScrollArea.listItems." .. li

    local font = self.currentFonts[item.name] or "hobo"

    self.widget.setText(newListItem .. ".name", string.format("^font=%s;%s", font or "hobo", starcustomchat.utils.getTranslation(item.label)))
    self.widget.setData(newListItem, {
      name = item.name,
      font = font,
      label = item.label
    })
  end
end

function fonts:changedFontItem()
  local selectedItem = self.widget.getListSelected("saScrollArea.listItems")
  if selectedItem then
    local data = self.widget.getData("saScrollArea.listItems." .. selectedItem)
    self.currentListItem = selectedItem
    self.currentItemName = data.name
    self.currentLabel = data.label

    self.combobox:setSelected(self.currentFonts[self.currentItemName] or "hobo")
    self.widget.setText("btnSelectFont", self.currentFonts[self.currentItemName] or "hobo")
    self.widget.setVisible("btnDropToDefault", true)
    self.widget.setVisible("btnSelectFont", true)
  end

end

function fonts:dropToDefault()
  self:selectedCombobox()
end

function fonts:selectedCombobox(newFont)
  self.widget.setText("btnSelectFont", newFont or "hobo")

  if self.currentListItem then
    self.widget.setText("saScrollArea.listItems." .. self.currentListItem .. ".name", string.format("^font=%s;%s", newFont or "hobo", starcustomchat.utils.getTranslation(self.currentLabel)))
    self.widget.setData("saScrollArea.listItems." .. self.currentListItem, {
      name = self.currentItemName,
      font = font,
      label = self.currentLabel
    })

    self.currentFonts[self.currentItemName] = newFont
    root.setConfiguration("scc_custom_fonts", self.currentFonts)
    save()
  end
end

function fonts:uninit()

end