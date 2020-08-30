void StringToLower(char[] input)
{
	int inputLen = strlen(input);
	for (int i = 0; i <= inputLen; i++)
	{
		input[i] = CharToLower(input[i]);
	}
}

void ExecuteCommand(int client, const char[] command)
{
	if (client == 0)
	{
		ServerCommand("%s", command);
	}
	else
	{
		FakeClientCommandEx(client, "%s", command);
	}
}

void GetCommandNameAsLower(char[] buffer, int maxlength)
{
	GetCmdArg(0, buffer, maxlength);
	StringToLower(buffer);
}

ArrayList StringMapKeysToList(StringMap map, const int maxKeyBytes)
{
	ArrayList list = new ArrayList(ByteCountToCells(maxKeyBytes));

	StringMapSnapshot keys = map.Snapshot();
	for (int i = 0; i < keys.Length; i++)
	{
		char[] key = new char[maxKeyBytes];
		keys.GetKey(i, key, maxKeyBytes);

		list.PushString(key);
	}

	delete keys;
	return list;
}