# `ukko_bashlibs` -- An old man's collection of bash utilities  (WIP: `0.0.6-wip`) #

Release Checklist:  **`./install/do-run-tests.sh`**

## Parts ##

| Part                                                                       | Version |
|----------------------------------------------------------------------------|---------|
| **[do-run-in-docker ⧉](part_do-run-in-docker/readme.md)**                 | v0.0.2  |
| **[git-shared-checkout ⧉](part_git-shared-checkout/git-shared-checkout)** | v0.0.8  |
| **[_loader-shim.inc.bash ⧉](part_shim-installer/_loader-shim.inc.bash)**  | v0.0.5  |


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

* **`libs/_loader-shim.inc.bash`** is: [**lib/_loader-shim.inc.bash**](part_shim-installer/_loader-shim.inc.bash) -and-
* **`do-build-and-install.sh`** is:

   ```bash
   #!/bin/env bash
   set -eu


   function apps_doInstallOrClean()
   {
       echo "🔨 app-name"

       installEditablePythonPkgs "git@github.com:smc-collaborate/ukko_pylibs"  --ref='ver:v0.2.2'

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

However, a simple self-contained test is:

```bash
# Build & test all the sample projects

find _sample-projects -name 'do-build-and-install.sh' -exec {} --with-tests --with-docker \;

./install/do-run-tests.sh

```

### pythonScript-hello ##

Run: `_sample-projects/pythonScript-hello/do-build-and-install.sh --with-tests --with-docker`

| Result | OS                | OS SubRev                | Python  | PIP        | Test                                                                                                       |
|--------|-------------------|--------------------------|---------|------------|------------------------------------------------------------------------------------------------------------|
|   ✓    | ubuntu-apt:22.04  | .5 LTS (Jammy Jellyfish) | 3.10.12 | pip 22.0.2 | `_sample-projects/pythonScript-hello/do-build-and-install.sh --with-docker=ubuntu-apt:22.04  --with-tests` |
|   ✓    | ubuntu-apt:24.04  | .4 LTS (Noble Numbat)    | 3.12.3  | pip 24.0   | `_sample-projects/pythonScript-hello/do-build-and-install.sh --with-docker=ubuntu-apt:24.04  --with-tests` |
|   ✓    | ubuntu-apt:26.04  | LTS (Resolute Racoon)    | 3.14.4  | pip 25.1.1 | `_sample-projects/pythonScript-hello/do-build-and-install.sh --with-docker=ubuntu-apt:26.04  --with-tests` |
|   ✓    | ubuntu-apt:latest | LTS (Resolute Racoon)    | 3.14.4  | pip 25.1.1 | `_sample-projects/pythonScript-hello/do-build-and-install.sh --with-docker=ubuntu-apt:latest --with-tests` |
