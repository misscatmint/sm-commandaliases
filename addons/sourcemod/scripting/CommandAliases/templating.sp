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

/**
 * Expands every templating variable in the buffer.
 *
 * @return    False if the expanded buffer would not fit, which leaves the buffer partly expanded.
 */
bool ExpandAllVariables(char[] buffer, int maxlength, bool shouldEscape = true)
{
	for (TemplatingVariable v; v < TemplatingVariable_COUNT; v++)
	{
		if (!ExpandVariable(v, buffer, maxlength, shouldEscape))
		{
			return false;
		}
	}

	return true;
}

/**
 * Expands one templating variable in the buffer.
 *
 * @return    False if the value or the expanded buffer would not fit, which leaves the buffer unchanged.
 */
bool ExpandVariable(TemplatingVariable variable, char[] buffer, int maxlength, bool shouldEscape)
{
	if (StrContains(buffer, TemplatingVariables[variable]) == -1)
	{
		return true;
	}

	char value[sizeof(AliasDescriptor::Destination)];
	switch (variable)
	{
		case Variable_Args:
		{
			GetCmdArgString(value, sizeof(value));

			if (shouldEscape)
			{
				ReplaceString(value, sizeof(value), ";", "");
			}
		}
		case Variable_CommandName:
		{
			GetCmdArg(0, value, sizeof(value));
		}
	}

	// A value that fills its buffer may have been cut off.
	if (strlen(value) >= sizeof(value) - 1)
	{
		return false;
	}

	// Expanding into a buffer one byte larger shows whether the result would have been cut off.
	char[] expanded = new char[maxlength + 1];
	strcopy(expanded, maxlength + 1, buffer);
	ReplaceString(expanded, maxlength + 1, TemplatingVariables[variable], value);

	if (strlen(expanded) >= maxlength)
	{
		return false;
	}

	strcopy(buffer, maxlength, expanded);
	return true;
}
