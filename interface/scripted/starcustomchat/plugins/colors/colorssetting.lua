require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"
require "/interface/scripted/starcustomchatsettings/colorpicker/widget.lua"

colors = SettingsPluginClass:new(
  { name = "colors" }
)

function colors:init(chat)
  self:_loadConfig()
  self.picker = colorpicker.new(self.layoutWidget .. ".cnvColorPicker")
  self.currentColor = ""
  self.coursorCanvas = widget.bindCanvas(self.layoutWidget .. ".coursorCanvas")
  local defaultColors = {}

  for _, color in ipairs(self.items) do 
    defaultColors[color.name] = color.default
  end

  self.colors = sb.jsonMerge(defaultColors, root.getConfiguration("scc_custom_colors") or {})
end

function colors:onLocaleChange()
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.colors"))
  widget.setText(self.layoutWidget .. ".btnDropToDefault", starcustomchat.utils.getTranslation("settings.colors.drop_to_default"))
  self:populateList()
end

function colors:populateList()
  widget.clearListItems(self.layoutWidget .. ".saScrollArea.listItems")
  self.currentListItem = nil
  self.currentItemName = nil
  widget.setVisible(self.layoutWidget .. ".btnDropToDefault", false)


  for _, item in ipairs(self.items) do 
    local li = widget.addListItem(self.layoutWidget .. ".saScrollArea.listItems")
    local newListItem = self.layoutWidget .. ".saScrollArea.listItems." .. li

    widget.setText(newListItem .. ".name", starcustomchat.utils.getTranslation(item.label))
    widget.setFontColor(newListItem .. ".name", "#" .. (self.colors[item.name] or item.default))
    widget.setData(newListItem, {
      defaultColor = item.default,
      name = item.name
    })
  end
end

function colors:changedColorItem()
  local selectedItem = widget.getListSelected(self.layoutWidget .. ".saScrollArea.listItems")
  if selectedItem then
    local data = widget.getData(self.layoutWidget .. ".saScrollArea.listItems." .. selectedItem)
    self.currentListItem = selectedItem
    self.currentItemName = data.name
    self.picker:setColor(self.colors[self.currentItemName] or data.defaultColor)
    widget.setVisible(self.layoutWidget .. ".btnDropToDefault", true)
  end
end

function colors:cursorOverride()
  if input.mouseUp("MouseLeft") and self.picker.down then
    self.picker.down = false
  end
end

function colors:update()
  self.coursorCanvas:clear()
  if widget.active(self.layoutWidget) and self.currentListItem then
    self.picker:update()
    if self.currentColor ~= self.picker:hex() then
      self.currentColor = self.picker:hex()

      self.colors[self.currentItemName] = self.currentColor
      root.setConfiguration("scc_custom_colors", self.colors)
      save()
      widget.setFontColor(self.layoutWidget .. ".saScrollArea.listItems." .. self.currentListItem .. ".name", 
        "#" .. self.currentColor)
      widget.setImage(self.layoutWidget .. ".previewImage", "/interface/scripted/starcustomchatsettings/colorpicker/previewcolor.png?replace;FFFF=" .. self.currentColor)
    end

    self.coursorCanvas:drawImage("/interface/easel/spectrumcursor.png", vec2.sub(self.picker.color_mouse, 3), 1)
    self.coursorCanvas:drawImage("/interface/easel/spectrumcursor.png", vec2.sub(self.picker.alpha_mouse, 3), 1)
  end
end

function colors:dropToDefault()
  if self.currentListItem then
    local defaultColor = widget.getData(self.layoutWidget .. ".saScrollArea.listItems." .. self.currentListItem).defaultColor
    self.picker:setColor(defaultColor)
    self.colors[self.currentItemName] = defaultColor
    root.setConfiguration("scc_custom_colors", self.colors)
    save()
  end
end

function colors:clickCanvasCallback(position, button, isDown)
  if widget.active(self.layoutWidget) then
    if button == 0 then
      self.picker.down = isDown
      widget.blur(self.layoutWidget .. ".cnvColorPicker")
    end
  end
end