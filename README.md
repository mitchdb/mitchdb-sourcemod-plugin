# MitchDB SourceMod Plugin
This plugin allows a game server to communicate with the MitchDB API.
This plugin interfaces to the MitchDB service and will report player information which can be searched at any time. It also records any bans made by admins. Bans are submitted to the database and can be viewed by other admins.


## Requirements
* A [MitchDB](http://www.mitchdb.com/) account with at least one server added.
* [SourceMod](http://www.sourcemod.net/)
* [sourcemod-curl-extension](http://code.google.com/p/sourcemod-curl-extension/)



## Configuration
This plugin requires the following console variables to be specified:

* `mdb_apikey` - This should be set to your MitchDB API Key.
  * You can obtain this key by accessing your account and clicking on the "Servers" tab.
* `mdb_apisecret` - This should be set to your MitchDB API Secret. 
  * You can obtain this by accessing your account and clicking on the "Servers" tab.
* `mdb_serverid` - This should be the MitchDB server ID for the server you are using.
  * Each server in your account has a different ID.
* `mdb_status_update_interval` - This is the frequency that status updates should be sent to MitchDB (in seconds). 
  * This must be more than 45. Enter 0 to disable.
  * Default: 60 seconds

### Server Commands
* `mdb_banlist` - This will display a list of banned SteamIDs from the cache. Note: This will display the entire banlist. (Could be large)
* `mdb_banlist_update` - This will force the ban list to be updated
* `mdb_status_update` - This will force the status update to run

### Admin Commands
* `mdb_ping` - This sends a test ping to the MitchDB API. It checks to see if the service is available, and if your plugin is properly configured
* `mdb_stats` - This shows some statistics about the plugin. 
* `mdb_isbanned <SteamID>` - This will show whether or not a specific SteamID is currently on the cached banlist. (It does not check whether they are banned on MitchDB).

### Other Commands
The commands listed below are generally used by MitchDB API only. They are not meant to be used by admins.

* `mdb_addban <SteamID>` - This is used only by MitchDB. This adds a SteamID to the cached banlist.

### Console Variables
* `mitchdb_version` - This console variable will show the current version of the MitchDB plugin.

## Help & Support
If you have trouble with this plugin, please contact MitchDB support. If you find bugs/issues with this plugin, feel free to [submit an issue](https://github.com/mitchdb/mitchdb-sourcemod-plugin/issues) to the GitHub issue tracker.

## Development
You can use `make compile` to compile the plugin. If you want to create a Zip archive to install on your game server, you can run `make zip` which will create a zip archive inside the `build/` folder.
