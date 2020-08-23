void RegisterAliasReloadCommand()
{
	RegAdminCmd("sm_commandaliases_reload", Command_ReloadAliases, ADMFLAG_RCON, "Reloads command aliases.");
}

public Action Command_ReloadAliases(int client, int args)
{
	ClearAliases();
	LoadAliasesFromKeyValues(client);
	return Plugin_Handled;
}