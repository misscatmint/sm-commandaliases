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

This plugin optionally supports passing arguments from the alias command to the destination command.  
This can be implemented by using `{{args}}` template in the destination command.

The following configuration would redirect from `sm_h 12` to `sm_help 12`.
```
"sm_h"  "sm_help {{args}}"
```

---

#### **Requirements for an alias**
- An alias command cannot be empty.
- An alias command cannot contain whitespace.
- An alias command's destination cannot be empty.
- An alias command cannot be an already existing alias command.
