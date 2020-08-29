void RegisterCommands()
{
	RegAdminCmd("sm_commandaliases_list", Command_ListAliases, ADMFLAG_RCON, "Lists command aliases.");
	RegAdminCmd("sm_commandaliases_reload", Command_ReloadAliases, ADMFLAG_RCON, "Reloads command aliases.");
}

public Action Command_ListAliases(int client, int args)
{
	if (GetAliasesCount() <= 0)
	{
		ReplyToCommand(client, "No aliases were found!");
		return Plugin_Handled;
	}

	ArrayList aliases = GetAliasesSorted(Sort_Ascending);

	for (int i = 0; i < aliases.Length; i++)
	{
		AliasDescriptor alias;
		aliases.GetArray(i, alias);

		ReplyToCommand(client, "\n%s\n\
								[Destination            ] %s\n\
								[Required Command Flags ] %d\n\
								[Explicit Server Execute] %d",
								alias.Command,
								alias.Destination,
								alias.CommandFlags,
								alias.ExplicitServerExecute);
	}

	delete aliases;
	return Plugin_Handled;
}

public Action Command_ReloadAliases(int client, int args)
{
	ClearAliases();
	if (LoadAliasesFromKeyValues(client))
	{
		ReplyToCommand(client, "Reloaded command aliases!");
	}

	return Plugin_Handled;
}