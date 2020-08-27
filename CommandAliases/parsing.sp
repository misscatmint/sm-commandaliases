ArrayList ParseAliasesFromKeyValuesFile(char filePath[PLATFORM_MAX_PATH])
{
	KeyValues kv = new KeyValues("CommandAliases");
	if (kv == null || !kv.ImportFromFile(filePath))
	{
		delete kv;
		return null;
	}

	ArrayList aliases = new ArrayList(sizeof(AliasDescriptor));

	while (kv.GotoNextKey(false) || (kv.GotoFirstSubKey(false) && kv.NodesInStack() <= 1))
	{
		AliasDescriptor alias;
		kv.GetSectionName(alias.Command, sizeof(alias.Command));

		bool isSimpleDefinition = (kv.GetDataType(NULL_STRING) == KvData_String);
		if (isSimpleDefinition)
		{
			kv.GetString(NULL_STRING, alias.Destination, sizeof(alias.Destination));
		}
		else
		{
			kv.GetString("destination", alias.Destination, sizeof(alias.Destination));

			char flags[32];
			kv.GetString("required_flags", flags, sizeof(flags));

			alias.CommandFlags = ReadFlagString(flags);
		}

		aliases.PushArray(alias);
	}

	return aliases;
}

ArrayList ParseAliasArguments(char[] destination)
{
	static Regex argRegex;
	if (argRegex == null)
	{
		argRegex = new Regex("[\\[\\<]([1-9])(?:\\:([a-zA-Z]+))?[\\]\\>]");
	}

	ArrayList arguments = new ArrayList(sizeof(AliasArgumentDescriptor));

	int matchCount = argRegex.MatchAll(destination);
	for (int i = 0; i < matchCount; i++)
	{
		AliasArgumentDescriptor argument;
		argRegex.GetSubString(0, argument.FullMatch, sizeof(argument.FullMatch), i);

		char firstChar = (argument.FullMatch[0]);
		char lastChar = (argument.FullMatch[strlen(argument.FullMatch) - 1]);

		bool isOptional = (firstChar == '[' && lastChar == ']');
		bool isRequired = (firstChar == '<' && lastChar == '>');

		if (!isOptional && !isRequired)
		{
			continue;
		}

		argument.ParseOrder = (i + 1);
		argument.Required = isRequired;

		char szArgIdx[12];
		argRegex.GetSubString(1, szArgIdx, sizeof(szArgIdx), i);

		argument.Index = StringToInt(szArgIdx);

		if (argRegex.CaptureCount(i) >= 2)
		{
			argRegex.GetSubString(2, argument.Label, sizeof(argument.Label), i);
		}

		arguments.PushArray(argument);
	}

	return arguments;
}

ArrayList ParseAliasArgumentsSorted(char[] destination)
{
	ArrayList arguments = ParseAliasArguments(destination);
	arguments.SortCustom(SortAscending_ArgumentIndexAndParseOrder);
	return arguments;
}

// ===== [ PRIVATE ] =====

static int SortAscending_ArgumentIndexAndParseOrder(int index1, int index2, Handle array, Handle hndl)
{
	ArrayList list = view_as<ArrayList>(array);

	AliasArgumentDescriptor first;
	list.GetArray(index1, first);

	AliasArgumentDescriptor second;
	list.GetArray(index2, second);

	if (first.Index > second.Index)
	{
		return 1;
	}

	if (first.Index < second.Index)
	{
		return -1;
	}

	if (first.ParseOrder > second.ParseOrder)
	{
		return 1;
	}

	if (first.ParseOrder < second.ParseOrder)
	{
		return -1;
	}

	return 0;
}