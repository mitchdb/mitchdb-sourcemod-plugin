
// Called when a user tries to remove a ban using sourcemod
public Action:OnRemoveBan(const String:identity[], flags, const String:command[], any:source) {
  LogToGame("[MitchDB] Error: Please use the MitchDB website to unban players.");
  return Plugin_Handled;
}

// If you try to ban someone who is not in game, then tell them to use the site!
public Action:OnBanIdentity(const String:identity[], duration, flags, const String:reason[], const String:command[], any:source) {
  LogToGame("[MitchDB] Error: Please use the MitchDB website to ban players that are not in-game.");
  return Plugin_Handled;
}



// This will play a player who is currently in-game
public Action:OnBanClient(client, duration, flags, const String:reason[], const String:kick[], const String:command[], any:source) {
  decl String:ban_steamid[STEAMID_SIZE];
  decl String:admin_steamid[STEAMID_SIZE] = "RCON";

  // eh... not sure how this would ever happen, but better to be safe
  if(!IsClientAuthorized(client)) {
    return Plugin_Handled;
  }

  if( GetClientAuthString(client, ban_steamid, sizeof(ban_steamid)) ) {

    // a source of 0 means that this is done by console
    if(source != 0) {
      // find the steamid of the banning admin, and then override the "RCON"
      GetClientAuthString(source, admin_steamid, sizeof(admin_steamid));
    }

    SubmitBan(ban_steamid, duration, admin_steamid);

  } else {
    // If a player isn't currently in game, then you should be using MitchDB to ban them
    LogToGame("[MitchDB] Error: Please use the MitchDB website to ban players that are not in-game.");
  }
  return Plugin_Handled;
}




// this will capture rcon bans
public Action:Command_Banid(args) {
  if(GetCmdArgs() < 2) {
    PrintToServer("[MitchDB] Invalid Format: banid <time> <steamid|userid> [kick]");
    return Plugin_Handled;
  }

  PrintToServer("[MitchDB] NOTICE: Please ban players using the website. Using banid is deprecated.");

  decl String:command[100];
  decl String:parts[3][STEAMID_SIZE];

  GetCmdArgString(command, sizeof(command));
  ExplodeString(command, " ", parts, 3, STEAMID_SIZE);

  // 0 = time
  // 1 = steamid/userid
  // 2 = kick

  new clientid;
  decl String:steamid[STEAMID_SIZE];
  strcopy(steamid, sizeof(steamid), parts[1]);

  // This isnt a steamid. Perhaps it is a clientid?
  if(!IsStringSteamId(steamid)) {
    // they gave us a clientid, so lookup the steamid
    new userid = StringToInt(steamid);
    clientid = GetClientOfUserId(userid);
    if(clientid == 0) {
      PrintToServer("[MitchDB] No players were found with a userid of %d (%s)", userid, steamid);
      return Plugin_Handled;

    } 

    // Now use the clientid to find the steamid.
    if(!IsClientAuthorized(clientid) || !GetClientAuthString(clientid, steamid, sizeof(steamid))) {
      PrintToServer("[MitchDB] Please use the website to ban players who are not in game.");
      return Plugin_Handled;
    }
  }

  // At this point, we SHOULD have a valid steamid. If we dont, then bail out.
  if(!IsStringSteamId(steamid)) {
    PrintToServer("[MitchDB] No user was found by '%s'. Banning failed.", steamid);
    return Plugin_Handled;
  }

  // add the steamid to the banlist
  new bool:just_banned = false; // were they already on the list?
  if(!IsSteamIdBanned(steamid)) {
    just_banned = true;
    PushArrayString(g_BanList, steamid);
  } else {
    PrintToServer("[MitchDB] Player '%s' is already banned.", steamid);
  }

  // Loop thru the connected players, and see if any are banned.
  // If any are, then kick them
  KickBannedPlayers();

  // Submit this ban to MitchDB
  if(just_banned) {
    SubmitBan(steamid, StringToInt(parts[0]), "RCON");
  }

  return Plugin_Handled;
}





// Ban submission
stock SubmitBan(const String:steamid[], time, const String:admin_steamid[]) {

  // if everything else fails, we should still ban them in our cache
  if(!IsSteamIdBanned(steamid)) {
    PushArrayString(g_BanList, steamid);
  }

  decl String:apikey[APIKEY_SIZE];
  decl String:apisecret[APISECRET_SIZE];
  decl String:serverid[11];
  decl String:duration[10];
  decl String:servertime[11];

  decl String:sig_request[256];
  decl String:signature[128];

  Format(duration, sizeof(duration), "%d", time);

  Format(servertime, sizeof(servertime), "%d", GetTime());

  GetConVarString(convar_mdb_apikey, apikey, sizeof(apikey));
  GetConVarString(convar_mdb_apisecret, apisecret, sizeof(apisecret));
  GetConVarString(convar_mdb_serverid, serverid, sizeof(serverid));

  new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, MDB_URL_BAN);
  Steam_SetHTTPRequestGetOrPostParameter(request, "api_key", apikey);
  Steam_SetHTTPRequestGetOrPostParameter(request, "server_id", serverid);
  Steam_SetHTTPRequestGetOrPostParameter(request, "admin_steamid", admin_steamid);
  Steam_SetHTTPRequestGetOrPostParameter(request, "steamid", steamid);
  Steam_SetHTTPRequestGetOrPostParameter(request, "duration", duration);
  Steam_SetHTTPRequestGetOrPostParameter(request, "servertime", servertime);
  

  // Make the signature request (combine all parts)
  Format(sig_request, sizeof(sig_request), "%s%s%s%s%s%s%s", apisecret, apikey, servertime, serverid, admin_steamid, steamid, duration);
  curl_hash_string(sig_request, strlen(sig_request), Openssl_Hash_SHA1, signature, sizeof(signature));

  // add the signature to the request
  Steam_SetHTTPRequestGetOrPostParameter(request, "signature", signature);

  Steam_SetHTTPRequestNetworkActivityTimeout(request, MDB_TIMEOUT);
  Steam_SendHTTPRequest(request, SubmitBanCompleted);
}


// Handle the ban response
public SubmitBanCompleted(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code) {
  
  if(!successful || code != HTTPStatusCode_Created) {
    LogToGame("[MitchDB] ERROR: There was a problem submitting this ban. (Server returned HTTP %d)", code);
  }

  Steam_ReleaseHTTPRequest(request);
}