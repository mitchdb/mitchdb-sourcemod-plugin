
// Initiate the PING request to the API
public Action:Command_MDB_Ping(client, args) {
  PrintToConsole(client, "[MitchDB] Pinging MitchDB service...");

  decl String:apikey[APIKEY_SIZE];
  decl String:serverid[45];
  decl String:servertime[11];

  Format(servertime, sizeof(servertime), "%d", GetTime());

  GetConVarString(convar_mdb_apikey, apikey, sizeof(apikey));
  GetConVarString(convar_mdb_serverid, serverid, sizeof(serverid));

  new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, MDB_URL_PING);
  Steam_SetHTTPRequestGetOrPostParameter(request, "api_key", apikey);
  Steam_SetHTTPRequestGetOrPostParameter(request, "server_id", serverid);
  Steam_SetHTTPRequestGetOrPostParameter(request, "servertime", servertime);


  Steam_SetHTTPRequestNetworkActivityTimeout(request, MDB_TIMEOUT);

  Steam_SendHTTPRequest(request, PingCompleted, client);
  return Plugin_Handled;
}

public PingCompleted(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:client) {
  if(!successful || code != HTTPStatusCode_OK) {
    LogToGame("[MitchDB] ERROR: There was a problem pinging MitchDB. (Server returned HTTP %d)", code);
  }
  Steam_ReleaseHTTPRequest(request);

  if(code == HTTPStatusCode_OK) {
    PrintToConsole(client, "[MitchDB] API is online and responding properly.");
  } else if (code == HTTPStatusCode_Forbidden) {
    PrintToConsole(client, "[MitchDB] API Key or Secret is not valid.");
  } else if (code == HTTPStatusCode_PreconditionFailed) {
    PrintToConsole(client, "[MitchDB] ServerID is invalid.");
  } else if (code == HTTPStatusCode_InternalServerError) {
    PrintToConsole(client, "[MitchDB] MitchDB is currently down. Please try this command in a few minutes.");
  } else if (code == HTTPStatusCode_ServiceUnavailable) {
    PrintToConsole(client, "[MitchDB] MitchDB is currently down for maintenance. Please try this command in a few minutes.");
  } else {
    PrintToConsole(client, "[MitchDB] MitchDB is currently down. System returned HTTP %d.", code);
  }
}

