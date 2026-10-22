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

	if (!ExpandArguments(alias, args)
		|| !ExpandAllVariables(alias.Destination, sizeof(alias.Destination), alias.EscapeArgumentsBuffer))
	{
		ReplyToCommand(client, "Arguments are too long for this alias.");
		return Plugin_Handled;
	}

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
static bool ExpandArguments(AliasDescriptor alias, int argCount)
{
	char source[sizeof(AliasDescriptor::Destination)];
	strcopy(source, sizeof(source), alias.Destination);
	alias.Destination[0] = '\0';

	int i = 0;
	while (source[i] != '\0')
	{
		// Room for an argument that fills the destination plus its quotes, so overflow is detectable.
		char insert[sizeof(AliasDescriptor::Destination) + 2];
		insert[0] = source[i];
		insert[1] = '\0';
		int consumed = 1;

		for (int j = 0; j < alias.Arguments.Length; j++)
		{
			AliasArgumentDescriptor arg;
			alias.Arguments.GetArray(j, arg);

			int matchLength = strlen(arg.FullMatch);
			if (strncmp(source[i], arg.FullMatch, matchLength) == 0)
			{
				insert[0] = '\0';
				if (arg.Index <= argCount)
				{
					GetCommandArgumentSafe(arg.Index, insert, sizeof(insert));
				}

				consumed = matchLength;
				break;
			}
		}

		if (strlen(alias.Destination) + strlen(insert) >= sizeof(alias.Destination))
		{
			return false;
		}

		StrCat(alias.Destination, sizeof(alias.Destination), insert);
		i += consumed;
	}

	return true;
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