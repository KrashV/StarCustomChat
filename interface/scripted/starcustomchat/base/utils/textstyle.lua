
local function _styleOpenMarker(id)
  return "~[{" .. string.rep("!", id) .. "}]~"
end

local function _styleCloseMarker(id)
  return "~{/" .. string.rep("!", id) .. "}~"
end

local function _registerStyle(message, directives)
  message.sccStyleDirectives = message.sccStyleDirectives or {}
  table.insert(message.sccStyleDirectives, directives)
  return #message.sccStyleDirectives
end

function starcustomchat.utils.styleText(message, directives, text)
  if not message or not directives or not text then
    return text
  end

  local id = _registerStyle(message, directives)
  return _styleOpenMarker(id) .. text .. _styleCloseMarker(id)
end

function starcustomchat.utils.styleStart(message, directives)
  if not message or not directives then
    return ""
  end

  local id = _registerStyle(message, directives)
  return _styleOpenMarker(id)
end

local function _composeStyleStack(stack)
  if #stack == 0 then
    return "^reset;"
  end

  local directives = {}
  for _, style in ipairs(stack) do
    table.insert(directives, style.directives)
  end
  return table.concat(directives)
end

local function _popStyle(stack, id)
  if #stack == 0 then
    return
  end

  if stack[#stack].id == id then
    table.remove(stack)
    return
  end

  for i = #stack, 1, -1 do
    if stack[i].id == id then
      table.remove(stack, i)
      return
    end
  end
end

local function _appendText(output, text, stack)
  if text == "" then
    return
  end

  if #stack > 0 then
    text = text:gsub("%^reset;", function()
      return "^reset;" .. _composeStyleStack(stack)
    end)
  end

  table.insert(output, text)
end

function starcustomchat.utils.resolveStyleText(text, styleDirectives)
  if not text or not styleDirectives or #styleDirectives == 0 then
    return text
  end

  local output = {}
  local stack = {}
  local index = 1

  while index <= #text do
    local openStart, openEnd, openId = text:find("%~%[%{(!+)%}%]%~", index)
    local closeStart, closeEnd, closeId = text:find("%~%{%/(!+)%}%~", index)
    local markerStart, markerEnd, markerId, opening

    if openStart and (not closeStart or openStart < closeStart) then
      markerStart, markerEnd, markerId, opening = openStart, openEnd, openId, true
    elseif closeStart then
      markerStart, markerEnd, markerId, opening = closeStart, closeEnd, closeId, false
    else
      _appendText(output, text:sub(index), stack)
      break
    end

    if markerStart > index then
      _appendText(output, text:sub(index, markerStart - 1), stack)
    end

    local id = #markerId
    local directives = styleDirectives[id]
    if directives then
      if opening then
        table.insert(stack, { id = id, directives = directives })
        table.insert(output, directives)
      else
        _popStyle(stack, id)
        table.insert(output, _composeStyleStack(stack))
      end
    else
      table.insert(output, text:sub(markerStart, markerEnd))
    end

    index = markerEnd + 1
  end

  if #stack > 0 then
    table.insert(output, "^reset;")
  end

  return table.concat(output)
end

function starcustomchat.utils.resolveStyleStack(message)
  if type(message) ~= "table" or type(message.text) ~= "string" then
    return message
  end

  message.text = starcustomchat.utils.resolveStyleText(message.text, message.sccStyleDirectives)
  message.sccStyleDirectives = nil
  return message
end
