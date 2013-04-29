
// After the player is "put in game"
// if they are new, we should submit them
// Called when a player joins the server
// What if we didnt call this for players who have a large "time" online
public OnClientPostAdminCheck(clientid) {
  // The client is not in game... so wait
  // This should never happen
  if(!IsClientInGame(clientid)) {
    return;
  }

  // is this a bot
  if(IsFakeClient(clientid) || IsClientSourceTV(clientid) || IsClientReplay(clientid)) {
    return;
  }

  // lets make sure they really are "new".
  // if they have been on the server for more than 45seconds
  // then they are not new
  if(GetClientTime(clientid) > MDB_MAXIMUM_NEW_PLAYER_TIME) {
    return;
  }

  #if USE_PROFILER
    new Handle:prof = CreateProfiler();
    StartProfiling(prof);
  #endif

  new Handle:curl = curl_easy_init();
  if(curl == INVALID_HANDLE) {
    CurlError("player join submission");
    return;
  }
  CURL_DEFAULT_OPT(curl);

  decl String:apikey[APIKEY_SIZE];
  decl String:apisecret[APISECRET_SIZE];
  decl String:serverid[20];
  decl String:servertime[11];

  decl String:playerSteamId[STEAMID_SIZE];
  decl String:playerIP[16];
  decl String:playerName[45];
  decl String:playerTime[20];

  decl String:sig_request[256];
  decl String:signature[128];


  Format(servertime, sizeof(servertime), "%d", GetTime());
  GetConVarString(convar_mdb_apikey, apikey, sizeof(apikey));
  GetConVarString(convar_mdb_apisecret, apisecret, sizeof(apisecret));
  GetConVarString(convar_mdb_serverid, serverid, sizeof(serverid));

  new Handle:join_form_handle = curl_httppost();
  curl_formadd(join_form_handle, CURLFORM_COPYNAME, "api_key", CURLFORM_COPYCONTENTS, apikey, CURLFORM_END);
  curl_formadd(join_form_handle, CURLFORM_COPYNAME, "server_id", CURLFORM_COPYCONTENTS, serverid, CURLFORM_END);
  curl_formadd(join_form_handle, CURLFORM_COPYNAME, "servertime", CURLFORM_COPYCONTENTS, servertime, CURLFORM_END);

  // steamid
  GetClientAuthString(clientid, playerSteamId, sizeof(playerSteamId));
  curl_formadd(join_form_handle, CURLFORM_COPYNAME, "steamid", CURLFORM_COPYCONTENTS, playerSteamId, CURLFORM_END);

  // game time
  Format(playerTime, sizeof(playerTime), "%f", GetClientTime(clientid));
  curl_formadd(join_form_handle, CURLFORM_COPYNAME, "time", CURLFORM_COPYCONTENTS, playerTime, CURLFORM_END);
  
  // Ip address
  GetClientIP(clientid, playerIP, sizeof(playerIP));
  curl_formadd(join_form_handle, CURLFORM_COPYNAME, "ip", CURLFORM_COPYCONTENTS, playerIP, CURLFORM_END);

  // name
  GetClientName(clientid, playerName, sizeof(playerName));
  curl_formadd(join_form_handle, CURLFORM_COPYNAME, "name", CURLFORM_COPYCONTENTS, playerName, CURLFORM_END);

  // Make the signature request (combine all parts)
  Format(sig_request, sizeof(sig_request), "%s%s%s%s%s%s%s%s", apisecret, apikey, servertime, serverid, playerName, playerSteamId, playerIP, playerTime);
  curl_hash_string(sig_request, strlen(sig_request), Openssl_Hash_SHA1, signature, sizeof(signature));

  // add the signature to the request
  curl_formadd(join_form_handle, CURLFORM_COPYNAME, "signature", CURLFORM_COPYCONTENTS, signature, CURLFORM_END);

  curl_easy_setopt_string(curl, CURLOPT_URL, MDB_URL_PLAYER_JOIN);
  curl_easy_setopt_handle(curl, CURLOPT_HTTPPOST, join_form_handle);

  #if USE_THREAD
    curl_easy_perform_thread(curl, PlayerJoinCompleted, join_form_handle);
  #else
    new CURLcode:code = curl_load_opt(curl);
    if(code != CURLE_OK) {
      CloseHandle(curl);
      CloseHandle(ban_form_handle);
      return;
    }
    code = curl_easy_perform(curl);
    PlayerJoinCompleted(curl, code, join_form_handle);
  #endif

  #if USE_PROFILER
    StopProfiling(prof);
    LogToGame("MITCHDB PROFILE: PlayerJoin: %f sec", GetProfilerTime(prof));
    CloseHandle(prof);
  #endif
}

// Handle the player join response
public PlayerJoinCompleted(Handle:hndl, CURLcode: code, any:form_handle) {
  CloseHandle(form_handle);

  if(code != CURLE_OK) {
    CurlFailure("Player Join", code);
    CloseHandle(hndl);
    return;
  }
  
  new responseCode;
  curl_easy_getinfo_int(hndl, CURLINFO_RESPONSE_CODE, responseCode);
  CloseHandle(hndl);

  // make sure we get a 201 - CREATED
  if(responseCode != 201) {
    LogToGame("[MitchDB] ERROR: There was a problem submitting a recent player join. (Server returned HTTP %d)", responseCode);
  }
}