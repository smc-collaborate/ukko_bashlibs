# app: `hello` ##

A sample project

eg:

`hello --person=Mary`

Built and tested on:

* ubuntu:**22.04**
* ubuntu:**24.04**
* ubuntu:**26.04**
* ubuntu:**latest**

## Installing ##

| Action                                | Command                                                    | Hint                                       |
|---------------------------------------|------------------------------------------------------------|--------------------------------------------|
| Install                               | **`./do-build-and-install.sh`**                            |  ⭐  Make 'hello' available to you         |
| Uninstall                             | **`./do-build-and-install.sh  --remove`**                  |                                            |

## Sample Help ##

```text
╭────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
│ Usage: hello [person⁺] [options …]
│
│    Basic Options                      Default
│ -p --person⁺=                         Fred
│ -h --helloCount=1…30                  1
│    --version                                  Gives version information for this app: v1.0.2
│ -? --help                                     Gives help
│
│    Display Options                    Default
│ -v --verbosity=quiet/info/details/all info    Set verbosity of messaging         -- Can also be set with $UAPP_VERBOSITY
│    --colour=enable/disable            enable  Select output colouring & styling  -- Can also be set with $UAPP_COLOUR
│
│ Parameter Notes:
│  • Options marked with ⁺ may be passed directly, without the option name
│
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
```

## Development ##

See **[docs/readme-dev.md](docs/readme-dev.md)**
