
// Initiate the PING request to the API
public Action:Command_MDB_Ping(client, args) {
  PrintToConsole(client, "[MitchDB] Pinging MitchDB service...");
  
  new Handle:curl = curl_easy_init();
  if(curl == INVALID_HANDLE) {
    CurlError("ping");
    return Plugin_Handled;
  }

  #if USE_PROFILER
    new Handle:prof = CreateProfiler();
    StartProfiling(prof);
  #endif

  CURL_DEFAULT_OPT(curl);
  curl_easy_setopt_string(curl, CURLOPT_URL, MDB_URL_PING);

  decl String:apikey[APIKEY_SIZE];
  decl String:apisecret[APISECRET_SIZE];
  decl String:serverid[45];
  decl String:servertime[11];

  decl String:sig_request[256];
  decl String:signature[128];


  Format(servertime, sizeof(servertime), "%d", GetTime());

  GetConVarString(convar_mdb_apikey, apikey, sizeof(apikey));
  GetConVarString(convar_mdb_apisecret, apisecret, sizeof(apisecret));
  GetConVarString(convar_mdb_serverid, serverid, sizeof(serverid));

  new Handle:ping_form_handle = curl_httppost();
  curl_formadd(ping_form_handle, CURLFORM_COPYNAME, "api_key", CURLFORM_COPYCONTENTS, apikey, CURLFORM_END);
  curl_formadd(ping_form_handle, CURLFORM_COPYNAME, "server_id", CURLFORM_COPYCONTENTS, serverid, CURLFORM_END);
  curl_formadd(ping_form_handle, CURLFORM_COPYNAME, "servertime", CURLFORM_COPYCONTENTS, servertime, CURLFORM_END);

  // Make the signature request (combine all parts)
  Format(sig_request, sizeof(sig_request), "%s%s%s%s", apisecret, apikey, servertime, serverid);
  curl_hash_string(sig_request, strlen(sig_request), Openssl_Hash_SHA1, signature, sizeof(signature));

  // add the signature to the request
  curl_formadd(ping_form_handle, CURLFORM_COPYNAME, "signature", CURLFORM_COPYCONTENTS, signature, CURLFORM_END);

  curl_easy_setopt_string(curl, CURLOPT_URL, MDB_URL_PING);
  curl_easy_setopt_handle(curl, CURLOPT_HTTPPOST, ping_form_handle);

  new CURLcode:code = curl_load_opt(curl);
  if(code != CURLE_OK) {
    CloseHandle(curl);
    CloseHandle(ping_form_handle);
    PrintToConsole(client, "PING FAILED (%d)", code);
    return Plugin_Handled;
  }
  code = curl_easy_perform(curl);

  #if USE_PROFILER
    StopProfiling(prof);
    PrintToServer("[MitchDB] Profiler: Ping took %f seconds.", GetProfilerTime(prof));
    CloseHandle(prof);
  #endif

  CloseHandle(ping_form_handle);

  if(curl == INVALID_HANDLE) {
    CurlError("ping");
    return Plugin_Handled;
  }

  if(code != CURLE_OK) {
    CloseHandle(curl);
    
    if(code == CURLE_COULDNT_RESOLVE_HOST) {
      PrintToConsole(client, "[MitchDB] ERROR: Ping failed: Couldn't resolve host", code);
    } else if (code == CURLE_OPERATION_TIMEDOUT) {
      PrintToConsole(client, "[MitchDB] ERROR: Ping failed: Operation timed out", code);
    } else {
      PrintToConsole(client, "[MitchDB] ERROR: Ping failed (code=%d)", code);
    }

    return Plugin_Handled;
  }

  new responseCode;
  curl_easy_getinfo_int(curl, CURLINFO_RESPONSE_CODE, responseCode);
  CloseHandle(curl);

  // display the various errors, if any
  if(responseCode == 200) {
    PrintToConsole(client, "[MitchDB] API is online and responding properly.");
  } else if (responseCode == 403) {
    PrintToConsole(client, "[MitchDB] API Key or Secret is not valid.");
  } else if (responseCode == 412) {
    PrintToConsole(client, "[MitchDB] ServerID is invalid.");
  } else if (responseCode == 500) {
    PrintToConsole(client, "[MitchDB] MitchDB is currently down. Please try this command in a few minutes.");
  } else if (responseCode == 503) {
    PrintToConsole(client, "[MitchDB] MitchDB is currently down for maintenance. Please try this command in a few minutes.");
  }
  return Plugin_Handled;
}

