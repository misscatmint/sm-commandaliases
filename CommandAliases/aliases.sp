static StringMap AliasMap = null;

enum struct AliasDescriptor
{
	char Command[128];
	char Destination[256];

	ArrayList Arguments;
	char UsageBuffer[256];
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

bool AliasExists(char[] aliasName)
{
	AliasDescriptor unused;
	return (AliasMap.GetArray(aliasName, unused, 1));
}

bool GetAliasByName(char[] name, AliasDescriptor alias)
{
	return (AliasMap.GetArray(name, alias, sizeof(alias)));
}

bool InitAlias(AliasDescriptor alias)
{
	alias.Arguments = ParseAliasArgumentsSorted(alias.Destination);
	GenerateUsageBuffer(alias);
}

void RegisterAlias(AliasDescriptor alias)
{
	if (ShouldHookCommand(alias.Command))
	{
		RegisterAliasPositionalListener(alias);
	}

	AliasMap.SetArray(alias.Command, alias, sizeof(alias));
}

// ===== [ PRIVATE ] =====

static bool ShouldHookCommand(char[] command)
{
	static StringMap MyHooks;
	if (MyHooks == null)
	{
		MyHooks = new StringMap();
	}

	bool shouldHook = false;

	if (!CommandExists(command))
	{
		shouldHook = true;
	}
	else
	{
		any unused;
		if (!MyHooks.GetValue(command, unused))
		{
			shouldHook = true;
		}
	}

	if (shouldHook)
	{
		MyHooks.SetValue(command, 0);
	}

	return shouldHook;
}

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