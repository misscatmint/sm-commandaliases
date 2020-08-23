void RegisterAliasListCommand()
{
	RegAdminCmd("sm_commandaliases_list", Command_ListAliases, ADMFLAG_RCON, "Lists command aliases.");
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

		ReplyToCommand(client, "\n%s \n[Destination] - \"%s\"",
								alias.Command, alias.Destination);
	}

	delete aliases;
	return Plugin_Handled;
}