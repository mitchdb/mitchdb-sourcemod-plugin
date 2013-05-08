#pragma semicolon 1
#include <sourcemod>
#include <regex>
#include <cURL>
#include <steamtools>

#define USE_THREAD    1
#define USE_PROFILER    0

#if USE_PROFILER
  #include <profiler>
#endif

#define MDBVERSION "2.1.0-dev"

// Some default values for various things
#define MDB_BANLIST_DELAY 30.0
#define MDB_TIMEOUT 40
#define MDB_MINIMUM_STATUS_INTERVAL 45.0
#define MDB_MAXIMUM_NEW_PLAYER_TIME 45.0 // a player must be online for less than this amount of time if we are going to use the "player_join" 

// Define some max string sizes
#define STEAMID_SIZE 21 // STEAM_0:0:4294967295 (20 chars + null)
#define APIKEY_SIZE 33 // 32 + null
#define APISECRET_SIZE 33 // 32 + null

// API ENDPOINTS
#define MDB_URL_PING        "http://api.mitchdb.net/api/v2/ping"
#define MDB_URL_BANLIST     "http://api.mitchdb.net/api/v2/bans"
#define MDB_URL_STATUS      "http://api.mitchdb.net/api/v2/status_update"
#define MDB_URL_BAN         "http://api.mitchdb.net/api/v2/ban_player"
#define MDB_URL_UPDATE      "http://api.mitchdb.net/api/v2/check_update?version=%s"
#define MDB_URL_PLAYER_JOIN "http://api.mitchdb.net/api/v2/player_join"




public Plugin:myinfo = 
{
  name = "MitchDB",
  author = "Mitch Dempsey (WebDestroya)",
  description = "MitchDB.com Player Database Plugin",
  version = MDBVERSION,
  url = "http://www.mitchdb.com/"
};

new CURL_Default_opt[][2] = {
#if USE_THREAD
  {_:CURLOPT_NOSIGNAL,1},
#endif
  {_:CURLOPT_NOPROGRESS,1},
  {_:CURLOPT_TIMEOUT,40},
  {_:CURLOPT_CONNECTTIMEOUT,30},
  {_:CURLOPT_VERBOSE,0},
  {_:CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_0}
};

#define CURL_DEFAULT_OPT(%1) curl_easy_setopt_int_array(%1, CURL_Default_opt, sizeof(CURL_Default_opt))


new Handle:convar_mdb_apikey = INVALID_HANDLE; // ApiKey Console Variable
new Handle:convar_mdb_apisecret = INVALID_HANDLE; // Api Secret Console Variable
new Handle:convar_mdb_serverid = INVALID_HANDLE; // ServerID Console Variable
new Handle:convar_mdb_status_interval = INVALID_HANDLE; // StatusUpdate interval Console Variable

// Global Banlist
new Handle:g_BanList = INVALID_HANDLE;

new Handle:steamid_regex = INVALID_HANDLE;

// Extra utilities and things
#include <mitchdb/utils.sp>
#include <mitchdb/status.sp>
#include <mitchdb/bans.sp>
#include <mitchdb/banlist.sp>
#include <mitchdb/player_join.sp>
//#include <mitchdb/check_update.sp>
#include <mitchdb/stats.sp>
#include <mitchdb/ping.sp>


