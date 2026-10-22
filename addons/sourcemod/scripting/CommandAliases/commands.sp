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

		int effectiveAdminFlags = GetEffectiveFlags(alias);

		ReplyToCommand(client, "\n%s\n\
								[Destination                 ] => %s\n\
								[Explicit Server Execute     ] => %d\n\
								[Real Admin Flags            ] => %s\n\
								[Effective Admin Flags       ] => %s",
								alias.Command,
								alias.Destination,
								alias.ExplicitServerExecute,
								GetFlagString(alias.AdminFlags),
								GetFlagString(effectiveAdminFlags));
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

static int GetEffectiveFlags(AliasDescriptor alias)
{
	// Command override always has priority
	int eFlags;
	if (GetCommandOverride(alias.Command, Override_Command, eFlags))
	{
		return eFlags;
	}

	if (GetCommandOverride("CommandAliases", Override_CommandGroup, eFlags))
	{
		return eFlags;
	}

	return alias.AdminFlags;
}

static char[] GetFlagString(int adminFlagsBits)
{
	AdminFlag flags[AdminFlags_TOTAL];
	int flagCount = FlagBitsToArray(adminFlagsBits, flags, sizeof(flags));

	char buffer[32];
	for (int i = 0; i < flagCount; i++)
	{
		int flag;
		FindFlagChar(flags[i], flag);

		buffer[i] = flag;
	}

	return strlen(buffer) > 0 ? buffer : "none";
}