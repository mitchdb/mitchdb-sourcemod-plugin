// Handle for the status update (that periodically notifies of all users on the system)
new Handle:timer_statusupdate = INVALID_HANDLE;
new bool:statusupdate_running = false;
//new status_concurrent_requests = 0;
// static counter for how many times we have called this and it was already running
// new already_running_count = 0;

// This will call the status update
public Action:UpdateStatusTimer(Handle:timer, any:data) {
  SendStatusUpdate();
}


// This allows an admin to force the server to send a status update.
public Action:Command_MDB_StatusUpdate(args) {
  if(statusupdate_running) {
    PrintToServer("[MitchDB] The status update is currently running. Resetting.");
    statusupdate_running = false;
    // already_running_count = 0;
  }
  PrintToServer("[MitchDB] Forcing the status update to run.");
  TriggerTimer(timer_statusupdate, true);
  return Plugin_Handled;
}

// This sends a status update to MitchDB.
stock SendStatusUpdate() {
  /*
  // if the update is already running, then bail out.
  if(statusupdate_running) {
    LogToGame("[MitchDB] Error: Status update task is already running.");

    // if we have failed a bunch, we should reset the counter
    if(already_running_count > 0) {
      LogToGame("[MitchDB] Error: Status Update process attempt %d.", already_running_count);

      // It has failed more than 5 times. at ths point, lets reset the counter
      // and have it try again.
      if(already_running_count > 4) {
        LogToGame("[MitchDB] Error: Status Update process has failed %d times. Resetting status.", already_running_count);
        already_running_count = 0;
        statusupdate_running = false;
      } else {
        // ok, we havent failed 5 times, so update the fail count
        already_running_count++;
      }
    } else {
      already_running_count++;
    }
    
    return;
  }

  // set the status of the updater
  statusupdate_running = true;

  // ensure that we only have one running at a time.
  already_running_count = 0;
  */

  if(mdb_verbose) {
    LogToGame("[MitchDB] Running status update...");
  }

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

  Steam_SendHTTPRequest(request, StatusUpdateCompleted);
}

// Status update completion
public StatusUpdateCompleted(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code) {
  statusupdate_running = false;
  Steam_ReleaseHTTPRequest(request);
  //already_running_count = 0;

  if(mdb_verbose) {
    LogToGame("[MitchDB] Status update completed...");
  }

  if(successful!=true) {
    LogToGame("[MitchDB] ERROR: Network error contacting API. [httpcode=%d] (status update)", code);
    return;
  }

  if(code != HTTPStatusCode_OK) {
    LogToGame("[MitchDB] ERROR: There was a problem submitting the status update. (Server returned HTTP %d)", code);
  }
}
