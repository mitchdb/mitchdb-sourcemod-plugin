
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

  new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, MDB_URL_PLAYER_JOIN);
  Steam_SetHTTPRequestGetOrPostParameter(request, "api_key", apikey);
  Steam_SetHTTPRequestGetOrPostParameter(request, "server_id", serverid);
  Steam_SetHTTPRequestGetOrPostParameter(request, "servertime", servertime);

  // steamid
  GetClientAuthString(clientid, playerSteamId, sizeof(playerSteamId));
  Steam_SetHTTPRequestGetOrPostParameter(request, "steamid", playerSteamId);

  // game time
  Format(playerTime, sizeof(playerTime), "%f", GetClientTime(clientid));
  Steam_SetHTTPRequestGetOrPostParameter(request, "time", playerTime);
  
  // Ip address
  GetClientIP(clientid, playerIP, sizeof(playerIP));
  Steam_SetHTTPRequestGetOrPostParameter(request, "ip", playerIP);

  // name
  GetClientName(clientid, playerName, sizeof(playerName));
  Steam_SetHTTPRequestGetOrPostParameter(request, "name", playerName);

  // Make the signature request (combine all parts)
  Format(sig_request, sizeof(sig_request), "%s%s%s%s%s%s%s%s", apisecret, apikey, servertime, serverid, playerName, playerSteamId, playerIP, playerTime);
  curl_hash_string(sig_request, strlen(sig_request), Openssl_Hash_SHA1, signature, sizeof(signature));

  // add the signature to the request
  Steam_SetHTTPRequestGetOrPostParameter(request, "signature", signature);
  Steam_SetHTTPRequestNetworkActivityTimeout(request, MDB_TIMEOUT);

  Steam_SendHTTPRequest(request, PlayerJoinCompleted);
}

// Handle the player join response
public PlayerJoinCompleted(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code) {
  if(!successful || code != HTTPStatusCode_Created) {
    LogToGame("[MitchDB] ERROR: There was a problem submitting a recent player join. (Server returned HTTP %d)", code);
  }
  Steam_ReleaseHTTPRequest(request);
}