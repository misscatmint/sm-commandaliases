enum TemplatingVariable
{
	Variable_Args = 0,
	Variable_CommandName,
	TemplatingVariable_COUNT
};

static char TemplatingVariables[TemplatingVariable_COUNT][] =
{
	"{{args}}",
	"{{commandname}}"
};

void ExpandAllVariables(char[] buffer, int maxlength)
{
	for (TemplatingVariable v; v < TemplatingVariable_COUNT; v++)
	{
		ExpandVariable(v, buffer, maxlength);
	}
}

void ExpandVariable(TemplatingVariable variable, char[] buffer, int maxlength)
{
	switch (variable)
	{
		case Variable_Args:
		{
			char args[256];
			GetCmdArgString(args, sizeof(args));
			ReplaceString(buffer, maxlength, TemplatingVariables[variable], args);
		}
		case Variable_CommandName:
		{
			char cmdName[sizeof(Alias::Command)];
			GetCmdArg(0, cmdName, sizeof(cmdName));
			ReplaceString(buffer, maxlength, TemplatingVariables[variable], cmdName);
		}
	}
}