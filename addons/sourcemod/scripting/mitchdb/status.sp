// Handle for the status update (that periodically notifies of all users on the system)
new Handle:timer_statusupdate = INVALID_HANDLE;
new bool:statusupdate_running = false;
//new status_concurrent_requests = 0;
#if USE_PROFILER
  //new Handle:statusupdate_profiler = INVALID_HANDLE;
#endif
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
  SendStatusUpdate();
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
  

  new Handle:curl = curl_easy_init();
  if(curl == INVALID_HANDLE) {
    CurlError("status update");
    return;
  }
  CURL_DEFAULT_OPT(curl);

  #if USE_PROFILER
    new Handle:statusupdate_profiler = CreateProfiler();
    StartProfiling(statusupdate_profiler);
  #endif

  decl String:apikey[APIKEY_SIZE];
  decl String:serverid[45];
  decl String:currentMap[50];
  decl String:sourcemodVersion[50];
  decl String:metamodVersion[50];
  decl String:curlVersion[256];
  curl_version(curlVersion, sizeof(curlVersion));

  GetCurrentMap(currentMap, sizeof(currentMap));
  GetConVarString(convar_mdb_apikey, apikey, sizeof(apikey));
  GetConVarString(convar_mdb_serverid, serverid, sizeof(serverid));
  GetConVarString(FindConVar("sourcemod_version"), sourcemodVersion, sizeof(sourcemodVersion));
  GetConVarString(FindConVar("metamod_version"), metamodVersion, sizeof(metamodVersion));

  new clientct = GetMaxClients();
  new formindex = 0;

  new Handle:statusupdate_form = curl_httppost();
  curl_formadd(statusupdate_form, CURLFORM_COPYNAME, "api_key", CURLFORM_COPYCONTENTS, apikey, CURLFORM_END);
  curl_formadd(statusupdate_form, CURLFORM_COPYNAME, "server_id", CURLFORM_COPYCONTENTS, serverid, CURLFORM_END);
  curl_formadd(statusupdate_form, CURLFORM_COPYNAME, "map", CURLFORM_COPYCONTENTS, currentMap, CURLFORM_END);
  curl_formadd(statusupdate_form, CURLFORM_COPYNAME, "version[mitchdb]", CURLFORM_COPYCONTENTS, MDBVERSION, CURLFORM_END);
  curl_formadd(statusupdate_form, CURLFORM_COPYNAME, "version[sourcemod]", CURLFORM_COPYCONTENTS, sourcemodVersion, CURLFORM_END);
  curl_formadd(statusupdate_form, CURLFORM_COPYNAME, "version[metamod]", CURLFORM_COPYCONTENTS, metamodVersion, CURLFORM_END);
  curl_formadd(statusupdate_form, CURLFORM_COPYNAME, "version[curl]", CURLFORM_COPYCONTENTS, curlVersion, CURLFORM_END);

  decl String:steamid[STEAMID_SIZE];

  decl String:playerIP[16];
  decl String:playerName[100];
  decl String:playerCountry[4];
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
      curl_formadd(statusupdate_form, CURLFORM_COPYNAME, fieldName, CURLFORM_COPYCONTENTS, playerName, CURLFORM_END);

      // IP address
      Format(fieldName, sizeof(fieldName), "player[%d][ip]", formindex);
      curl_formadd(statusupdate_form, CURLFORM_COPYNAME, fieldName, CURLFORM_COPYCONTENTS, playerIP, CURLFORM_END);

      // steamid
      Format(fieldName, sizeof(fieldName), "player[%d][steamid]", formindex);
      curl_formadd(statusupdate_form, CURLFORM_COPYNAME, fieldName, CURLFORM_COPYCONTENTS, steamid, CURLFORM_END);

      // client time
      Format(fieldName, sizeof(fieldName), "player[%d][time]", formindex);
      if(IsClientInGame(i)) {
        Format(playerTime, sizeof(playerTime), "%f", GetClientTime(i));
        curl_formadd(statusupdate_form, CURLFORM_COPYNAME, fieldName, CURLFORM_COPYCONTENTS, playerTime, CURLFORM_END);
      } else {
        curl_formadd(statusupdate_form, CURLFORM_COPYNAME, fieldName, CURLFORM_COPYCONTENTS, "0", CURLFORM_END);
      }
      
      // userid?
      Format(fieldName, sizeof(fieldName), "player[%d][userid]", formindex);
      Format(playerUserid, sizeof(playerUserid), "%d", GetClientUserId(i));
      curl_formadd(statusupdate_form, CURLFORM_COPYNAME, fieldName, CURLFORM_COPYCONTENTS, playerUserid, CURLFORM_END);

      // country
      if(has_geoip && GeoipCode3(playerIP, playerCountry)) {
        Format(fieldName, sizeof(fieldName), "player[%d][ccode]", formindex);
        curl_formadd(statusupdate_form, CURLFORM_COPYNAME, fieldName, CURLFORM_COPYCONTENTS, playerCountry, CURLFORM_END);
      }

      formindex++;
    }
  }

  decl String:playerCounts[8]; // "current/max"
  Format(playerCounts, sizeof(playerCounts), "%d/%d", formindex, GetMaxClients());

  curl_formadd(statusupdate_form, CURLFORM_COPYNAME, "players", CURLFORM_COPYCONTENTS, playerCounts, CURLFORM_END);

  curl_easy_setopt_string(curl, CURLOPT_URL, MDB_URL_STATUS);
  curl_easy_setopt_handle(curl, CURLOPT_HTTPPOST, statusupdate_form);

  #if USE_THREAD
    curl_easy_perform_thread(curl, StatusUpdateCompleted, statusupdate_form);
  #else
    new CURLcode:code = curl_load_opt(curl);
    if(code != CURLE_OK) {
      CloseHandle(curl);
      CloseHandle(statusupdate_form);
      CurlFailure("status update 1", code);
      return;
    }
    code = curl_easy_perform(curl);
    CloseHandle(statusupdate_form);

    StatusUpdateCompleted(curl, code, statusupdate_form);
  #endif
  
}

// Status update completion
public StatusUpdateCompleted(Handle:hndl, CURLcode: code, any:statusupdate_form) {
  statusupdate_running = false;
  //already_running_count = 0;

  CloseHandle(statusupdate_form);

  #if USE_PROFILER
    StopProfiling(statusupdate_profiler);
    LogToGame("MITCHDB PROFILE: StatusUpdate: %f sec", GetProfilerTime(statusupdate_profiler));
    //CloseHandle(statusupdate_profiler);
  #endif

  if(code != CURLE_OK) {
    CurlFailure("status update", code);
    CloseHandle(hndl);
    return;
  }

  new responseCode;
  curl_easy_getinfo_int(hndl, CURLINFO_RESPONSE_CODE, responseCode);
  CloseHandle(hndl);

  if(responseCode != 200) {
    LogToGame("[MitchDB] ERROR: There was a problem submitting the status update. (Server returned HTTP %d)", responseCode);
  }
}
