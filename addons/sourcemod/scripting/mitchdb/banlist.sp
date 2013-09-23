
#define MDB_BANLIST_FILE "data/mitchdb_banlist.dat"
#define MDB_BANLIST_TEMP_FILE "data/mitchdb_banlist.dat.tmp"

// This will download the banlist
public Action:RunBanlistUpdate(Handle:timer, any:data) {
  DownloadBanList();
}

// Check to see if a player is banned
public Action:Command_MDB_IsBanned(client, args) {

  // command was called with no arguments
  if(args < 1) {
    PrintToConsole(client, "Usage: mdb_isbanned <steamid>");
    PrintToConsole(client, " This can be used to tell you if a specific SteamID is currently on the banlist (cached).");
    PrintToConsole(client, " The banlist is reloaded every map change.");
    return Plugin_Handled;
  }

  decl String:steamid[STEAMID_SIZE];
  GetCmdArgString(steamid, sizeof(steamid));

  // they gave us the wrong format.
  if(!IsStringSteamId(steamid)) {
    PrintToConsole(client, "Invalid SteamID format");
    return Plugin_Handled;
  }

  #if USE_PROFILER
    new Handle:prof = CreateProfiler();
    StartProfiling(prof);
  #endif

  // Find them!
  new result = FindStringInArray(g_BanList, steamid);

  #if USE_PROFILER
    StopProfiling(prof);
    PrintToServer("[MitchDB] Profiler: SteamID lookup for %s took %f seconds. Result = %d", steamid, GetProfilerTime(prof), result);
    CloseHandle(prof);
  #endif
  
  if(result == -1) {
    // not found
    PrintToConsole(client, "The SteamID '%s' is NOT currently on the ban list.", steamid);
  } else {
    PrintToConsole(client, "The SteamID '%s' is currently BANNED.", steamid);
  }

  return Plugin_Handled;
}





// This allows an admin to force the server to send a status update.
public Action:Command_MDB_BanListUpdate(args) {
  PrintToServer("[MitchDB] Forcing the ban list to update with a fresh copy.");
  DownloadBanList();
  return Plugin_Handled;
}

/// Download Banlist
stock DownloadBanList() {
  
  // clear out the existing temp banlist file
  decl String:path[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, path, sizeof(path), MDB_BANLIST_TEMP_FILE);
  DeleteFile(path);

  decl String:apikey[APIKEY_SIZE];

  GetConVarString(convar_mdb_apikey, apikey, sizeof(apikey));

  new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, MDB_URL_BANLIST);
  Steam_SetHTTPRequestGetOrPostParameter(request, "api_key", apikey);

  Steam_SetHTTPRequestNetworkActivityTimeout(request, MDB_TIMEOUT);

  Steam_SendHTTPRequest(request, onCompleteMDBBanlist);
}

// Called when the banlist download finishes
public onCompleteMDBBanlist(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code) {
  if(!successful || code != HTTPStatusCode_OK) {
    LogToGame("[MitchDB] ERROR: There was a problem retreiving the banlist. (Server returned HTTP %d)", code);
  }
  

  // write the local banlist
  decl String:temp_path[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, temp_path, sizeof(temp_path), MDB_BANLIST_TEMP_FILE);
  Steam_WriteHTTPResponseBody(request, temp_path);

  // release the request
  Steam_ReleaseHTTPRequest(request);

  if(code != HTTPStatusCode_OK) {
    LogToGame("[MitchDB] ERROR: There was a problem downloading the banlist. Loading bans from cache instead. (Server returned HTTP %d)", code);

  } else {

    decl String:new_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, new_path, sizeof(new_path), MDB_BANLIST_FILE);

    // Response was good, so update the file
    DeleteFile(MDB_BANLIST_FILE);

    // rename the old one
    RenameFile(MDB_BANLIST_FILE, MDB_BANLIST_TEMP_FILE);
  }

  // Load the bans
  LoadBanCacheFromFile();
}

// This reads the banlist from a file, and loads it into memory
stock LoadBanCacheFromFile() {

  decl String:new_path[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, new_path, sizeof(new_path), MDB_BANLIST_FILE);

  if(!FileExists(new_path)) {
    LogToGame("[MitchDB] ERROR: Could not load ban cache from filesystem.");
    return;
  }

  #if USE_PROFILER
    new Handle:prof = CreateProfiler();
    StartProfiling(prof);
  #endif

  // open our file
  new Handle:banfile = OpenFile(new_path, "r");


  decl String:line[STEAMID_SIZE];

  // Clear the existing banlist
  ClearArray(g_BanList);

  // Loop thru the file (line by line)
  while(ReadFileLine(banfile, line, sizeof(line))) {
    TrimString(line);
    PushArrayString(g_BanList, line);
  }

  // cleanup
  CloseHandle(banfile);

  LogToGame("[MitchDB] Loaded %d bans from cache.", GetArraySize(g_BanList));

  #if USE_PROFILER
    StopProfiling(prof);
    LogToGame("MITCHDB PROFILE: LoadBanCache: %f sec", GetProfilerTime(prof));
    CloseHandle(prof);
  #endif

  // make sure that any banned players that are ingame are booted
  KickBannedPlayers();
}




// This will display the cached banlist
public Action:Command_MDB_BanList(args) {
  PrintToServer("[MitchDB] Displaying cached banlist...");
  
  new blsize = GetArraySize(g_BanList);

  decl String:steamid[STEAMID_SIZE];
  for(new i=0;i<blsize;i++) {
    GetArrayString(g_BanList, i, steamid, sizeof(steamid));
    PrintToServer("[MitchDB] (#%d) %s", (i+1), steamid);
  }
  PrintToServer("[MitchDB] Displaying %d cached bans", blsize);

  return Plugin_Handled;
}




// This is used only by MitchDB.com. When a ban is submitted, we want to be able to add the user to the list.
public Action:Command_MDB_AddBan(args) {

  // this shouldnt happen
  if(GetCmdArgs() == 0) {
    PrintToServer("Invalid command format. This command should only be called by MitchDB.");
    return Plugin_Handled;
  }

  decl String:steamid[STEAMID_SIZE];
  GetCmdArgString(steamid, sizeof(steamid));

  // if they are already banned, then just bail out
  if(IsSteamIdBanned(steamid)) {
    return Plugin_Handled;
  }

  // add to banlist
  PushArrayString(g_BanList, steamid);

  // are they currently playing on the server?
  new clientid = ClientIDFromSteamID(steamid);

  // if we are adding a ban for someone who is currently in game, we should kick them
  if(clientid != 0) {
    KickPlayer(clientid);
  }
  return Plugin_Handled;
}
