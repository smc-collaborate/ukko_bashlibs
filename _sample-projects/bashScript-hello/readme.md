# app: `hello`

A sample project

eg:

`hello --person=Mary`


Built and tested on:
 * ubuntu:**22.04**
 * ubuntu:**24.04**
 * ubuntu:**26.04**
 * ubuntu:**latest**

## Sample Help ##

```
╭───────────────────────────────────────────────────────────────────────
│ hello: This app says 'hello'
│ Usage: hello [--person=<name>]
│        --person=<name>    Specify the name to greet (default: 'fred')
│
│ Additional functions:
│      --help     : Give this help message
│      --version  : Give version : 1.0.0
│      --colours=no|yes|auto  (Default 'auto')
╰───────────────────────────────────────────────────────────────────────
```

## Installing

| Action                                | Command                                                    | Hint
|---------------------------------------|------------------------------------------------------------|--------------------------------------------
| Install                               | **`./do-build-and-install.sh`**                            |  ⭐  Make 'hello' available to you
| Uninstall                             | **`./do-build-and-install.sh  --remove`**                  |

## Development

See **[docs/readme-dev.md](docs/readme-dev.md)**
