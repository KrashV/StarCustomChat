require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"

function init()

  self.localePluginConfig = {}
  local plugins = {}

  self.chatMode = root.getConfiguration("iccMode") or "modern"
  self.currentLanguage = root.getConfiguration("iccLocale") or "en"

  self.availableLocales = root.assetJson("/interface/scripted/starcustomchat/languages/locales.json")
  self.availableModes = {"compact", "modern"}

  -- Load plugins
  for i, pluginName in ipairs(config.getParameter("enabledPlugins", {})) do 
    local pluginConfig = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", pluginName, pluginName))

    if pluginConfig.settingsScript then
      require(pluginConfig.settingsScript)

      if not _ENV[pluginName] then
        sb.logError("Failed to load settings plugin %s", pluginName)
      else
        local classInstance = _ENV[pluginName]:new()
        table.insert(plugins, classInstance)
      end
    end

    if pluginConfig.localeKeys then
      self.localePluginConfig = sb.jsonMerge(self.localePluginConfig, pluginConfig.localeKeys)
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

  self.pluginLayouts = {}
  for layoutName, layoutConfig in pairs(config.getParameter("gui")["lytPluginSettings"]["children"]) do 
    self.pluginLayouts[layoutConfig.data.pluginName] = layoutName
  end

  self.runCallbackForPlugins("init", starcustomchat.locale)
  localeSettings()
  
end

function localeSettings()
  starcustomchat.utils.buildLocale(self.localePluginConfig)
  widget.setText("btnLanguage", starcustomchat.utils.getTranslation("name"))
  widget.setText("btnMode", starcustomchat.utils.getTranslation("settings.modes." .. self.chatMode))
  pane.setTitle(starcustomchat.utils.getTranslation("settings.title"), starcustomchat.utils.getTranslation("settings.subtitle"))
  self.runCallbackForPlugins("onLocaleChange", self.localePluginConfig)
end



function save()
  self.runCallbackForPlugins("save", starcustomchat.locale)
  world.sendEntityMessage(player.id(), "icc_reset_settings")
end

function changePluginPage(_, data)
  for pluginName, layoutName in pairs(self.pluginLayouts) do 
    widget.setVisible("lytPluginSettings." .. layoutName, data.pluginName == pluginName)
  end
end

function update(dt)
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

function _generalCanvasClick(position, button, isDown)
  self.runCallbackForPlugins("_canvasClick", position, button, isDown)
end

function cursorOverride(screenPosition)
  self.runCallbackForPlugins("cursorOverride", screenPosition)
end

function changeLanguage()
  local i = index(self.availableLocales, self.currentLanguage)
  self.currentLanguage = self.availableLocales[(i % #self.availableLocales) + 1]
  root.setConfiguration("iccLocale", self.currentLanguage)
  
  localeSettings()
  save()
end


function changeMode()
  local i = index(self.availableModes, self.chatMode)
  self.chatMode = self.availableModes[(i % #self.availableModes) + 1]
  root.setConfiguration("iccMode", self.chatMode)
  widget.setText("btnMode", starcustomchat.utils.getTranslation("settings.modes." .. self.chatMode))
  save()
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
      end
    end
  end
end

function uninit()
  self.runCallbackForPlugins("uninit")
  save()
end