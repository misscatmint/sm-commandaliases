#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define DEFAULT_CONFIG "cfg/sourcemod/CommandAliases.cfg"

enum struct AliasDescriptor
{
	char Command[128];
	char Destination[256];

	char ChatMessage[128];
}

enum AliasValidationError
{
	ValidationError_None = 0,
	ValidationError_AliasEmpty,
	ValidationError_AliasWhitespace,
	ValidationError_DestinationEmpty,
	ValidationError_AliasDuplicateKey,
	ValidationError_COUNT
};

static char gC_ValidationPhrases[ValidationError_COUNT][] =
{
	"None",
	"Alias commands cannot be empty",
	"Alias commands cannot contain whitespace",
	"Alias destinations cannot be empty",
	"Alias commands cannot be duplicate"
};

StringMap g_Aliases = null;

public Plugin myinfo =
{
	name = "CommandAliases",
	author = "Sikari",
	description = "",
	version = "1.0.0",
	url = "https://bitbucket.org/Sikarii/sm-commandaliases"
};

// ===== [ PUBLIC ] =====

public void OnPluginStart()
{
	g_Aliases = new StringMap();

	RegAdminCmd("sm_commandaliases_list", Command_ListAliases, ADMFLAG_RCON, "Lists command aliases");
	RegAdminCmd("sm_commandaliases_reload", Command_ReloadAliases, ADMFLAG_RCON, "Reloads command aliases");
}

public void OnAllPluginsLoaded()
{
	ArrayList aliases = ParseAliasesFromKeyValuesFile(DEFAULT_CONFIG);
	if (aliases == null)
	{
		LogError("Failure parsing command aliases from \"%s\"", DEFAULT_CONFIG);
		return;
	}

	ArrayList errors = new ArrayList();
	ArrayList validAliases = GetValidAliases(aliases, errors);

	if (aliases.Length != validAliases.Length)
	{
		for (int i = 0; i < aliases.Length; i++)
		{
			AliasValidationError error = errors.Get(i);
			if (error != ValidationError_None)
			{
				AliasDescriptor alias;
				aliases.GetArray(i, alias);

				LogError("Validation of alias \"%s\" failed, reason: \"%s\"", alias.Command, gC_ValidationPhrases[error]);
			}
		}
	}

	int hookCount = RegisterAndHookAliases(validAliases, g_Aliases, true);

	LogMessage("%d command aliases loaded, \
				of which %d are valid, \
				%d new command hooks were used to accomplish full coverage.",
				aliases.Length,
				validAliases.Length,
				hookCount);

	delete errors;
	delete aliases;
	delete validAliases;
}

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
			kv.GetString("chatmessage", alias.ChatMessage, sizeof(alias.ChatMessage));
		}

		aliases.PushArray(alias);
	}

	return aliases;
}

ArrayList GetValidAliases(ArrayList candicates, ArrayList validationResults = null)
{
	ArrayList validAliases = new ArrayList(sizeof(AliasDescriptor));
	if (candicates == null || candicates.Length <= 0)
	{
		return validAliases;
	}

	for (int i = 0; i < candicates.Length; i++)
	{
		AliasDescriptor candicate;
		candicates.GetArray(i, candicate);

		AliasValidationError error = ValidateAlias(candicate, validAliases);

		if (validationResults != null)
		{
			validationResults.Push(error);
		}

		if (error == ValidationError_None)
		{
			validAliases.PushArray(candicate);
		}
	}

	return validAliases;
}


AliasValidationError ValidateAlias(AliasDescriptor alias, ArrayList existingAliases)
{
	TrimString(alias.Command);
	TrimString(alias.Destination);

	StringToLower(alias.Command);

	if (alias.Command[0] == '\0')
	{
		return ValidationError_AliasEmpty;
	}

	if (StrContains(alias.Command, " ") != -1)
	{
		return ValidationError_AliasWhitespace;
	}

	if (alias.Destination[0] == '\0')
	{
		return ValidationError_DestinationEmpty;
	}

	for (int i = 0; i < existingAliases.Length; i++)
	{
		AliasDescriptor existingAlias;
		existingAliases.GetArray(i, existingAlias);

		if (StrEqual(existingAlias.Command, alias.Command))
		{
			return ValidationError_AliasDuplicateKey;
		}
	}

	return ValidationError_None;
}

