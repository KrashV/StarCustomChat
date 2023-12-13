require "/stagehands/irden/irdencustomchathandler.lua"

function init()
  if Outbox then
    self.outbox = Outbox.new("outbox", ContactList.new("contacts"))
  end

  -- That's new
  iccstagehand_init()
end

function uninit()
  if self.outbox then
    self.outbox:uninit()
  end
end

function update(dt)
  if self.outbox then
    self.outbox:update()

    if self.outbox:empty() or not(iccstagehand_update) then
      stagehand.die()
    end
  end
  
  iccstagehand_update(dt)
end

function post(contacts, messages)
  if self.outbox then
    self.outbox.contactList:registerContacts(contacts)
    for _,messageData in ipairs(messages) do
      self.outbox:logMessage(messageData, "mailbox received")
      self.outbox:postpone(messageData)
    end
  end
end
