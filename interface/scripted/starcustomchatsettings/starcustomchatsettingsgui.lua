require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/messageutil.lua"
require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"
require "/interface/scripted/combobox/combobox.class.lua"

function init()

  self.isOpenSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")
  self.isOSBXSB = self.isOpenSB or xsb
  
  self.translations = config.getParameter("translations", jarray())
  self.hintTranslations = config.getParameter("hintTranslations", jarray())

  local plugins = {}

  self.currentLanguage = root.getConfiguration("scclocale") or "en"
  
  self.availableLocales = root.assetJson("/interface/scripted/starcustomchat/locales/locales.json")

  self.pluginSettingsButtons = {}

  -- Load plugins
  for i, pluginName in ipairs(config.getParameter("enabledPlugins", {})) do 
    local pluginConfig = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", pluginName, pluginName))

    if pluginConfig.settingsScript then
      require(pluginConfig.settingsScript)

      if not _ENV[pluginName] then
        sb.logError("Failed to load settings plugin %s", pluginName)
      else
        if _ENV[pluginName]:isAvailable() then
          table.insert(plugins, _ENV[pluginName]:new())
        end
      end
    end
  end

  self.runCallbackForPlugins = function(method, ...)
    -- The logic here is actually strange and might need some more customisation
    local result = nil
    for _, plugin in ipairs(plugins) do 
      result = plugin[method](plugin, ...)
    end
    return result
  end

  self.runCallback = function(pluginName, method, ...)
    if not pluginName or not method then return end

    for _, plugin in ipairs(plugins) do 
      if plugin.name == pluginName then
        if plugin[method] then
          return plugin[method](plugin, ...)
        else
          sb.logError("Plugin %s does not have method %s", pluginName, method)
          return
        end
      end
    end

    sb.logError("Plugin %s does not exist", pluginName)

    return
  end

  self.pluginLayouts = {}

  local pluginLayouts = config.getParameter("gui")["lytPluginSettings"]["children"]
  local sortedLayouts = {}

  for layoutName, layoutConfig in pairs(pluginLayouts) do 
    table.insert(sortedLayouts, layoutConfig)
  end

  table.sort(sortedLayouts, function(lay1, lay2)
    local a_priority = lay1.data.priority or 999999
    local b_priority = lay2.data.priority or 999999

    return a_priority < b_priority
  end)

  widget.clearListItems("saPlugins.listPluginTabs")
  for i, layoutConfig in pairs(sortedLayouts) do 
    if _ENV[layoutConfig.data.pluginName]:isAvailable() then
      self.pluginLayouts[layoutConfig.data.pluginName] = layoutConfig.data.pluginName
      local li = widget.addListItem("saPlugins.listPluginTabs")

      self.pluginSettingsButtons[layoutConfig.data.pluginName] = li

      widget.setButtonImages("saPlugins.listPluginTabs." .. li .. ".pluginSetting", {
        base = layoutConfig.data.base,
        hover = layoutConfig.data.hover,
        pressed = layoutConfig.data.baseImageChecked
      })
      widget.setButtonCheckedImages("saPlugins.listPluginTabs." .. li .. ".pluginSetting", {
        base = layoutConfig.data.baseImageChecked,
        hover = layoutConfig.data.hoverImageChecked,
        pressed = layoutConfig.data.base
      })

      widget.setData("saPlugins.listPluginTabs." .. li, layoutConfig.data)
      widget.setData("saPlugins.listPluginTabs." .. li .. ".pluginSetting", {
        pluginTabName = layoutConfig.data.pluginName
      })
      widget.setChecked("saPlugins.listPluginTabs." .. li .. ".pluginSetting", i == 1)
    end
  end

  for _, spinnerName in ipairs(config.getParameter("spinnerNames")) do 
    widget.setData(spinnerName .. ".up", widget.getData(spinnerName))
    widget.setData(spinnerName .. ".down", widget.getData(spinnerName))
  end

  self.localization = config.getParameter("localizationTable")

  self.runCallbackForPlugins("init", self.localization)
  populateLanguagesList()
end

function localeSettings()
  starcustomchat.utils.buildLocale(self.localization)
  local selectedLocale = root.getConfiguration("scclocale") or "en"
  widget.setButtonImages("btnLanguage", {
    base = "/interface/scripted/starcustomchatsettings/flags/" .. selectedLocale .. ".png?border=1;000F",
    hover = "/interface/scripted/starcustomchatsettings/flags/" .. selectedLocale .. ".png?brightness=90?border=1;000F"
  })
  
  local version = starcustomchat.utils.getVersion()
  version = version and " v" .. version or ""
  pane.setTitle(starcustomchat.utils.getTranslation("settings.title"), starcustomchat.utils.getTranslation("settings.subtitle") .. version)

  for _, translation in ipairs(self.translations) do 
    widget.setText(translation.widget, starcustomchat.utils.getTranslation(translation.key))
  end

  for _, translation in ipairs(self.hintTranslations) do 
    if widget.setHint then -- not in the current release of OSB
      widget.setHint(translation.widget, starcustomchat.utils.getTranslation(translation.key))
    end
  end

  self.runCallbackForPlugins("onLocaleChange", self.localePluginConfig)
