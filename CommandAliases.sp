#include <regex>
#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

enum AliasValidationError
{
	ValidationError_None = 0,
	ValidationError_AliasEmpty,
	ValidationError_AliasWhitespace,
	ValidationError_DestinationEmpty,
	ValidationError_AliasDuplicateKey,
	ValidationError_COUNT
};

stock char gC_ValidationPhrases[ValidationError_COUNT][] =
{
	"None",
	"Alias cannot be empty",
	"Alias cannot contain whitespace",
	"Alias destination cannot be empty",
	"Alias cannot be an existing alias"
};

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

StringMap g_Aliases = null;
ConVar gCV_ConfigPath = null;

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

	RegAdminCmd("sm_commandaliases_list", Command_ListAliases, ADMFLAG_RCON, "Lists command aliases.");

	gCV_ConfigPath = CreateConVar("commandaliases_config_path",
									"cfg/sourcemod/CommandAliases.cfg",
									"Config file to load aliases from.");

	AutoExecConfig(true, "CommandAliases-Convars");
}

public void OnAllPluginsLoaded()
{
	char path[PLATFORM_MAX_PATH];
	gCV_ConfigPath.GetString(path, sizeof(path));

	if (path[0] == '\0')
	{
		return;
	}

	ArrayList aliases = ParseAliasesFromKeyValuesFile(path);
	if (aliases == null)
	{
		LogError("Failed loading command aliases from file '%s'.", path);
		return;
	}

	for (int i = 0; i < aliases.Length; i++)
	{
		AliasDescriptor alias;
		aliases.GetArray(i, alias);

		AliasValidationError error = ValidateAlias(alias);
		if (error == ValidationError_None)
		{
			RegisterAlias(alias);
		}
		else
		{
			LogError("'%s' is not valid: '%s'.", alias.Command, gC_ValidationPhrases[error]);
		}
	}

	delete aliases;
}

ArrayList ParseAliasesFromKeyValuesFile(const char filePath[PLATFORM_MAX_PATH])
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
		}

		// TODO: Does it make sense to parse and generate these
		// as aliases at this point of parsing are not necessarily valid?

		alias.Arguments = ParseAliasArguments(alias.Destination);
		alias.Arguments.SortCustom(SortAscending_ArgumentIndexAndParseOrder);

		GenerateUsageBuffer(alias);
		aliases.PushArray(alias);
	}

	return aliases;
}

ArrayList ParseAliasArguments(const char[] input)
{
	static Regex argRegex;
	if (argRegex == null)
	{
		argRegex = new Regex("[\\[\\<]([1-9])(?:\\:([a-zA-Z]+))?[\\]\\>]");
	}

	ArrayList arguments = new ArrayList(sizeof(AliasArgumentDescriptor));

	int matchCount = argRegex.MatchAll(input);
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

void GenerateUsageBuffer(AliasDescriptor alias)
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

AliasValidationError ValidateAlias(AliasDescriptor alias)
{
	TrimString(alias.Command);
	TrimString(alias.Destination);

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

	AliasDescriptor unused;
	if (g_Aliases.GetArray(alias.Command, unused, 1))
	{
		return ValidationError_AliasDuplicateKey;
	}

	return ValidationError_None;
}

bool RegisterAlias(AliasDescriptor alias)
{
	static StringMap MyHooks;
	if (MyHooks == null)
	{
		MyHooks = new StringMap();
	}

	bool shouldHook = false;
	if (!CommandExists(alias.Command))
	{
		shouldHook = true;
	}
	else
	{
		any unused;
		if (!MyHooks.GetValue(alias.Command, unused))
		{
			shouldHook = true;
			LogMessage("Warning: Alias command \"%s\" was already registered as a command!", alias.Command);
		}
	}

	if (shouldHook)
	{
		MyHooks.SetValue(alias.Command, 0);
		RegConsoleCmd(alias.Command, Command_Alias, "Alias command");
	}

	g_Aliases.SetArray(alias.Command, alias, sizeof(alias));
	return shouldHook;
}

bool HasAliasArguments(ArrayList args, const int userArgCount)
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

		Last index is skipped as it's
		already covered in the above condition.
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

		ReplyToCommand(client, "\n%s \n[Destination] - \"%s\"",
								alias.Command, alias.Destination);
	}

	delete aliases;
	return Plugin_Handled;
}

// ===== [ LISTENER ] =====

public Action Command_Alias(int client, int args)
{
	char commandName[sizeof(AliasDescriptor::Command)];
	GetCmdArg(0, commandName, sizeof(commandName));

	StringToLower(commandName);

	AliasDescriptor alias;
	if (!g_Aliases.GetArray(commandName, alias, sizeof(alias)))
	{
		return Plugin_Continue;
	}

	if (!HasAliasArguments(alias.Arguments, args))
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
		GetCmdArg(arg.Index, argValue, sizeof(argValue));

		if (argValue[0] != '\0')
		{
			Format(argValue, sizeof(argValue), "\"%s\"", argValue);
		}

		ReplaceStringEx(alias.Destination, sizeof(alias.Destination), arg.FullMatch, argValue);
	}

	TrimString(alias.Destination);
	PrintToServer("Executing: \"%s\"", alias.Destination);

	if (client == 0)
	{
		ServerCommand("%s", alias.Destination);
	}
	else
	{
		FakeClientCommandEx(client, "%s", alias.Destination);
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

int SortAscending_ArgumentIndexAndParseOrder(int index1, int index2, Handle array, Handle hndl)
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