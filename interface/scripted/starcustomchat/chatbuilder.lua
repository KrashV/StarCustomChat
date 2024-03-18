-- This function dinamically builds the chat interfaces based on the enabled and disabled modes

require "/scripts/util.lua"


function buildChatInterface()

  local function sortByPriority(tbl)
    table.sort(tbl, function(a, b) 
      local a_priority = a.priority or 999999
      local b_priority = b.priority or 999999
      return a_priority < b_priority
    end)
  end


  local baseInterface = root.assetJson("/interface/scripted/starcustomchat/base/chatgui.json")
  local enabledPlugins = root.assetJson("/scripts/starcustomchat/enabledplugins.json")
  local disabledModes = root.assetJson("/scripts/starcustomchat/disabledmodes.json")

  -- First, collect all the modes from the plugins
  local chatModes = {}
  baseInterface["chatModes"] = {}
  baseInterface["contextMenuButtons"] = {}
  baseInterface["enabledPlugins"] = {}
  for _, pluginName in ipairs(enabledPlugins) do 
    local pluginConfig = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", pluginName, pluginName))
    table.insert(baseInterface["enabledPlugins"], pluginName)
    
    if pluginConfig.modes then
      for _, mode in ipairs(pluginConfig.modes) do
        if not disabledModes[mode.name] then
          table.insert(baseInterface["chatModes"], mode.name)
          table.insert(chatModes, mode)
        end
      end
    end

    if pluginConfig.contextMenuButtons then
      for _, btnConfig in ipairs(pluginConfig.contextMenuButtons) do
        table.insert(baseInterface["contextMenuButtons"], btnConfig)
      end
    end

    if pluginConfig.guiAddons then
      baseInterface["gui"] = sb.jsonMerge(baseInterface["gui"], pluginConfig.guiAddons)
    end
  end

  -- Then sort the modes by tab priority
  sortByPriority(chatModes)

  -- Then sort the modes by tab priority
  sortByPriority(baseInterface["contextMenuButtons"])

  -- Then add the modes to the radio group
  local tab_id = 1
  local toggle_id = 1

  local function modesThatHaveTabs(modes)
    local n = 0
    for _, mode in ipairs(modes) do 
      n = (mode.has_tab and (not mode.admin or player.isAdmin())) and n + 1 or n 
    end
    return n 
  end

  local totalNModes = modesThatHaveTabs(chatModes)
  local tabWidth = root.imageSize(string.format("/interface/scripted/starcustomchat/base/tabmodes/chatmode%d.png", totalNModes))[1]

  for _, mode in ipairs(chatModes) do
    if mode.has_tab and (not mode.admin or player.isAdmin()) then
      table.insert(baseInterface["gui"]["rgChatMode"]["buttons"], {
        id = tab_id,
        baseImage = string.format("/interface/scripted/starcustomchat/base/tabmodes/chatmode%d.png", totalNModes),
        hoverImage = string.format("/interface/scripted/starcustomchat/base/tabmodes/chatmode%d.png?brightness=30", totalNModes),
        baseImageChecked = string.format("/interface/scripted/starcustomchat/base/tabmodes/chatmode%dselected.png", totalNModes),
        hoverImageChecked = string.format("/interface/scripted/starcustomchat/base/tabmodes/chatmode%dselected.png?brightness=30", totalNModes),
        pressedOffset = {0, 0},
        position = {(tab_id - 1) * tabWidth, 0},
        selected = tab_id == 1,
        data = {
          mode = mode.name
        }
      })
      tab_id = tab_id + 1
    end

    if mode.has_toggle then
      local checked = true
      if mode.checked ~= nil then
          checked = mode.checked
      end

    
      baseInterface["gui"]["btnCk" .. mode.name] = {
        type = "button",
        checkable = true,
        checked = checked,
        position = {289, 6 + 15 * (toggle_id - 1)},
        pressedOffset = {0, 0},
        base = "/interface/scripted/starcustomchat/base/chatmodedisabled.png",
        hover = "/interface/scripted/starcustomchat/base/chatmodedisabled.png",
        baseImageChecked = "/interface/scripted/starcustomchat/base/chatmodeenabled.png",
        hoverImageChecked = "/interface/scripted/starcustomchat/base/chatmodeenabled.png",
        callback = "modeToggle",
        data = {
          mode = mode.name,
          tooltipMode = mode.name
        }
      }
      toggle_id = toggle_id + 1
    end
  end

  baseInterface.expanded = root.getConfiguration("icc_is_expanded")
  baseInterface["gui"]["background"]["fileBody"] = string.format("/interface/scripted/starcustomchat/base/%s.png", baseInterface.expanded and "body" or "shortbody")
  return baseInterface
