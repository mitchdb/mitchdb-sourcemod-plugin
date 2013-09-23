

// Find the clientid using the steamid
stock ClientIDFromSteamID(const String:steamid[]) {
  new clientct = GetMaxClients();
  new clientid = 0;
  decl String:sid[STEAMID_SIZE];
  for(new i=1;i<=clientct;i++) {
    if(IsClientAuthorized(i) && !IsFakeClient(i)) {
      GetClientAuthString(i, sid, sizeof(sid));
      if(StrEqual(steamid, sid)) {
        clientid = i;
        break;
      }
    }
  }
  return clientid;
}


// Kicks a player using their clientid
stock KickPlayer(clientid) {
  if(!IsFakeClient(clientid) && !IsClientInKickQueue(clientid)) {
    KickClient(clientid, "[MitchDB] Your SteamID has been banned");
  }
}




// Loop thru all online players, and if any of them are on the list, ban them
stock KickBannedPlayers() {
  decl String:steamid[STEAMID_SIZE];
  for(new i=1;i<=GetMaxClients();i++) {
    if(IsClientAuthorized(i) && !IsFakeClient(i)) {
      GetClientAuthString(i, steamid, sizeof(steamid));

      if(IsSteamIdBanned(steamid)) {
        // we found one of the users in the banlist. So ban them
        KickPlayer(i);
      }
    }
  }
}

// Is this steamid in our banlist
stock bool:IsSteamIdBanned(const String:steamid[]) {
  if(FindStringInArray(g_BanList, steamid) == -1) {
    return false;
  } else {
    return true;
  }
}

// Is this a valid SteamID? (format only)
stock bool:IsStringSteamId(const String:steamid[]) {
  if(MatchRegex(steamid_regex, steamid) == 1) {
    return true;
  } else {
    return false;
  }
}

// Some actions we just want to ignore
public Action:Command_Blocked(args) {
  PrintToServer("[MitchDB] This command has been blocked. Please use the MitchDB website instead.");
  return Plugin_Handled;
}