-- Combobox class.lua
require "/scripts/vec2.lua"

Combobox = {
  widgetName = "",
  callback = function() end,
  values = {},
  defaultValue = nil
}

local comboboxes = {}

function Combobox:_new(widgetName, callback, values, defaultValue)
  local obj = {}
  obj.widgetName = widgetName
  obj.callback = callback
  obj.values = values or {}
  obj.defaultValue = defaultValue or nil

  setmetatable(obj, self)
  self.__index = self
  return obj
end

function Combobox:bind(widgetName, callback, values, defaultValue, filter, size, offset, listScema)

    if not widget.getChecked(widgetName) == nil then
        sb.logError("Combobox:bind - Widget '" .. widgetName .. "' does not exist or is not a button.")
        return nil
    end

    local cbUUID = sb.makeUuid()

    local backgroundSize = root.imageSize("/interface/scripted/combobox/background.png")

    local lytPosition = vec2.add(widget.getPosition(widgetName), offset or {0, 10})

    local layoutTemplate = {
        type = "layout",
        layoutType = "basic",
        size = backgroundSize,
        position = lytPosition,
        visible = false,
        children = {
            ["backgroundCombobox"] = {
                type = "image",
                file = "/interface/scripted/combobox/background.png"
            },
            ["scrollAreaCombobox"] = {
                type = "scrollArea",
                position = {0, 15},
                size = {backgroundSize[1], backgroundSize[2] - 15},
                children = {
                    ["listCombobox"] = {
                        type = "list",
                        callback = "comboboxSelect",
                        schema = listScema or {
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
        defaultValue = defaultValue,
        uuid = cbUUID
    }

    -- Add optional filter
    if filter then
        layoutTemplate.children["textComboboxFilter"] = {
            type = "textbox",
            position = {5, 2},
            hint = "...",
            color = "gray",
            callback = "comboboxFilter",
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
    comboboxes[cbUUID] = self:_new(parentFullWidgetName .. lytName, callback, values, defaultValue)


    widget.setData(parentFullWidgetName .. "lytCombobox" .. widgetName .. ".scrollAreaCombobox.listCombobox", {
        comboboxData = {
            name = widgetName,
            parentWidgetName = parentWidgetName,
            uuid = cbUUID
        }
    })

    comboboxes[cbUUID]:fillValues(nil, defaultValue)
    return comboboxes[cbUUID]
end

function Combobox:fillValues(searchText, defaultValue)
    widget.clearListItems(self.widgetName .. ".scrollAreaCombobox.listCombobox")

    for _, value in ipairs(self.values) do
        if not searchText or value:lower():find(searchText:lower(), nil, true) then
            local li = widget.addListItem(self.widgetName .. ".scrollAreaCombobox.listCombobox")
            widget.setText(self.widgetName .. ".scrollAreaCombobox.listCombobox." .. li .. ".option", value)
            widget.setData(self.widgetName .. ".scrollAreaCombobox.listCombobox." .. li, value)

            if defaultValue and value == defaultValue then
                widget.setListSelected(self.widgetName .. ".scrollAreaCombobox.listCombobox", li)
            end
        end
    end
end

function Combobox:toggle()
    widget.setVisible(self.widgetName, not widget.active(self.widgetName))
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
                cb.callback(widget.getData(widgetName .. ".scrollAreaCombobox.listCombobox." .. li))
            end
        end
    end
end

function comboboxFilter(widgetName, widgetData)
    if widgetData.comboboxData then
        if widgetData.comboboxData.parentWidgetName then
            widgetName = widgetData.comboboxData.parentWidgetName .. "." .. "lytCombobox" .. widgetData.comboboxData.name .. "." .. widgetName
        else
            widgetName = "lytCombobox." .. widgetData.comboboxData.name .. "." .. widgetName
        end

        local cb = getCombobox(widgetData.comboboxData.uuid)
        if cb then
            local searchText = widget.getText(widgetName)

            cb:fillValues(searchText)
        end
    end
end