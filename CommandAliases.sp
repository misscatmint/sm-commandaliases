/*
	Things to keep in mind:
	- "sm_" prefix gets adjusted to your chat trigger(s), i.e. '!' and '/'.
	- The below example configuration file sets the following:
		- "sm_admin" to an alias called "sm_a" (!a, /a by default)
		- "sm_help" to an alias called "sm_h" (!h, /h by default)
	- Configure your aliases to "cfg/sourcemod/CommandAliases.cfg".

	"CommandAliases"
	{
    	"sm_a" "sm_admin"
    	"sm_h" "sm_help"
	}
*/

StringMap g_Aliases = null;

#define DefaultConfigPath "cfg/sourcemod/CommandAliases.cfg"

public void OnPluginStart()
{
	g_Aliases = LoadAliasesFromKeyValuesFile(DefaultConfigPath);
	if (g_Aliases == null)
	{
		LogError("Failed loading command aliases from \"%s\"", DefaultConfigPath);
	}
	else
	{
		LogMessage("Loaded %d command aliases from \"%s\"", g_Aliases.Size, DefaultConfigPath);
	}

	RegAdminCmd("sm_commandaliases_list", Command_ListAliases, ADMFLAG_RCON, "Lists command aliases");
	RegAdminCmd("sm_commandaliases_reload", Command_ReloadAliases, ADMFLAG_RCON, "Reloads command aliases");
}

/*
	Helper to load aliases and their destination commands
	from KeyValues structure, needs "CommandAliases" root section.

	Both the alias and destination commands are casted to lowercase.
	This does NOT validate for (infinite) command recursion!
*/
StringMap LoadAliasesFromKeyValuesFile(char filePath[PLATFORM_MAX_PATH])
{
	if (!FileExists(filePath))
	{
		return null;
	}

	KeyValues kv = new KeyValues("CommandAliases");
	if (kv == null || !kv.ImportFromFile(filePath))
	{
		delete kv;
		return null;
	}

	StringMap aliases = new StringMap();

	while (kv.GotoFirstSubKey(false) || kv.GotoNextKey(false))
	{
		char alias[256];
		kv.GetSectionName(alias, sizeof(alias));

		char destCmd[256];
		kv.GetString(NULL_STRING, destCmd, sizeof(destCmd));
		
		TrimString(alias);
		TrimString(destCmd);

		StringToLower(alias);
		StringToLower(destCmd);

		// TODO: Alias / DestCmd should probably be validated
		// i.e. an empty string ("") as an alias is probably not valid.

		// Already existing key (alias)
		if (!aliases.SetString(alias, destCmd, false))
		{
			LogError("Duplicate alias \"%s\" (->\"%s\")", alias, destCmd);
			continue;
		}

		// Constants cannot be used for sizeof()
		char desc[sizeof(destCmd) + 14];
		Format(desc, sizeof(desc), "Alias to \"%s\"", destCmd);

		// TODO: Should we care if the command exists already?
		RegConsoleCmd(alias, Command_Alias, desc);
	}

	delete kv;
	return aliases;
}

void StringToLower(char[] input)
{
	int maxlen = strlen(input);
	for (int i = 0; i <= maxlen; i++)
	{
		input[i] = CharToLower(input[i]);
	}
}

public Action Command_Alias(int client, int args)
{
	if (g_Aliases == null)
	{
		return Plugin_Continue;
	}

	// We shouldnt care if console (0) is not connected..?
	if (client > 0 && !IsClientConnected(client))
	{
		return Plugin_Continue;
	}

	char command[256];
	GetCmdArg(0, command, sizeof(command));

	char destCmd[256];
	if (!g_Aliases.GetString(command, destCmd, sizeof(destCmd)))
	{
		// Let this pass if its not one of our aliases
		return Plugin_Continue;
	}

	FakeClientCommand(client, "%s", destCmd);
	return Plugin_Handled;
}

public Action Command_ReloadAliases(int client, int args)
{
	char configPath[PLATFORM_MAX_PATH] = DefaultConfigPath;

	// Allow (re)loading of non standard path(s)
	if (args >= 1)
	{
		GetCmdArgString(configPath, sizeof(configPath));
	}

	StringMap aliases = LoadAliasesFromKeyValuesFile(configPath);
	if (aliases == null)
	{
		ReplyToCommand(client, "Failed loading command aliases from \"%s\"", configPath);
		return Plugin_Handled;
	}

	if (g_Aliases != null)
	{
		g_Aliases.Clear();
		delete g_Aliases;
	}

	g_Aliases = aliases;
	ReplyToCommand(client, "Loaded %d command aliases from \"%s\"", aliases.Size, configPath);

	return Plugin_Handled;
}

public Action Command_ListAliases(int client, int args)
{
	if (g_Aliases == null || g_Aliases.Size <= 0)
	{
		ReplyToCommand(client, "No aliases were found!");
		return Plugin_Handled;
	}

	StringMapSnapshot snap = g_Aliases.Snapshot();
	if (snap == null)
	{
		// Can this even happen? Out of memory?
		ReplyToCommand(client, "Something unexpected happened while trying to list aliases, try again later!");
		return Plugin_Handled;
	}

	ReplyToCommand(client, "Command Aliases:");

	for (int i = 0; i < snap.Length; i++)
	{
		char alias[256];
		snap.GetKey(i, alias, sizeof(alias));

		char destCmd[256];
		g_Aliases.GetString(alias, destCmd, sizeof(destCmd));

		ReplyToCommand(client, "\t[%s] => %s", alias, destCmd);
	}

	delete snap;
	return Plugin_Handled;
}