int RegisterAndHookAliases(ArrayList aliases, StringMap destination, bool clearDestination = true)
{
	if (aliases == null || aliases.Length <= 0)
	{
		return 0;
	}

	if (clearDestination)
	{
		destination.Clear();
	}

	static StringMap MyHooks;
	if (MyHooks == null)
	{
		MyHooks = new StringMap();
	}

	int hookCount = 0;

	for (int i = 0; i < aliases.Length; i++)
	{
		AliasDescriptor alias;
		aliases.GetArray(i, alias);

		bool shouldHook = false;

		if (!CommandExists(alias.Command))
		{
			shouldHook = true;
		}
		else
		{
			any dummy;
			if (!MyHooks.GetValue(alias.Command, dummy))
			{
				shouldHook = true;
				LogMessage("Warning: Alias command \"%s\" was already registered as a command!", alias.Command);
			}
		}

		if (shouldHook)
		{
			hookCount++;
			MyHooks.SetValue(alias.Command, 0);
			RegConsoleCmd(alias.Command, Command_Alias, "Alias command");
		}

		destination.SetArray(alias.Command, alias, sizeof(alias));
	}

	return hookCount;
}

bool PerformAlias(int client, int args, AliasDescriptor alias)
{
	// TODO: Can we validate if we're in a command hook context?

	if (alias.Command[0] == '\0')
	{
		return false;
	}

	if (alias.Destination[0] == '\0')
	{
		return false;
	}

	int argsIdx = StrContains(alias.Destination, " ");
	if (argsIdx != -1)
	{
		if (StrContains(alias.Destination[argsIdx], "{{args}}") != -1)
		{
			char argString[128];
			if (args > 0)
			{
				GetCmdArgString(argString, sizeof(argString));
			}

			ReplaceString(alias.Destination[argsIdx], sizeof(alias.Destination), "{{args}}", argString);
		}
	}

	TrimString(alias.Destination);

	if (client == 0)
	{
		ServerCommand("%s", alias.Destination);
	}
	else
	{
		FakeClientCommandEx(client, "%s", alias.Destination);
	}

	if (alias.ChatMessage[0] != '\0')
	{
		ReplyToCommand(client, "%s", alias.ChatMessage);
	}

	return true;
}

// ===== [ COMMANDS ] =====

public Action Command_ListAliases(int client, int args)
{
	if (g_Aliases.Size <= 0)
	{
		ReplyToCommand(client, "No aliases were found!");
		return Plugin_Handled;
	}

	ArrayList aliases = StringMapKeysToList(g_Aliases, sizeof(AliasDescriptor::Command));

	aliases.Sort(Sort_Ascending, Sort_String);

	for (int i = 0; i < aliases.Length; i++)
	{
		char command[sizeof(AliasDescriptor::Command)];
		aliases.GetString(i, command, sizeof(command));

		AliasDescriptor alias;
		g_Aliases.GetArray(command, alias, sizeof(alias));

		ReplyToCommand(client, " \"%s\" => \"%s\"", alias.Command, alias.Destination);
	}

	delete aliases;
	return Plugin_Handled;
}

public Action Command_ReloadAliases(int client, int args)
{
	ArrayList aliases = ParseAliasesFromKeyValuesFile(DEFAULT_CONFIG);
	if (aliases == null)
	{
		ReplyToCommand(client, "Failure parsing command aliases from \"%s\"", DEFAULT_CONFIG);
		return Plugin_Handled;
	}

	ArrayList validAliases = GetValidAliases(aliases);

	int hookCount = RegisterAndHookAliases(validAliases, g_Aliases, true);

	ReplyToCommand(client, "%d command aliases loaded, \
							of which %d are valid, \
							%d new command hooks were used to accomplish full coverage.",
							aliases.Length,
							validAliases.Length,
							hookCount);

	delete aliases;
	delete validAliases;
	return Plugin_Handled;
}

// ===== [ LISTENER ] =====

public Action Command_Alias(int client, int args)
{
	char commandName[sizeof(AliasDescriptor::Command)];
	GetCmdArg(0, commandName, sizeof(commandName));

	StringToLower(commandName);

	/*
		Command hooks cannot be unregistered,
		so we need to ask our collection if it's still active.
	*/
	AliasDescriptor alias;
	if (!g_Aliases.GetArray(commandName, alias, sizeof(alias)))
	{
		return Plugin_Continue;
	}

	if (!PerformAlias(client, args, alias))
	{
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

// ===== [ HELPERS ] =====

void StringToLower(char[] input)
{
	int inputLen = strlen(input);
	for (int i = 0; i <= inputLen; i++)
	{
		input[i] = CharToLower(input[i]);
	}
}

ArrayList StringMapKeysToList(StringMap map, int maxKeyBytes)
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