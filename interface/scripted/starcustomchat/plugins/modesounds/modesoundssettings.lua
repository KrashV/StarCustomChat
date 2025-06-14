require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

modesounds = SettingsPluginClass:new(
  { name = "modesounds" }
)


-- Settings
function modesounds:init()
  self:_loadConfig()

  self.modeSoundTable = root.getConfiguration("scc_mode_sounds") or {}
end

function modesounds:openTab()
  self.soundList = {}

  for _, sound in ipairs(self.sounds) do
    local name = sound:match("(/[^/]+/[^/]+)$") or sound
    table.insert(self.soundList, {
      name = name,
      data = sound
    })
  end

  self:populateModesScrollArea()
end

function modesounds:populateModesScrollArea()
  self.selectedModeListItem = nil
  local modeList = {}
  for _, mode in pairs(config.getParameter("chatModes", {})) do
    table.insert(modeList, {
      name = starcustomchat.utils.getTranslation("chat.modes." .. mode) or mode,
      data = mode
    })
  end

  self:populateScrollArea("saModes", modeList, nil, function(name, data, li)
    if self.modeSoundTable[data] then
      self.widget.setFontColor("saModes.listItems." .. li .. ".name", "blue")
    end
  end)
end

function modesounds:onLocaleChange()
  self:populateModesScrollArea()
  self.widget.setButtonEnabled("btnClear", false)
  self:populateScrollArea("saSounds", self.soundList)
end

function modesounds:changeMode()
  self.selectedModeListItem = self.widget.getListSelected("saModes.listItems")
  if self.selectedModeListItem then
    self.selectedMode = self.widget.getData("saModes.listItems." .. self.selectedModeListItem)
  end


  self.widget.setVisible("btnClear", true)
  self.widget.setButtonEnabled("btnClear", false)
  self:populateScrollArea("saSounds", self.soundList, self.modeSoundTable[self.selectedMode])
end

function modesounds:populateScrollArea(scrollArea, items, selectedItem, callback)
  self.widget.clearListItems(scrollArea .. ".listItems")

  for _, item in ipairs(items or {}) do
    local li = self.widget.addListItem(scrollArea .. ".listItems")
    self.widget.setText(scrollArea .. ".listItems" .. "." .. li .. ".name", item.name)
    self.widget.setData(scrollArea .. ".listItems" .. "." .. li, item.data)
    if selectedItem and item.data == selectedItem then
      self.widget.setListSelected(scrollArea .. ".listItems", li)
      self.widget.setButtonEnabled("btnClear", true)
    end

    if callback then
      callback(item.name, item.data, li)
    end
  end
end

function modesounds:setModeSound()
  local li = self.widget.getListSelected("saSounds.listItems")
  if li then
    local sound = self.widget.getData("saSounds.listItems." .. li)
    if sound then
      pane.playSound(sound)
      self.modeSoundTable[self.selectedMode] = sound
      self.widget.setButtonEnabled("btnClear", true)
      if self.selectedModeListItem then
        self.widget.setFontColor("saModes.listItems." .. self.selectedModeListItem .. ".name", "blue")
      end
    else
      self.modeSoundTable[self.selectedMode] = nil
      if self.selectedModeListItem then
        self.widget.setFontColor("saModes.listItems." .. self.selectedModeListItem .. ".name", "white")
      end
    end
  end
  root.setConfiguration("scc_mode_sounds", self.modeSoundTable)
  save()
end

function modesounds:clearModeSound()
  if self.selectedMode then
    self.widget.setButtonEnabled("btnClear", false)
    self.modeSoundTable[self.selectedMode] = nil
    if self.selectedModeListItem then
      self.widget.setFontColor("saModes.listItems." .. self.selectedModeListItem .. ".name", "white")
    end
    root.setConfiguration("scc_mode_sounds", self.modeSoundTable)
    save()
    self:populateScrollArea("saSounds", self.soundList, nil)
  end
end

function modesounds:uninit()
  pane.stopAllSounds(self.modeSoundTable[self.selectedMode])
end