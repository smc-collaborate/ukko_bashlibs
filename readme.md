# `ukko_bashlibs` -- An old man's collection of bash utilities  (WIP: `0.0.6-wip`)


## Parts ##

* **[do-run-in-docker ⧉](part_do-run-in-docker/readme.md)**
* **[git-shared-checkout ⧉](part_git-shared-checkout/readme.md)**
* **[Building and Installing your project ⧉](part_installer/readme.md)**


## Style ##

Style can be enforced with **`pre-commit install`**<br>

Check with: **`pre-commit run -a`**


## Full Regression Testing ##

This is done with `ukko_collections` - which has test scripts and includes `ukko_bashlibs` as a submodule

## Dev notes ##

Will be deprecated:

```
git-shared-checkout  -> part_git-shared-checkout/git-shared-checkout
do-run-in-docker     -> part_do-run-in-docker/do-run-in-docker
utils.inc.bash       |  See note inside
testSupport.inc.bash |
test-funcs.inc.bash  |
build-funcs.inc.bash |
```
