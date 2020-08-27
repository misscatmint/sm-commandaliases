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

ConVar gCV_ConfigPath = null;

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

	gCV_ConfigPath = CreateConVar("commandaliases_config_path",
									"cfg/sourcemod/CommandAliases.cfg",
									"Config file to load aliases from.");

	AutoExecConfig(true, "CommandAliases-Convars");
}

public void OnAllPluginsLoaded()
{
	LoadAliasesFromKeyValues();
}

bool LoadAliasesFromKeyValues(int recipient = -1)
{
	char path[PLATFORM_MAX_PATH];
	gCV_ConfigPath.GetString(path, sizeof(path));

	if (path[0] == '\0')
	{
		return false;
	}

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

		if (AssertAliasValid(alias, recipient))
		{
			InitAlias(alias);
			RegisterAlias(alias);
		}
	}

	delete aliases;
	return true;
}