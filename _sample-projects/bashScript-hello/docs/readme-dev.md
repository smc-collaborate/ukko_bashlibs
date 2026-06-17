# app: `hello` -- Development


Basic project info:  **[readme.md](../readme.md)**


| Action                                | Command                                                    | Hint
|---------------------------------------|------------------------------------------------------------|--------------------------------------------
| Install & test                        | **`./do-build-and-install.sh --with-tests`**               |
| Install & test on all supported OS's  | **`./do-build-and-install.sh --with-tests --with-docker`** |  ⭐  Does the most extensive regression testing available<br>    - including multiple OS's
| Test after installing                 | **`./do-all-tests.sh`**                                    |


The supported OS's for `--with-docker` are defined as `VERIFY_ON_BUILD_ENVIRONMENTS` in **[do-build-and-install.sh ⧉](./do-build-and-install.sh)**

They are currently:
 * ubuntu:**22.04**
 * ubuntu:**24.04**
 * ubuntu:**26.04**
 * ubuntu:**latest**

## Operating systems tested on ##


| OS                                  | Python | Pip     | Test command                                                                                 |
|-------------------------------------|--------|---------|----------------------------------------------------------------------------------------------|
| ubuntu 22.04 [.5]                   | 3.10.2 | 22.0.2  | **`do-run-in-docker ubuntu:22.04 -- ./do-build-and-install.sh --with-tests`**  |
| ubuntu 24.04 [.2]                   | 3.12.3 | 24.0    | **`do-run-in-docker ubuntu:24.04 -- ./do-build-and-install.sh --with-tests`**  |
| ubuntu 26.04 (Development branch)   | 3.14.4 | 25.1.1  | **`do-run-in-docker ubuntu:26.04 -- ./do-build-and-install.sh --with-tests`**  |

It is recommended to test automatically on all with:

**`./do-build-and-install.sh --with-tests --with-docker`**
