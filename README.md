# SM-CommandAliases

---

### This SourceMod plugin provides aliases to commands.

Let it be of annoyance, ease-of-access or delegation of access, this plugin aims to fix those problems.

---

## Installation
1. Download the zip of the [latest release](https://github.com/misscatmint/sm-commandaliases/releases/latest).
2. Copy `addons/sourcemod/plugins/CommandAliases.smx` from the zip into `{gamedir}/addons/sourcemod/plugins/`.
3. [Configure](#configuration) `{gamedir}/cfg/sourcemod/CommandAliases.cfg` with the aliases you wish to have.
4. You're done, use `sm_commandaliases_list` to verify the aliases you've setup.

Note: `{gamedir}` is your game's directory, this could be "csgo" or "tf2" or anything else, depending on your game.


---

## Commands
- `sm_commandaliases_list` - Lists all command aliases along with their properties.
- `sm_commandaliases_reload` - Reloads all command aliases from the file. If the file can't be loaded, the current aliases are kept.

---

## Configuration

Command aliases are automatically loaded from `/cfg/sourcemod/CommandAliases.cfg`.  
**The file is in KeyValues format and must start with the "CommandAliases" root section**.

Defining properties can be done in two ways:
```
"CommandAliases"
{
    "sm_a"  "sm_admin" // Simple definition, only supports "destination"
    
    "sm_b"  // Detailed definition, supports all of the properties below
    {
        "destination"       "sm_admin"
        "admin_flagstring"  "b"
    }

	// An alias that allows users with ADMFLAG_RESERVATION to execute a specific server command.
	"sm_w"
	{
		"destination"				"host_workshop_map <1:workshopid>"
		"admin_flagstring"			"a" // Usable by users with "ADMFLAG_RESERVATION" flag.
		"explicit_server_execute"	"1" // Explicitly (always) execute the destination as the server.
	}
}
```

#### Available properties
-- **Bolded** properties are **required**.  
-- Parsed properties can also be found [here](addons/sourcemod/scripting/CommandAliases/parsing.sp).  

|Property|Type|Description|
|--------|----|-----------|
| **destination** | string | Destination (template) for the alias.
| admin_flagstring | string | Admin flags required to execute the alias.
| explicit_server_execute | bool | Explicitly (always) execute the alias as the server. Arguments with unpaired quotes, quotes inside an argument or line breaks are refused.
| escape_arguments_buffer | bool | Escape `{{args}}` template variable, **do not change this unless you know what you're doing**! Cannot be disabled together with `explicit_server_execute`.

---

## The destination property

Having the following as the destination: `sm_ban <1:target> 0 [2:reason]` would produce the following:

- First argument would be marked as **required** and would have the label "target".
- Second argument would be marked as **optional** and would have the label "reason".
- An usage message if the first argument is not provided: `Usage: sm_alias <target> [reason]`.
    - This will trigger when the first argument (that is marked as **required**) is not provided by the user.
- If the second argument is not provided, it is left out of the command.

Labels can contain letters, digits and underscores. An alias refuses to run when its expanded command would be longer than 255 characters.

#### In addition to the above, some additional templating can also be applied:
- `sm_help {{args}}` would expand to `sm_help` and all the arguments the user provided.
- Please note that the `{{args}}` variable **cannot be marked as required**, use the `<>` notation.

### Available templating
|Variable|Description|
|--------|-----------|
| {{args}} | [Expands to the entire argument string](https://sm.alliedmods.net/new-api/console/GetCmdArgString).
| {{commandname}} | Expands to the invoked alias' command name.

---

## Permissions

All commands created by this plugin will be put under the **CommandAliases** group.  
All aliases can also be given the `admin_flagstring` property to restrict access to them.

You can setup overrides either separately `sm_a` or the entire group `@CommandAliases`.  
Keep in mind that any type of override takes priority over the admin flags set on the alias.  
Changes to `admin_flagstring` apply after `sm_commandaliases_reload`.

If you wanna get more in-depth with overrides, see [the SourceMod wiki](https://wiki.alliedmods.net/Overriding_Command_Access_(SourceMod)).

#### Examples of overrides:
`/addons/sourcemod/configs/admin_overrides.cfg`:
```diff
Overrides
{
	/**
	 * By default, commands are registered with three pieces of information:
	 * 1)Command Name 		(for example, "csdm_enable")
	 * 2)Command Group Name	(for example, "CSDM")
	 * 3)Command Level		(for example, "changemap")
	 *
	 * You can override the default flags assigned to individual commands or command groups in this way.
	 * To override a group, use the "@" character before the name.  Example:
	 * Examples:
	 *		"@CSDM"			"b"				// Override the CSDM group to 'b' flag
	 * 		"csdm_enable"	"bgi"			// Override the csdm_enable command to 'bgi' flags
	 *
	 * Note that for overrides, order is important.  In the above example, csdm_enable overwrites
	 * any setting that csdm_enable previously had.
	 *
	 * You can make a command completely public by using an empty flag string.
	 */

    "@CommandAliases"   "z" // Override all aliases to the root (z) flag.
    "sm_a"              "a" // Override the "sm_a" alias to the reservation (a) flag.
}
```

`/addons/sourcemod/configs/admin_groups.cfg`:
```diff
Groups
{
	/**
	 * Allowed properties for a group:
	 *
	 *   "flags"           - Flag string.
	 *   "immunity"        - Immunity level number, or a group name.
	 *						 If the group name is a number, prepend it with an 
	 *						 '@' symbol similar to admins_simple.ini.  Users 
	 *						 will only inherit the level number if it's higher 
	 *						 than their current value.
	 */
	"Default"
	{
		"immunity"		"1"
	}

	"Alias Users"
	{
		Overrides
		{
			"sm_w"	"allow" // Anyone in the "Alias Users" group will get access to "sm_w".
			"sm_b"	"deny"  // Anyone in the "Alias Users" group is NOT allowed to use "sm_b".
		}
	}
}
```

Allow and deny rules in admin groups only work per command, since SourceMod matches `@` group rules there against the command name. They also don't apply to aliases that need no admin flags.

---

## Requirements for an alias
All requirements can be found at all times [here](addons/sourcemod/scripting/CommandAliases/validation.sp).

- An alias command cannot be empty.
- An alias command cannot contain whitespace.
- An alias command's destination cannot be empty.
- An alias command cannot be an already existing alias command. Alias commands are not case-sensitive.
- An alias command cannot reuse an existing command. To change who can use an existing command, override it in `admin_overrides.cfg` instead.
- An alias command's destination cannot run the alias itself.
- An alias command cannot disable `escape_arguments_buffer` while using `explicit_server_execute`.
