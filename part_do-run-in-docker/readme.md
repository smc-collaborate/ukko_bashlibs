# do-run-in-docker

## Typical Use - Try an install of a program & test it for multiple ubuntu versions [`22.04`, `24.04`, `26.04`]

`do-run-in-docker ubuntu:22.04,ubuntu:24.04,ubuntu:26.04 --exit=yes --apt-get=yes -- ./do-build-and-install.sh --with-tests`


## Help
```
╭───────────────────────────────────────────────────────────────────────
│ do-run-in-docker: Runs a command on a docker image with some supportive extras (e.g. copying ssh keys, mounting the app directory, etc.)
│ Usage : do-run-in-docker <docker-image> [options] -- [cmd to run] [parameters for cmd..]
│
│ Options:  <docker-image>     : Docker image to use for testing (e.g. 'ubuntu:22.04')
│
│           --exit=yes         : Always exit after running the command  **DEFAULT**
│           --exit=no          : Don't exit automatically after running the command
│           --exit=on-success  : Stay in docker if the command fails - otherwise exit
│
│           --keys-dir=<dir>   : The directory containing SSH keys that the container may use
│                                (Default: ~/.ssh/)
│           --workspace=<dir>  : The directory to be mapped to '/workspace' inside the container
│                                (Default: .)
│           --apt-get=yes      : Perform `apt-get update` and steps
│
│           --dry-run          : Does a dry-run without actually executing the command (useful for experiments)
│
│ Example  : do-run-in-docker ubuntu:22.04 --exit=no  cat /etc/os-release
│
│ Additional functions:
│      --help     : Give this help message
│      --version  : Give version : 0.0.1
│      --colours=no|yes|auto  (Default 'auto')
╰───────────────────────────────────────────────────────────────────────
```
