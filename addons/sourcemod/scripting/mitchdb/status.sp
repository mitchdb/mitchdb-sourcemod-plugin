// Handle for the status update (that periodically notifies of all users on the system)
new Handle:timer_statusupdate = INVALID_HANDLE;
new bool:statusupdate_running = false;

// This will call the status update
public Action:UpdateStatusTimer(Handle:timer, any:data) {
  SendStatusUpdate();
}


// This allows an admin to force the server to send a status update.
public Action:Command_MDB_StatusUpdate(args) {
  if(statusupdate_running) {
    PrintToServer("[MitchDB] The status update is currently running. Resetting.");
    statusupdate_running = false;
  }
  PrintToServer("[MitchDB] Forcing the status update to run.");
  TriggerTimer(timer_statusupdate, true);
  return Plugin_Handled;
}

// This sends a status update to MitchDB.
stock SendStatusUpdate() {
  if(mdb_verbose) {
    LogToGame("[MitchDB] Running status update...");
  }
  statusupdate_running = true;
  
  decl String:apikey[APIKEY_SIZE];
  decl String:serverid[11];
  decl String:currentMap[50];
  decl String:sourcemodVersion[50];
  decl String:metamodVersion[50];
  
  GetCurrentMap(currentMap, sizeof(currentMap));
  GetConVarString(convar_mdb_apikey, apikey, sizeof(apikey));
  GetConVarString(convar_mdb_serverid, serverid, sizeof(serverid));
  GetConVarString(FindConVar("sourcemod_version"), sourcemodVersion, sizeof(sourcemodVersion));
  GetConVarString(FindConVar("metamod_version"), metamodVersion, sizeof(metamodVersion));

  new clientct = GetMaxClients();
  new formindex = 0;

  new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, MDB_URL_STATUS);
  Steam_SetHTTPRequestGetOrPostParameter(request, "api_key", apikey);
  Steam_SetHTTPRequestGetOrPostParameter(request, "server_id", serverid);
  Steam_SetHTTPRequestGetOrPostParameter(request, "map", currentMap);
  Steam_SetHTTPRequestGetOrPostParameter(request, "version[mitchdb]", MDBVERSION);
  Steam_SetHTTPRequestGetOrPostParameter(request, "version[sourcemod]", sourcemodVersion);
  Steam_SetHTTPRequestGetOrPostParameter(request, "version[metamod]", metamodVersion);

  decl String:steamid[STEAMID_SIZE];

  decl String:playerIP[16];
  decl String:playerName[100];
  decl String:playerUserid[10];
  decl String:playerTime[20];

  decl String:fieldName[32];

  for(new i=1;i<=clientct;i++) {
    if(IsClientAuthorized(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i)) {

      GetClientAuthString(i, steamid, sizeof(steamid));
      GetClientName(i, playerName, sizeof(playerName));
      GetClientIP(i, playerIP, sizeof(playerIP));
      
      // Player Name
      Format(fieldName, sizeof(fieldName), "player[%d][name]", formindex);
      Steam_SetHTTPRequestGetOrPostParameter(request, fieldName, playerName);

      // IP address
      Format(fieldName, sizeof(fieldName), "player[%d][ip]", formindex);
      Steam_SetHTTPRequestGetOrPostParameter(request, fieldName, playerIP);

      // steamid
      Format(fieldName, sizeof(fieldName), "player[%d][steamid]", formindex);
      Steam_SetHTTPRequestGetOrPostParameter(request, fieldName, steamid);

      // client time
      Format(fieldName, sizeof(fieldName), "player[%d][time]", formindex);
      if(IsClientInGame(i)) {
        Format(playerTime, sizeof(playerTime), "%f", GetClientTime(i));
        Steam_SetHTTPRequestGetOrPostParameter(request, fieldName, playerTime);
      } else {
        Steam_SetHTTPRequestGetOrPostParameter(request, fieldName, "0");
      }
      
      // userid?
      Format(fieldName, sizeof(fieldName), "player[%d][userid]", formindex);
      Format(playerUserid, sizeof(playerUserid), "%d", GetClientUserId(i));
      Steam_SetHTTPRequestGetOrPostParameter(request, fieldName, playerUserid);

      formindex++;
    }
  }

  decl String:playerCounts[8]; // "current/max"
  Format(playerCounts, sizeof(playerCounts), "%d/%d", formindex, GetMaxClients());

  Steam_SetHTTPRequestGetOrPostParameter(request, "players", playerCounts);

  Steam_SetHTTPRequestNetworkActivityTimeout(request, MDB_TIMEOUT);
  Steam_SendHTTPRequest(request, StatusUpdateCompleted);
}

// Status update completion
public StatusUpdateCompleted(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code) {
  statusupdate_running = false;
  Steam_ReleaseHTTPRequest(request);

  if(!successful || code != HTTPStatusCode_OK) {
    LogToGame("[MitchDB] ERROR: There was a problem submitting the status update. (Server returned HTTP %d)", code);
    return;
  }
  
  if(mdb_verbose) {
    LogToGame("[MitchDB] Status update completed...");
  }
}
