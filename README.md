# SM-CommandAliases

---

### This SourceMod plugin provides aliases to commands.

Let it be of annoyance or ease-of-access, this plugin aims to fix those problems.

---

## Configuration

The configuration **KeyValues** file by default belongs to `/csgo/cfg/sourcemod/CommandAliases.cfg`.

#### **Example configuration file contents**
```
"CommandAliases"
{
    "sm_a"  "sm_admin"
    "sm_h"
    {
        "destination"   "sm_help {{args}}"
        "chatmessage"   "Feeling lazy?"
    }
    "sm_permban"    "sm_ban <1:target> 0 [2:reason]"
}
```

---


#### **Ways of defining an alias command**

1. A simple definition, useful when you only want a simple alias.

        "sm_myalias"    "sm_help"

2. A detailed definition, useful when you want to more clearly define the behaviour of the alias.

        "sm_myalias"
        {
            "destination"   "sm_help"
            "chatmessage"   "Hello World"
        }

---

#### **Passing arguments**

This plugin almost fully supports all types of **positional** arguments from the alias command to the destination command.

Full argument strings can be passed with the `{{args}}` template, this will pass the entire argument string to the destination command.

Arguments can also be passed by specifying the index, and either `<>` for required arguments or `[]` for optional arguments.  
An optional label can also be given to the arguments, specifying this can help users when an usage message is displayed to them.

The definition: `"sm_permban"   "sm_ban <1:target> 0 [2:reason]"`, would produce the following:

- Argument from index 1 is passed as the "target", and is **required**, the alias will not execute unless it is provided.
- Argument from index 2 is passed as the "reason", but is **optional**, the alias will execute regardless of if it is provided.

Executing the above alias: `sm_permban "#STEAM_1:1" "Cheater"` would redirect to: `sm_ban "#STEAM_1:1" 0 "Cheater"`.

---

#### **Usage message**

Failing to fulfill an alias' argument requirements will make an usage message be displayed to the user.  
This message's format depends on the labels you've given for arguments, these can greatly improve user experience.

The following definition: `"sm_permban"   "sm_ban <1:target> 0 [2:reason]"`,  
upon failure of providing target, would notify the user of the following: `Usage: sm_permban <target> [reason]`.

--- 

#### **Requirements for an alias**
- An alias command cannot be empty.
- An alias command cannot contain whitespace.
- An alias command's destination cannot be empty.
- An alias command cannot be an already existing alias command.