end

function populateLanguagesList()
  widget.clearListItems("lytSelectLanguage.saLanguages.listLanguages")
  local selectedLocale = root.getConfiguration("scclocale") or "en"

  for locale, localeConfig in pairs(self.availableLocales) do 
    local flagImage = "/interface/scripted/starcustomchatsettings/flags/" .. locale .. ".png"
    local li = widget.addListItem("lytSelectLanguage.saLanguages.listLanguages")

    if li then
      widget.setImage("lytSelectLanguage.saLanguages.listLanguages." .. li .. ".language", flagImage)
      widget.setData("lytSelectLanguage.saLanguages.listLanguages." .. li .. ".language", {
        lang = locale,
        displayPlainText = localeConfig.name
      })
      widget.setData("lytSelectLanguage.saLanguages.listLanguages." .. li, {
        lang = locale,
        displayPlainText = localeConfig.name
      })

      if locale == selectedLocale then
        widget.setListSelected("lytSelectLanguage.saLanguages.listLanguages", li)
      end
    end
  end
end

function setLanguage()
  local li = widget.getListSelected("lytSelectLanguage.saLanguages.listLanguages")
  if li then
    local data = widget.getData("lytSelectLanguage.saLanguages.listLanguages." .. li)
    root.setConfiguration("scclocale", data.lang)
  
    localeSettings()
    save()
    widget.setVisible("lytSelectLanguage", false)
  end
end

function save()
  self.runCallbackForPlugins("save", starcustomchat.locale)
  world.sendEntityMessage(player.id(), "scc_reset_settings")
end

function changePluginPage()
  local li = widget.getListSelected("saPlugins.listPluginTabs")
  if not li then return end
  local data = widget.getData("saPlugins.listPluginTabs." .. li)

  for pluginName, layoutName in pairs(self.pluginLayouts) do 
    widget.setVisible("lytPluginSettings." .. layoutName, data.pluginName == pluginName)
  end

  for pluginName, li in pairs(self.pluginSettingsButtons) do 
    widget.setChecked("saPlugins.listPluginTabs." .. li .. ".pluginSetting", false)
  end

  self.runCallback(data.pluginName, "__openTab")
end

function update(dt)
  promises:update()
  self.runCallbackForPlugins("update", dt)
end

_generalSpinnerCallback = {}

function _generalSpinnerCallback.up(widgetName, data)
  if data and data["actualPluginCallback"] then
    self.runCallbackForPlugins("_spinner_callback", data["actualPluginCallback"], "up", widgetName, data)
  end
end

function _generalSpinnerCallback.down(widgetName, data)
  if data and data["actualPluginCallback"] then
    self.runCallbackForPlugins("_spinner_callback", data["actualPluginCallback"], "down", widgetName, data)
  end
end

function _generalCallback(widgetName, data)
  if data and data["actualPluginCallback"] then
    self.runCallbackForPlugins("_callback", data["actualPluginCallback"], widgetName, data)
  end
end

function _generalTextBoxCallback(widgetName, data)
  if data and data["actualPluginCallback"] then
    self.runCallbackForPlugins("_textBoxCallback", data["actualPluginCallback"], widgetName, data, "callback")
  end
end

function _generalTextBoxCallbackEnter(widgetName, data)
  if data and data["actualPluginCallback"] then
    self.runCallbackForPlugins("_textBoxCallback", data["actualPluginCallback"], widgetName, data, "enterKey")
  end
end

function _generalTextBoxCallbackEscape(widgetName, data)
  if data and data["actualPluginCallback"] then
    self.runCallbackForPlugins("_textBoxCallback", data["actualPluginCallback"], widgetName, data, "escapeKey")
  end
end

function _generalCanvasClick(position, button, isDown)
  self.runCallbackForPlugins("_canvasClick", position, button, isDown)
end

function cursorOverride(screenPosition)
  self.runCallbackForPlugins("cursorOverride", screenPosition)
end

function toggleLanguageSelection()
  widget.setVisible("lytSelectLanguage", not widget.active("lytSelectLanguage"))
end

-- Utility function: return the index of a value in the given array
  function index(tab, value)
    for k, v in ipairs(tab) do
      if v == value then return k end
    end
    return 0
  end

function createTooltip(screenPosition)
  if self.tooltipFields then
    for widgetName, tooltip in pairs(self.tooltipFields) do
      if widget.inMember(widgetName, screenPosition) then
        return tooltip
      end
    end
  end

  if widget.getChildAt(screenPosition) then
    local w = widget.getChildAt(screenPosition)
    local wData = widget.getData(w:sub(2))
    if wData and type(wData) == "table" then
      if wData.pluginTabName then
        return starcustomchat.utils.getTranslation("settings.plugins." .. wData.pluginTabName)
      elseif wData.displayText then
        return starcustomchat.utils.getTranslation(wData.displayText)
      elseif wData.displayPlainText then
        return wData.displayPlainText
      end
    end
  end
end

function uninit()
  self.runCallbackForPlugins("uninit")
  save()
end