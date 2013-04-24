
// This shows some basic stats
public Action:Command_MDB_Stats(client, args) {

  PrintToConsole(client, "[MitchDB] Statistics:");
  PrintToConsole(client, "[MitchDB] Plugin version: %s", MDBVERSION);

  new Float:statusInterval = GetConVarFloat(convar_mdb_status_interval);
  if(statusInterval == 0.0) {
    PrintToConsole(client, "[MitchDB] Status update interval: Off");
  } else if (statusInterval < MDB_MINIMUM_STATUS_INTERVAL) {
    PrintToConsole(client, "[MitchDB] Status update interval: Off (Set to %f, but must be more than %f)", statusInterval, MDB_MINIMUM_STATUS_INTERVAL);
  } else {
    PrintToConsole(client, "[MitchDB] Status update interval: %f seconds", statusInterval);
  }

  if(timer_statusupdate == INVALID_HANDLE) {
    PrintToConsole(client, "[MitchDB] Status update state: Not running");
  } else {
    PrintToConsole(client, "[MitchDB] Status update state: Running");
  }

  if(has_geoip) {
    PrintToConsole(client, "[MitchDB] Is GeoIP enabled: Yes");
  } else {
    PrintToConsole(client, "[MitchDB] Is GeoIP enabled: No");
  }

  PrintToConsole(client, "[MitchDB] Number of bans in cache: %d", GetArraySize(g_BanList));
  PrintToConsole(client, "[MitchDB] Ban cache memory usage: %d bytes", GetArraySize(g_BanList)*STEAMID_SIZE );

  // Does the ban cache file exist?
  if(FileExists(MDB_BANLIST_FILE)) {
    PrintToConsole(client, "[MitchDB] Ban cache file: %s", MDB_BANLIST_FILE);

    PrintToConsole(client, "[MitchDB] Ban cache file size: %d bytes", FileSize(MDB_BANLIST_FILE));

    new curTime = GetTime();
    new fileTime = GetFileTime(MDB_BANLIST_FILE, FileTime_LastChange);
    new fileAge = curTime - fileTime;

    decl String:timeFormat[100];
    FormatTime(timeFormat, sizeof(timeFormat), "%Y-%m-%dT%H:%M:%S", fileTime);

    if(fileAge < 60) {
      PrintToConsole(client, "[MitchDB] Ban cache age: %d seconds", fileAge );  
    } else if(fileAge < 3600) {
      PrintToConsole(client, "[MitchDB] Ban cache age: %d mins", (fileAge/60) );
    } else if(fileAge < 86400) {
      PrintToConsole(client, "[MitchDB] Ban cache age: %d hours", (fileAge/3600) );
    } else {
      PrintToConsole(client, "[MitchDB] Ban cache age: %d days", (fileAge/86400) );
    }
    
    PrintToConsole(client, "[MitchDB] Ban cache updated: %s", timeFormat);
  } else {
    PrintToConsole(client, "[MitchDB] Ban cache file: N/A");
    PrintToConsole(client, "[MitchDB] Ban cache file size: N/A");
    PrintToConsole(client, "[MitchDB] Ban cache age: N/A");
  }

  return Plugin_Handled;
}