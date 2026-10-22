void RegisterAliasPositionalListener(AliasDescriptor alias)
{
	// Registered flags can't change after registration, so the alias flags are checked in the callback.
	RegAdminCmd(alias.Command, Command_PositionalListener, 0, "Alias command", "CommandAliases");
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

	if (!CheckCommandAccess(client, alias.Command, GetAliasEffectiveFlags(alias), true))
	{
		ReplyToCommand(client, "[SM] %T", client, "No Access");
		return Plugin_Handled;
	}

	if (!HasArguments(alias.Arguments, args))
	{
		ReplyToCommand(client, "Usage: %s", alias.UsageBuffer);
		return Plugin_Handled;
	}

	if (alias.ExplicitServerExecute && !IsInputSafeForServer(args))
	{
		ReplyToCommand(client, "Arguments cannot contain stray quotes or line breaks.");
		return Plugin_Handled;
	}

	ExpandArguments(alias);
	ExpandAllVariables(alias.Destination, sizeof(alias.Destination), alias.EscapeArgumentsBuffer);

	if (alias.ExplicitServerExecute)
	{
		ExecuteCommand(0, alias.Destination);
	}
	else
	{
		ExecuteCommand(client, alias.Destination);
	}

	return Plugin_Handled;
}

// ===== [ PRIVATE ] =====

// Server-run destinations must not let input change where the command buffer splits commands.
static bool IsInputSafeForServer(int argCount)
{
	char argString[256];
	GetCmdArgString(argString, sizeof(argString));

	if (StrContains(argString, "\n") != -1 || StrContains(argString, "\r") != -1)
	{
		return false;
	}

	int quotes = 0;
	for (int i = 0; argString[i] != '\0'; i++)
	{
		if (argString[i] == '"')
		{
			quotes++;
		}
	}

	if (quotes % 2 != 0)
	{
		return false;
	}

	for (int i = 1; i <= argCount; i++)
	{
		char arg[256];
		GetCmdArg(i, arg, sizeof(arg));

		if (StrContains(arg, "\"") != -1)
		{
			return false;
		}
	}

	return true;
}

// One pass, so an inserted value is never scanned for placeholders again.
static void ExpandArguments(AliasDescriptor alias)
{
	char source[sizeof(AliasDescriptor::Destination)];
	strcopy(source, sizeof(source), alias.Destination);
	alias.Destination[0] = '\0';

	int i = 0;
	while (source[i] != '\0')
	{
		bool replaced = false;

		for (int j = 0; j < alias.Arguments.Length; j++)
		{
			AliasArgumentDescriptor arg;
			alias.Arguments.GetArray(j, arg);

			int matchLength = strlen(arg.FullMatch);
			if (strncmp(source[i], arg.FullMatch, matchLength) == 0)
			{
				char argValue[64];
				GetCommandArgumentSafe(arg.Index, argValue, sizeof(argValue));

				StrCat(alias.Destination, sizeof(alias.Destination), argValue);
				i += matchLength;
				replaced = true;
				break;
			}
		}

		if (!replaced)
		{
			char character[2];
			character[0] = source[i];

			StrCat(alias.Destination, sizeof(alias.Destination), character);
			i++;
		}
	}
}

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