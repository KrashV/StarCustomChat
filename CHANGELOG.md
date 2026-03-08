## Features
Added the description to the pinging command
Added the ability to send the whisper message to your party
The players in @pinging list are now ordered by nearest
Reactions: Supported saving the most recent/popular reactions.
The CommandResult now shows the command it created, if available

## Bugfixes
Fixed rare cases when the message lost the linebreaks
Fixed the rare case of chat not changing the extended/compact mode on clicking
Fixed the canvas going out of the frame when opening the submenu
Adjusted the position of messages scrolled down to on pressing the Replied to area
Fixed the bug when the plugins with enabled stagehand functionality stopped working on servers without such stagehands.
Unknown reactions are now replaced with an "Unknown" reaction instead of the invisible one.

## API
Added new Plugin method to clear up the message object before saving it
Reworked the Direct Messages system. Now, by default, it tries to send an Entity Message. If fails, revokes to /w
Moved all message logging to one place
Moved all the related SubMenu closure to a separate method
onTextboxCallback method now passes the chat string
If message.tooltip exists, it will be show on message hover
Added the abilty to register the stagehand callbacks, turning on the server-sending functionality (see README.md)
Added the ability to create SCC commands support in other mods, see README.md