public OnPluginStart() {

  CreateConVar("mitchdb_version", MDBVERSION, "MitchDB", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

  // Some console variables we need
  convar_mdb_apikey = CreateConVar("mdb_apikey", "none", "The API key used to communicate with MitchDB", FCVAR_PROTECTED);
  convar_mdb_apisecret = CreateConVar("mdb_apisecret", "none", "The API secret used to communicate with MitchDB", FCVAR_PROTECTED);
  convar_mdb_serverid = CreateConVar("mdb_serverid", "0", "The MitchDB ServerID for this server.", FCVAR_PROTECTED);
  convar_mdb_status_interval = CreateConVar("mdb_status_update_interval", "60", "This is the interval in seconds that a status update should be sent to MitchDB. Set to 0 to disable.");
  
  HookConVarChange(convar_mdb_status_interval, OnMDBConVarChanged);

  // Hook the Bans
  RegServerCmd("banid", Command_Banid, "Hooked in order to capture RCON bans.");
  RegServerCmd("writeid", Command_Blocked, "This is not needed any more either");

  // Misc/utility commands
  RegAdminCmd("mdb_ping", Command_MDB_Ping, ADMFLAG_BAN|ADMFLAG_UNBAN, "This pings the MitchDB service to see if it is responding. (This will cause the server to lag for a few seconds)");
  //RegServerCmd("mdb_check_update", Command_MDB_CheckUpdate, "Checks to see if there is an available update for the MitchDB plugin.");

  RegServerCmd("mdb_status_update", Command_MDB_StatusUpdate, "Forces the status updater to run.");
  RegServerCmd("mdb_banlist_update", Command_MDB_BanListUpdate, "Forces the system to update the banlist.");

  RegServerCmd("mdb_addban", Command_MDB_AddBan, "This is used by the website to add a single ban");

  RegServerCmd("mdb_banlist", Command_MDB_BanList, "Displays the list of banned players (cached). Warning: This could return a very large list.");

  // Admin Commands
  RegAdminCmd("mdb_stats", Command_MDB_Stats, ADMFLAG_BAN|ADMFLAG_UNBAN, "Displays statistical information about the plugin.");
  RegAdminCmd("mdb_isbanned", Command_MDB_IsBanned, ADMFLAG_BAN|ADMFLAG_UNBAN, "Checks to see if a SteamID is banned.");  

  // Regex
  steamid_regex = CompileRegex("^STEAM_[0-5]:[0-9]:[0-9]+$");

  // this array store the list of steamids that are banned
  g_BanList = CreateArray(STEAMID_SIZE);

  AutoExecConfig(false, "mitchdb");

  // If we already have the cachefile on the filesystem, we should load that
  if(FileExists(MDB_BANLIST_FILE)) {
    LoadBanCacheFromFile();
  }
}

public OnPluginEnd() {
  // when closing the plugin, remove the banlist
  CloseHandle(g_BanList);
}

public OnMapEnd() {
  // kill the status update timer
  if(timer_statusupdate != INVALID_HANDLE) {
    KillTimer(timer_statusupdate);
    timer_statusupdate = INVALID_HANDLE;
  }
}


// We want all this stuff to run AFTER the configs. Otherwise, we will have the wrong api key
public OnConfigsExecuted() {
  // get the requested update interval
  new Float:statusInterval = GetConVarFloat(convar_mdb_status_interval);

  // Create a timer for the status update calls
  if( statusInterval >= MDB_MINIMUM_STATUS_INTERVAL && timer_statusupdate == INVALID_HANDLE) {
    timer_statusupdate = CreateTimer( statusInterval, UpdateStatusTimer, 0, TIMER_REPEAT);
  }

  // This should initiate the banlist download
  // This will delay the update. in 99% of the cases, this should be fine
  // If you REALLY WANT your banlist sooner, then run mdb_banlist_update
  CreateTimer( MDB_BANLIST_DELAY, RunBanlistUpdate);
}

// This is called when any of our convars are changed.
public OnMDBConVarChanged(Handle:convar, const String:oldVal[], const String:newVal[]) {

  // If the status interval is changed
  if(convar == convar_mdb_status_interval) {
    new Float:statusInterval = StringToFloat(newVal);

    // if the old timer is running then we need to kill it
    if(timer_statusupdate != INVALID_HANDLE) {
      KillTimer(timer_statusupdate);
      timer_statusupdate = INVALID_HANDLE;
    }

    // Timer is greater than the minimum allowed, so create one
    if(statusInterval >= MDB_MINIMUM_STATUS_INTERVAL) {
      timer_statusupdate = CreateTimer( statusInterval, UpdateStatusTimer, 0, TIMER_REPEAT);
    }

    return;
  }

  // The server id was changed
  if(convar == convar_mdb_serverid) {
    // TODO: Finish
    return;
  }

  // the API key is changed
  if(convar == convar_mdb_apikey) {
    // TODO: Finish

    return;
  }
}


// The user has joined, lets make sure they are not in our banlist
public OnClientAuthorized(client, const String:auth[]) {

  // Has this steamid been banned?
  if( IsSteamIdBanned(auth) ) {
    KickPlayer(client);
  }
}
