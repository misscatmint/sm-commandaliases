static StringMap AliasMap = null;
static StringMap MyHooks = null;

enum struct AliasDescriptor
{
	char Command[128];
	char Destination[256];

	ArrayList Arguments;
	char UsageBuffer[256];

	int AdminFlags;
	bool ExplicitServerExecute;
	bool EscapeArgumentsBuffer;
}

enum struct AliasArgumentDescriptor
{
	int Index;
	char Label[32];

	bool Required;

	int ParseOrder;
	char FullMatch[64];
}

// ===== [ PUBLIC ] =====

void InitAliases()
{
	AliasMap = new StringMap();
	MyHooks = new StringMap();
}

void ClearAliases()
{
	ArrayList aliasCommands = StringMapKeysToList(AliasMap, sizeof(AliasDescriptor::Command));

	for (int i = 0; i < aliasCommands.Length; i++)
	{
		char command[sizeof(AliasDescriptor::Command)];
		aliasCommands.GetString(i, command, sizeof(command));

		AliasDescriptor alias;
		AliasMap.GetArray(command, alias, sizeof(alias));

		delete alias.Arguments;
	}

	AliasMap.Clear();
	delete aliasCommands;
}

ArrayList GetAliasesSorted(SortOrder order = Sort_Ascending)
{
	ArrayList aliasCommands = StringMapKeysToList(AliasMap, sizeof(AliasDescriptor::Command));
	aliasCommands.Sort(order, Sort_String);

	ArrayList aliases = new ArrayList(sizeof(AliasDescriptor));

	for (int i = 0; i < aliasCommands.Length; i++)
	{
		char command[sizeof(AliasDescriptor::Command)];
		aliasCommands.GetString(i, command, sizeof(command));

		AliasDescriptor alias;
		AliasMap.GetArray(command, alias, sizeof(alias));

		aliases.PushArray(alias);
	}

	delete aliasCommands;
	return aliases;
}

int GetAliasesCount()
{
	return AliasMap.Size;
}

bool AliasExists(const char[] aliasName)
{
	AliasDescriptor unused;
	return (AliasMap.GetArray(aliasName, unused, 1));
}

bool IsForeignCommand(const char[] command)
{
	any unused;
	return CommandExists(command) && !MyHooks.GetValue(command, unused);
}

bool GetAliasByName(const char[] name, AliasDescriptor alias)
{
	return (AliasMap.GetArray(name, alias, sizeof(alias)));
}

// Same priority SourceMod uses for admin commands, with the alias flags as the default.
int GetAliasEffectiveFlags(AliasDescriptor alias)
{
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

void InitAlias(AliasDescriptor alias)
{
	alias.Arguments = ParseAliasArgumentsSorted(alias.Destination);
	GenerateUsageBuffer(alias);
}

void RegisterAlias(AliasDescriptor alias)
{
	// SourceMod can't unregister commands, so an alias keeps its command across reloads.
	any unused;
	if (!MyHooks.GetValue(alias.Command, unused))
	{
		RegisterAliasPositionalListener(alias);
		MyHooks.SetValue(alias.Command, 0);
	}

	AliasMap.SetArray(alias.Command, alias, sizeof(alias));
}

// ===== [ PRIVATE ] =====

static void GenerateUsageBuffer(AliasDescriptor alias)
{
	alias.UsageBuffer = alias.Command;

	if (alias.Arguments.Length <= 0)
	{
		return;
	}

	AliasArgumentDescriptor highestArg;
	alias.Arguments.GetArray(alias.Arguments.Length - 1, highestArg);

	for (int i = 1; i <= highestArg.Index; i++)
	{
		int arrayIdx = -1;
		for (int j = 0; j < alias.Arguments.Length; j++)
		{
			AliasArgumentDescriptor arg;
			alias.Arguments.GetArray(j, arg);

			if (arg.Index == i)
			{
				arrayIdx = j;
				break;
			}
		}

		if (arrayIdx == -1)
		{
			StrCat(alias.UsageBuffer, sizeof(alias.UsageBuffer), " <unused>");
		}
		else
		{
			AliasArgumentDescriptor arg;
			alias.Arguments.GetArray(arrayIdx, arg);

			if (arg.Label[0] == '\0')
			{
				Format(arg.Label, sizeof(arg.Label), "@%d", arg.Index);
			}

			if (arg.Required)
			{
				Format(alias.UsageBuffer, sizeof(alias.UsageBuffer), "%s <%s>", alias.UsageBuffer, arg.Label);
			}
			else
			{
				Format(alias.UsageBuffer, sizeof(alias.UsageBuffer), "%s [%s]", alias.UsageBuffer, arg.Label);
			}
		}
	}

	TrimString(alias.UsageBuffer);
}