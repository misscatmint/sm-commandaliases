void RegisterAliasPositionalListener(AliasDescriptor alias)
{
	RegAdminCmd(alias.Command, Command_PositionalListener, alias.CommandFlags, "Alias command", "CommandAliases");
}

public Action Command_PositionalListener(int client, int args)
{
	char command[sizeof(AliasDescriptor::Command)];
	GetCommandNameAsLower(command, sizeof(command));

	AliasDescriptor alias;
	if (!GetAliasByName(command, alias))
	{
		return Plugin_Continue;
	}

	if (!HasArguments(alias.Arguments, args))
	{
		ReplyToCommand(client, "Usage: %s", alias.UsageBuffer);
		return Plugin_Handled;
	}

	char argString[256];
	GetCmdArgString(argString, sizeof(argString));
	ReplaceString(alias.Destination, sizeof(alias.Destination), "{{args}}", argString);

	for (int i = 0; i < alias.Arguments.Length; i++)
	{
		AliasArgumentDescriptor arg;
		alias.Arguments.GetArray(i, arg);

		char argValue[64];
		GetCmdArg(arg.Index, argValue, sizeof(argValue) - 2);

		Format(argValue, sizeof(argValue), "\"%s\"", argValue);
		ReplaceStringEx(alias.Destination, sizeof(alias.Destination), arg.FullMatch, argValue);
	}

	ExecuteCommand(client, alias.Destination);
	return Plugin_Handled;
}

// ===== [ PRIVATE ] =====

static bool HasArguments(ArrayList args, int userArgCount)
{
	if (args == null || args.Length <= 0)
	{
		return true;
	}

	AliasArgumentDescriptor highestArg;
	args.GetArray(args.Length - 1, highestArg);

	// All arguments are provided, bail
	if (userArgCount >= highestArg.Index)
	{
		return true;
	}

	/*
		TODO: Does it make sense to go from:
		- Lowest to highest index
		- Highest to lowest index
	*/
	for (int i = (args.Length - 1); i >= 0; i--)
	{
		AliasArgumentDescriptor arg;
		args.GetArray(i, arg);

		if (arg.Required && arg.Index > userArgCount)
		{
			return false;
		}
	}

	return true;
}