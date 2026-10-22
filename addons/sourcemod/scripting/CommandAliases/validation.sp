enum AliasValidationError
{
	ValidationError_None = 0,
	ValidationError_AliasEmpty,
	ValidationError_AliasWhitespace,
	ValidationError_DestinationEmpty,
	ValidationError_AliasDuplicateKey,
	ValidationError_UnescapedServerExecute,
	ValidationError_ExistingCommand,
	ValidationError_CallsItself,
	ValidationError_COUNT
};

static char ValidationPhrases[ValidationError_COUNT][] =
{
	"None",
	"Alias cannot be empty",
	"Alias cannot contain whitespace",
	"Alias destination cannot be empty",
	"Alias cannot be an existing alias",
	"Alias cannot disable argument escaping with explicit server execute",
	"Alias cannot reuse an existing command",
	"Alias destination cannot run the alias itself"
};

AliasValidationError ValidateAlias(AliasDescriptor alias)
{
	TrimString(alias.Command);
	TrimString(alias.Destination);

	// The listener looks aliases up by the lowercased command name.
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

	if (AliasExists(alias.Command))
	{
		return ValidationError_AliasDuplicateKey;
	}

	// Hooking another command would run both and reset its flags for every access check.
	if (IsForeignCommand(alias.Command))
	{
		return ValidationError_ExistingCommand;
	}

	if (alias.ExplicitServerExecute && !alias.EscapeArgumentsBuffer)
	{
		return ValidationError_UnescapedServerExecute;
	}

	if (DestinationCallsAlias(alias))
	{
		return ValidationError_CallsItself;
	}

	return ValidationError_None;
}

// A destination that runs its own alias would queue itself again every frame.
static bool DestinationCallsAlias(AliasDescriptor alias)
{
	char commands[16][sizeof(AliasDescriptor::Destination)];
	int count = ExplodeString(alias.Destination, ";", commands, sizeof(commands), sizeof(commands[]));

	for (int i = 0; i < count; i++)
	{
		TrimString(commands[i]);

		char firstWord[sizeof(AliasDescriptor::Command)];
		BreakString(commands[i], firstWord, sizeof(firstWord));

		if (StrEqual(firstWord, alias.Command, false))
		{
			return true;
		}
	}

	return false;
}

bool AssertAliasValid(AliasDescriptor alias, int invoker = -1)
{
	AliasValidationError error = ValidateAlias(alias);
	if (error != ValidationError_None)
	{
		if (invoker <= 0)
		{
			LogError("\"%s\": %s", alias.Command, ValidationPhrases[error]);
		}
		else
		{
			ReplyToCommand(invoker, "\"%s\": %s", alias.Command, ValidationPhrases[error]);
		}

		return false;
	}

	return true;
}