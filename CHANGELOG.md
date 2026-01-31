## Features
Added the description to the pinging command
Added the ability to send the whisper message to your party
The players in @pinging list are now ordered by nearest
Reactions: Supported saving the most recent/popular reactions.

## Bugfixes
Fixed rare cases when the message lost the linebreaks
Fixed the rare case of chat not changing the extended/compact mode on clicking

## API
Added new Plugin method to clear up the message object before saving it
Reworked the Direct Messages system. Now, by default, it tries to send an Entity Message. If fails, revokes to /w
Moved all message logging to one place