end

function buildSettingsInterface()
  local function mergeArrays(t1, t2)
    if t2 == nil then return t1 end
    for _,v in ipairs(t2) do 
      table.insert(t1, v)
    end
    return t1
  end

  local baseSettingsInterface = root.assetJson("/interface/scripted/starcustomchatsettings/starcustomchatsettingsgui.json")

  local enabledPlugins = root.assetJson("/scripts/starcustomchat/enabledplugins.json")

  local pluginPageId = 0
  local tabOffset = {0, -15}
  local tabPosition = {0, 0}

  for i, pluginName in ipairs(enabledPlugins) do 
    local pluginConfig = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", pluginName, pluginName))

    if pluginConfig.settingsPage then
      local layoutWidget = {
        type = "layout",
        layoutType = "basic",
        rect = {0, 0, 500, 500},
        children = {},
        visible = i == 1
      }

      baseSettingsInterface["gui"]["lytPluginSettings"]["children"]["pluginSettings" .. pluginName] = copy(layoutWidget)
      local layout = baseSettingsInterface["gui"]["lytPluginSettings"]["children"]["pluginSettings" .. pluginName]

      layout["data"] = {
        pluginName = pluginName
      }
      local function processWidgets(widgets)
        for widgetName, widgetConfig in pairs(widgets or {}) do 
            if widgetConfig.type == "spinner" then
                local callbackName = widgetConfig.callback or widgetName
                
                widgetConfig.data = sb.jsonMerge(widgetConfig.data or {}, {
                    actualPluginCallback = {
                        pluginName = pluginName,
                        callback = callbackName
                    }
                })
                widgetConfig.callback = "_generalSpinnerCallback"
            elseif widgetConfig.callback and widgetConfig.callback ~= "null" then
                widgetConfig.data = sb.jsonMerge(widgetConfig.data or {}, {
                    actualPluginCallback = {
                        pluginName = pluginName,
                        callback = widgetConfig.callback
                    }
                })
                widgetConfig.callback = "_generalCallback"
            elseif widgetConfig.type == "canvas" and widgetConfig.captureMouseEvents then
                baseSettingsInterface["canvasClickCallbacks"][widgetName] = "_generalCanvasClick"
            end
            layout["children"][widgetName] = widgetConfig
            
            -- If this widget has its own children, process them recursively
            if widgetConfig.children then
                processWidgets(widgetConfig.children)
            end
        end
    end
    
    -- Initial call to process the top-level widgets
    processWidgets(pluginConfig.settingsPage["gui"])
    

      table.insert(baseSettingsInterface["gui"]["rgPluginTabs"]["buttons"], {
        id = pluginPageId,
        selected = pluginPageId == 0,
        baseImage = pluginConfig.settingsPage["tabButtons"]["baseImage"],
        hoverImage = pluginConfig.settingsPage["tabButtons"]["hoverImage"],
        baseImageChecked = pluginConfig.settingsPage["tabButtons"]["baseImageChecked"],
        hoverImageChecked = pluginConfig.settingsPage["tabButtons"]["hoverImageChecked"],
        position = tabPosition,
        data = {
          pluginName = pluginName,
          pluginTabName = pluginName
        }
      })
      pluginPageId = pluginPageId + 1
      tabPosition = vec2.add(tabPosition, tabOffset)
    end
  end
  return baseSettingsInterface
end