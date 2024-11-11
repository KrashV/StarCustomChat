local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

function onChatReceivePacket(data)
  local message = {
    nickname = data.receivedMessage.fromNick,
    mode = data.receivedMessage.context.mode,
    text = data.receivedMessage.text,
    connection = data.receivedMessage.fromConnection
  }

  shared.addMessageToSCC(message)
end

function onEntityMessagePacket(data)
  sb.logInfo("SEM")
  sb.logInfo(sb.print(data))
end

function onChatSendPacket(data)
  sb.logInfo("SENDCHAT")
  sb.logInfo(sb.print(data))
end