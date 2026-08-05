# `ukko_bashlibs` -- An old man's collection of bash utilities  (WIP: `0.0.6-wip`) #

## Parts ##

* **[do-run-in-docker ⧉](part_do-run-in-docker/readme.md)**
* **[git-shared-checkout ⧉](part_git-shared-checkout/readme.md)**

## How to use in your project ##

This is most commonly used to install a python project, such as:

```tree
├── do-build-and-install.sh
├── my-app.py
├── libs
│   └── _loader-shim.inc.bash
├── readme.md
└── requirements.txt
```

Where:

* **`libs/_loader-shim.inc.bash`** is: [**libs/_loader-shim.inc.bash**](_internalUse/_loader-shim.inc.bash) -and-
* **`do-build-and-install.sh`** is:

   ```bash
   #!/bin/env bash
   set -eu


   function apps_doInstallOrClean()
   {
       echo "🔨 app-name"

       installEditablePythonPkgs "git@github.com:smc-collaborate/ukko_pylibs"  --ref='ver:v0.2.0'

       do_pyInstall "my-app.py"
   }


   # shellcheck source=/dev/null
   source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/libs/_loader-shim.inc.bash"
   ```

## Style ##

Style can be enforced with **`pre-commit install`**<br>

Check with: **`pre-commit run -a`**

## Full Regression Testing ##

This is done with `ukko_collections` - which has test scripts and includes `ukko_bashlibs` as a submodule

## Dev notes ##

None currently
