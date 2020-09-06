#include <regex>
#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#include "CommandAliases/helpers.sp"
#include "CommandAliases/aliases.sp"
#include "CommandAliases/parsing.sp"
#include "CommandAliases/commands.sp"
#include "CommandAliases/validation.sp"

#include "CommandAliases/listeners/positional.sp"

public Plugin myinfo =
{
	name = "CommandAliases",
	author = "Sikari",
	description = "",
	version = "2.0.0",
	url = "https://bitbucket.org/Sikarii/sm-commandaliases"
};

// ===== [ PUBLIC ] =====

public void OnPluginStart()
{
	InitAliases();
	RegisterCommands();

}

public void OnAllPluginsLoaded()
{
	LoadAliasesFromKeyValues();
}

bool LoadAliasesFromKeyValues(int invoker = -1)
{
	char path[PLATFORM_MAX_PATH] = "cfg/sourcemod/CommandAliases.cfg";

	ArrayList aliases = ParseAliasesFromKeyValuesFile(path);
	if (aliases == null)
	{
		LogError("Failed loading command aliases from file '%s'.", path);
		return false;
	}

	for (int i = 0; i < aliases.Length; i++)
	{
		AliasDescriptor alias;
		aliases.GetArray(i, alias);

		if (AssertAliasValid(alias, invoker))
		{
			InitAlias(alias);
			RegisterAlias(alias);
		}
	}

	delete aliases;
	return true;
}