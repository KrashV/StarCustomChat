require"/scripts/util.lua"
require"/interface/scripted/starcustomchatsettings/colorpicker/data.lua"
require"/scripts/vec2.lua"
require"/scripts/rect.lua"

local img_path = '/interface/scripted/starcustomchatsettings/colorpicker/spectrumchart.png'
local img_size = root.imageSize(img_path)
local alpha_size = {img_size[1], 10}
local spectrum_size = {img_size[1], img_size[2] - alpha_size[2]}

local parent = _ENV
local _ENV = setmetatable({}, {__index = parent})

__index = _ENV
__name  = "colorpicker"

function new(name)
    local new = {
         wname = name
        ,color_mouse = img_size
        ,selected = 0
        ,selected_alpha = 255
        ,alpha_mouse = {alpha_size[1], alpha_size[2] // 2}
        ,mode = nil
        ,wid = widget.bindCanvas(name)
    }

    -- Override size to ensure the canvas can fit the whole chart.
    widget.setSize(name, img_size)

    -- Create a widget callback,
    --  named as either the one specified in the config or a default using the name.
    new.clickEvent = bind(clickEvent, new)
    local cb = config.getParameter("canvasClickCallbacks", {})[name] or name:gsub("%.", "_").."_clickEvent"
    parent[cb] = new.clickEvent

    new.wid:clear()
    new.wid:drawImage(img_path, {0,0})
    return setmetatable(new, _ENV)
end

local function getByte(value, byte)
    return (value >> (8*byte)) & 0xFF
end

-- Have to clamp x and y to prevent accessing out of the matrix bounds.
function updateColor(c, position)
    local x,y =
     util.clamp(position[1],0,img_size[1]-1)
    ,util.clamp(position[2] +alpha_size[2],0,img_size[2]-1)


    c.selected = (spectrum_data[x][y-alpha_size[2]] or 0) 
    c.color_mouse = {x,y}
end

function updateAlpha(c, position)
    local x =
     util.clamp(position[1],0,alpha_size[1])

    c.selected_alpha = math.floor(255 - 255 * (alpha_size[1] - x) / alpha_size[1])
    c.alpha_mouse = {x, alpha_size[2] // 2}
end

function clickEvent(c, _, button, isDown)
    if button == 0 then
        c.down = isDown
    end
end

function setColor(c, newColor)
    if newColor then
        local col, al
        if string.len(newColor) == 8 then
            col = tonumber(string.sub(newColor, 1, 6), 16)
            al = tonumber(string.sub(newColor, 7, 8), 16)
        elseif string.len(newColor) == 6 then
            col = tonumber(newColor, 16)
            al = 255
        end
        -- First, set the alpha
        c.selected_alpha = al
        c.alpha_mouse = {alpha_size[1] * (al / 255), alpha_size[2] // 2}

        -- Then, find the color
        for x, line in ipairs(spectrum_data) do 
            for y, value in ipairs(spectrum_data[x]) do 
                if value == col then
                    c.selected = value
                    c.color_mouse = {x,y + alpha_size[2] + 1}
                    return
                end
            end
        end
    end
end

-- If the mouse is down and inside the canvas, update the color.
function update(c)
    if c.down then
        local mouse = c.wid:mousePosition()
        local pos = widget.getPosition(c.wname)
        local spectrum_extrema = vec2.add(pos, spectrum_size)
        local r = rect.fromVec2(pos, spectrum_extrema)
        local spectrum_offset = vec2.sub(mouse, {0, alpha_size[2]})
        if rect.contains(r, vec2.add(pos, spectrum_offset)) and (not c.mode or c.mode == "color") then
            c:updateColor(spectrum_offset)
            c.mode = "color"
        else
            local alpha_extrema = vec2.add(pos, alpha_size)
            local r = rect.fromVec2(pos, alpha_extrema)
            if rect.contains(r, vec2.add(pos, mouse)) and (not c.mode or c.mode == "alpha")  then
                c:updateAlpha(mouse)
                c.mode = "alpha"
            end
        end
    else
        c.mode = nil
    end
end


function red(c)   return getByte(c.selected, 2) end
function green(c) return getByte(c.selected, 1) end
function blue(c)  return getByte(c.selected, 0) end
function alpha(c) return ("%02x"):format(c.selected_alpha) end


function rgb(c) return {c:red(), c:green(), c:blue()} end
function rgba(c) return {c:red(), c:green(), c:blue(), c:alpha()} end
function hex(c) return ("%06x"):format(c.selected) .. c:alpha() end

-- The hue and lightness are estimates using the chart
--  to compute accurate hsl you should use the rgb values.
function hue(c)
    return (c.color_mouse[1] / img_size[1])*360
end

function lightness(c)
    return 1 - (c.color_mouse[2] / img_size[2])
end

parent.colorpicker = _ENV
