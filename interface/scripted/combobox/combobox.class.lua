-- Combobox class.lua
require "/scripts/vec2.lua"

Combobox = {
  widgetName = "",
  callback = function() end,
  values = {},
  listMap = {},
  defaultValue = nil
}

local comboboxes = {}

function Combobox:_new(widgetName, callback, values, defaultValue, closeOnSelect)
  local obj = {}
  obj.widgetName = widgetName
  obj.callback = callback
  obj.values = values or {}
  obj.defaultValue = defaultValue or nil
  obj.closeOnSelect = closeOnSelect or false
  obj.listMap = {}

  setmetatable(obj, self)
  self.__index = self
  return obj
end

function Combobox:bind(widgetName, values, callback, options)
    options = options or {}

    if not widget.getChecked(widgetName) == nil then
        sb.logError("Combobox:bind - Widget '" .. widgetName .. "' does not exist or is not a button.")
        return nil
    end

    -- Reformat values to a table if it's an array
    for k, v in ipairs(values or {}) do
        values[k] = nil
        values[v or k] = v
    end

    local cbUUID = sb.makeUuid()

    local backgroundSize = options.size or root.imageSize("/interface/scripted/combobox/background.png")

    local lytPosition = vec2.add(widget.getPosition(widgetName), options.offset or {0, widget.getSize(widgetName)[2]})

    local layoutTemplate = {
        type = "layout",
        layoutType = "basic",
        size = backgroundSize,
        position = lytPosition,
        visible = false,
        children = {
            ["backgroundCombobox"] = {
                type = "image",
                file = "/interface/scripted/combobox/" .. (options.filter and "backgroundFilter.png" or "background.png"),
                zlevel = 0
            },
            ["scrollAreaCombobox"] = {
                type = "scrollArea",
                position = {0, options.filter and 20 or 0},
                size = {backgroundSize[1], backgroundSize[2] - (options.filter and 20 or 0)},
                zlevel = 2,
                children = {
                    ["listCombobox"] = {
                        type = "list",
                        zlevel = 3,
                        callback = "comboboxSelect",
                        schema = options.listScema or {
                            selectedBG = "/interface/scripted/combobox/listselected.png",
                            unselectedBG = "/interface/scripted/combobox/listunselected.png",
                            spacing = {0, 0},
                            memberSize = {backgroundSize[1], 15},
                            listTemplate = {
                                background = {
                                    type = "image",
                                    file = "/interface/scripted/combobox/listunselected.png"
                                },
                                option = {
                                    type = "label",
                                    position = {5, 2}
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    local isChild = widgetName:find("%.")
    local childWidgetName = widgetName:match("([^%.]+)$")
    local parentWidgetName = isChild and widgetName:match("(.+)%..+") or nil
    local parentFullWidgetName = parentWidgetName and (parentWidgetName .. ".") or ""

    local jsonPath = isChild and widgetName:gsub("%.", ".children.") or widgetName
    widgetConfig = sb.jsonQuery(config.getParameter("gui"), jsonPath)
    widgetName = childWidgetName

    -- Remove old widget
    if isChild then
        widget.removeChild(parentWidgetName, widgetName)
    else
        pane.removeWidget(widgetName)
    end

    -- Setup combobox config
    widgetConfig.callback = "comboboxClick"
    widgetConfig.data = widgetConfig.data or {}
    widgetConfig.data.comboboxData = {
        name = childWidgetName,
        parentWidgetName = parentWidgetName or "",
        values = values,
        defaultValue = options.defaultValue,
        uuid = cbUUID
    }

    -- Add optional filter
    if options.filter then
        layoutTemplate.children["textComboboxFilter"] = {
            type = "textbox",
            position = {5, 2},
            hint = options.filterHint or "...",
            color = "gray",
            callback = "comboboxFilter",
            zlevel = 4,
            data = {
                comboboxData = {
                    name = childWidgetName,
                    parentWidgetName = parentWidgetName or "",
                    uuid = cbUUID
                }
            }
        }
    end

    -- Add new widgets
    local lytName = "lytCombobox" .. widgetName
    if isChild then
        widget.addChild(parentWidgetName, widgetConfig, widgetName)
        widget.addChild(parentWidgetName, layoutTemplate, lytName)
    else
        pane.addWidget(widgetConfig, widgetName)
        pane.addWidget(layoutTemplate, lytName)
    end

    -- Create and store combobox
    comboboxes[cbUUID] = self:_new(parentFullWidgetName .. lytName, callback, values, options.defaultValue, options.closeOnSelect)


    widget.setData(parentFullWidgetName .. "lytCombobox" .. widgetName .. ".scrollAreaCombobox.listCombobox", {
        comboboxData = {
            name = widgetName,
            parentWidgetName = parentWidgetName,
            uuid = cbUUID
        }
    })

    comboboxes[cbUUID]:fillValues(nil, options.defaultValue)
    return comboboxes[cbUUID]
end

function Combobox:fillValues(searchText, defaultValue)
    widget.clearListItems(self.widgetName .. ".scrollAreaCombobox.listCombobox")

    for value, name in pairs(self.values) do
        if not searchText or value:lower():find(searchText:lower(), nil, true) then
            local li = widget.addListItem(self.widgetName .. ".scrollAreaCombobox.listCombobox")
            widget.setText(self.widgetName .. ".scrollAreaCombobox.listCombobox." .. li .. ".option", name)
            widget.setData(self.widgetName .. ".scrollAreaCombobox.listCombobox." .. li, value)

            if defaultValue and value == defaultValue then
                widget.setListSelected(self.widgetName .. ".scrollAreaCombobox.listCombobox", li)
            end

            self.listMap[value] = li
        end
    end
end

function Combobox:toggle()
    widget.setVisible(self.widgetName, not widget.active(self.widgetName))
end

function Combobox:close()
    widget.setVisible(self.widgetName, false)
end

function Combobox:open()
    widget.setVisible(self.widgetName, true)
end

function Combobox:setSelected(value)
    widget.setListSelected(self.widgetName .. ".scrollAreaCombobox.listCombobox", self.listMap[value] or "")
end

function getCombobox(uuid)
    if comboboxes[uuid] then
        return comboboxes[uuid]
    else
        sb.logError("Combobox with UUID '" .. uuid .. "' not found.")
        return Combobox:_new(callback)
    end
end

function comboboxClick(widgetName, widgetData)
    if widgetData.comboboxData then
        getCombobox(widgetData.comboboxData.uuid):toggle()      
    end
end

function comboboxSelect(widgetName, widgetData)
    if widgetData.comboboxData then
        
        if widgetData.comboboxData.parentWidgetName then
            widgetName = widgetData.comboboxData.parentWidgetName .. "." .. "lytCombobox" .. widgetData.comboboxData.name
        else
            widgetName = "lytCombobox" .. widgetData.comboboxData.name
        end

        local li = widget.getListSelected(widgetName .. ".scrollAreaCombobox.listCombobox")
        if li then
            local cb = getCombobox(widgetData.comboboxData.uuid)
            if cb and cb.callback then
                cb.callback(widget.getData(widgetName .. ".scrollAreaCombobox.listCombobox." .. li), widget.getText(widgetName .. ".scrollAreaCombobox.listCombobox." .. li))
                if cb.closeOnSelect then
                    cb:close()
                end
            end
        end
    end
end

function comboboxFilter(widgetName, widgetData)
    if widgetData.comboboxData then
        if widgetData.comboboxData.parentWidgetName and widgetData.comboboxData.parentWidgetName ~= "" then
            widgetName = widgetData.comboboxData.parentWidgetName .. "." .. "lytCombobox" .. widgetData.comboboxData.name .. "." .. widgetName
        else
            widgetName = "lytCombobox" .. widgetData.comboboxData.name .. "." .. widgetName
        end

        local cb = getCombobox(widgetData.comboboxData.uuid)
        if cb then
            local searchText = widget.getText(widgetName)

            cb:fillValues(searchText)
        end
    end
end