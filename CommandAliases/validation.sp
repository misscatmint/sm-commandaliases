enum AliasValidationError
{
	ValidationError_None = 0,
	ValidationError_AliasEmpty,
	ValidationError_AliasWhitespace,
	ValidationError_DestinationEmpty,
	ValidationError_AliasDuplicateKey,
	ValidationError_COUNT
};

static char ValidationPhrases[ValidationError_COUNT][] =
{
	"None",
	"Alias cannot be empty",
	"Alias cannot contain whitespace",
	"Alias destination cannot be empty",
	"Alias cannot be an existing alias"
};

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

	if (AliasExists(alias.Command))
	{
		return ValidationError_AliasDuplicateKey;
	}

	return ValidationError_None;
}

bool AssertAliasValid(AliasDescriptor alias, int recipient = -1)
{
	AliasValidationError error = ValidateAlias(alias);
	if (error != ValidationError_None)
	{
		if (recipient <= 0)
		{
			LogError("\"%s\": %s", alias.Command, ValidationPhrases[error]);
		}
		else
		{
			ReplyToCommand(recipient, "\"%s\": %s", alias.Command, ValidationPhrases[error]);
		}

		return false;
	}

	return true;
}