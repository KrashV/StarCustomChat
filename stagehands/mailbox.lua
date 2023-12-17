require "/stagehands/irden/irdencustomchathandler.lua"

function init()
  if not Outbox then
    stagehand.die()
    return
  end
  self.outbox = Outbox.new("outbox", ContactList.new("contacts"))

  self.irdenStagehand = stagehand.typeName() == "irdencustomchat"
  if self.irdenStagehand then
    iccstagehand_init()
  end
end

function uninit()
  if not self.outbox then
    return
  end
  self.outbox:uninit()
end

function update(dt)
  if not self.outbox then
    stagehand.die()
    return
  end
  self.outbox:update()

  if self.outbox:empty() and not self.irdenStagehand then
    stagehand.die()
  end

  if self.irdenStagehand then
    iccstagehand_update(dt)
  end
end

function post(contacts, messages)
  self.outbox.contactList:registerContacts(contacts)
  for _,messageData in ipairs(messages) do
    self.outbox:logMessage(messageData, "mailbox received")
    self.outbox:postpone(messageData)
  end
end
