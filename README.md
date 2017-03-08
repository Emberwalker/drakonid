# Drakonid
Dumb and simple (for now) Discord bot.

## Adding to a Server
Edit the following link, replacing `CLIENT_ID` with your app ID.
```
https://discordapp.com/oauth2/authorize?client_id=CLIENT_ID&scope=bot&permissions=76800
```

## Setting Global Administrator
The Global Administrator is the assigned 'owner' of the bot, with all-access admin rights in addition to privileged
management commands, such as `!stop`. To get the ID, enable Developer Mode in Discord and right-click the user, and
select `Copy ID`.

## Running on Windows
The required files for voice support are now bundled in the repository. Run `drakonid_windows.rb` instead of
`drakonid.rb` to get the voice comms goodness.