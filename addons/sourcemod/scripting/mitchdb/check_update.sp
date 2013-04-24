

// This will check to see if we are at the latest version
public Action:Command_MDB_CheckUpdate(args) {
  PrintToServer("[MitchDB] Checking for an update for the MitchDB SourceMod plugin...");
  
  new Handle:curl = curl_easy_init();
  if(curl == INVALID_HANDLE) {
    CurlError("check_update");
    return Plugin_Handled;
  }
  CURL_DEFAULT_OPT(curl);

  decl String:status_url[100];
  
  Format(status_url, sizeof(status_url), MDB_URL_UPDATE, MDBVERSION);
  curl_easy_setopt_string(curl, CURLOPT_URL, status_url);

  #if USE_THREAD
    curl_easy_perform_thread(curl, onCompleteMDBCheckUpdate);
  #else
    new CURLcode:code = curl_load_opt(curl);
    if(code != CURLE_OK) {
      CloseHandle(curl);
      return;
    }
    code = curl_easy_perform(curl);
    onCompleteMDBCheckUpdate(curl, code);
  #endif

  return Plugin_Handled;
}


public onCompleteMDBCheckUpdate(Handle:hndl, CURLcode: code, any:data) {
  if(hndl == INVALID_HANDLE) {
    CurlError("check_update_complete");
    return;
  }

  if(code != CURLE_OK) {
    CurlFailure("check_update", code);
    CloseHandle(hndl);
    return;
  }

  new responseCode;
  curl_easy_getinfo_int(hndl, CURLINFO_RESPONSE_CODE, responseCode);
  CloseHandle(hndl);

  if(responseCode == 200) {
    PrintToServer("[MitchDB] An update is available for the MitchDB SourceMod plugin");
  } else if (responseCode == 204) {
    PrintToServer("[MitchDB] You have the latest version of the MitchDB SourceMod plugin");
  } else {
    PrintToServer("[MitchDB] Problem communicating with update server. Please try again later.");
  }

}