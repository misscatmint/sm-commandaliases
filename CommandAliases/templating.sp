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

void ExpandAllVariables(char[] buffer, int maxlength, bool shouldEscape = true)
{
	for (TemplatingVariable v; v < TemplatingVariable_COUNT; v++)
	{
		ExpandVariable(v, buffer, maxlength, shouldEscape);
	}
}

void ExpandVariable(TemplatingVariable variable, char[] buffer, int maxlength, bool shouldEscape)
{
	switch (variable)
	{
		case Variable_Args:
		{
			char args[256];
			GetCmdArgString(args, sizeof(args));

			if (shouldEscape)
			{
				ReplaceString(args, sizeof(args), ";", "");
			}

			ReplaceString(buffer, maxlength, TemplatingVariables[variable], args);
		}
		case Variable_CommandName:
		{
			char cmdName[sizeof(AliasDescriptor::Command)];
			GetCmdArg(0, cmdName, sizeof(cmdName));
			ReplaceString(buffer, maxlength, TemplatingVariables[variable], cmdName);
		}
	}
}