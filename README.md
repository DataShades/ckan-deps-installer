# CKAN dependency manager

## Installation

Copy `Makefile` into the root of you main CKAN exntension and run `make
prepare`. This command will download the latest version of scripts for managing
portal dependencies.

Instead of copying Makefile manually, if you have
[ckanext-toolbelt](https://pypi.org/project/ckanext-toolbelt) installed, you
can use the following command:

```sh
ctb make config deps-makefile > Makefile
```

## Usage

**Run `make prepare` before using any of the commands below.**

Whenever it's possible, consider using PyPI and `requirements.txt`(or
setuptools' `install_requires` option). And only if extensions is not published
to PyPI(or you need specific branch/tag/commit) use current tool.

Add all extensions required by your portal to the Makefile(it contains
`ckanext-spatial` as an example) and run `make full-upgrade` to synchronize and
install dependencies.

Any new dependency requires two changes in Makefile:

1. Add extension alias to `ext_list` variable.
2. Describe the alias using syntax:
   ```sh
   remote-ALIAS = REPOSITORY_URL REFERENCE_TYPE REFERENCE
   ```

You can use any word as alias, but the simplest option is to use extension
name. For example:

* use `scheming` as alias for `ckanext-scheming` and start alias' description with `remote-scheming = ...`
* use `dcat` as alias for `ckanext-dcat` and start alias' description with `remote-dcat = ...`
* use `spatial` as alias for `ckanext-spatial` and start alias' description with `remote-spatial = ...`

Repository URL is the same as one, you are using for `git clone REPOSITORY_URL`. For example:

* `ckanext-scheming`:  https://github.com/ckan/ckanext-scheming.git
* `ckanext-dcat`:  https://github.com/ckan/ckanext-dcat.git
* `ckanext-spatial`:  https://github.com/ckan/ckanext-spatial.git

Reference type is one of the following:

* `branch` if you want to use specific branch of the project
* `tag` if you want to use specific tag of the project
* `commit` if you want to use specific commit of the project

The best choice is `tag`, because it's self-descriptive. If tag is not
available, prefer using `commit`, because it guarantees predictable build. And
only when none of above is available(or you are not afraid of accidental
breaking changes), use `branch`

The last part, reference, is a name of the git object you are referring to:

* if reference type set to `tag`, it can be `v1.2.3`
* if reference type set to `commit`, it can be `fa38c1e5`
* if reference type set to `branch`, it can be `master`


Now you can do the following:

* Synchronize(download missing and switch existing to correct tag/commit/branch) specific extension using its alias:
  ```sh
  make sync-ALIAS
  # for example: make sync-spatial
  ```
* Install specific extension using its alias. This command will install extension itself, and its `requirements.txt` if available.
  ```sh
  make install-ALIAS
  # for example: make install-spatial
  ```

* Synchronize and install all extensions:
  ```sh
  make sync install
  ```

* Synchronize and install CKAN, all extensions and current extension(one, that contains Makefile):
  ```sh
  make full-upgrade
  ```

If you want to install extra packages(`pip install my_pkg[extra1,extra2]`), add following variable to the Makefile:

```sh
package_extras-remote-ALIAS = extra1,extra2
```

For example, if you want to install `test` extras for scheming and you defined
scheming as `remote-scheming`, you need the following line:

```sh
package_extras-remote-scheming = test
```

If you are using alternatives(`<alternative>-<alias>`, described below), replace `remote` part with an alternative name. I.e, for `alternative=dev`, you need to adapt extras definition in the following way:
```sh
package_extras-dev-scheming = test
```


## Commands

| Command       | Description                                                                                                            |
|---------------|------------------------------------------------------------------------------------------------------------------------|
| version       | check if current version of installer is correct                                                                       |
| prepare       | Download/update `deps.mk` file, that contains the main logic                                                           |
| list          | list all dependencies                                                                                                  |
| ckanext-ALIAS | clone the extension if missing and checkout to the required state                                                      |
| ckanext       | perform ckanext-ALIAS for every single dependency                                                                      |
| sync-ALIAS    | clone, update origin, reset changes and checkout the extension                                                         |
| sync          | perform sync-ALIAS for every single dependency                                                                         |
| install-ALIAS | install the extension and its pip-requirements                                                                         |
| install       | perform install-ALIAS for every single dependency                                                                      |
| ckan-check    | verify CKAN version                                                                                                    |
| check-ALIAS   | check whether the extension is in required state                                                                       |
| check         | perform check-ALIAS for every single dependency and do `ckan-check`                                                    |
| ckan          | clone CKAN repository                                                                                                  |
| ckan-sync     | set CKAN to the expected tag                                                                                           |
| ckan-install  | install CKAN with its requirements                                                                                     |
| self-install  | install current extension and its requirements                                                                         |
| full-upgrade  | synchronize and install everything(it is just a combination of `sync ckan-sync install ckan-install self-install`)     |
| local-index   | download all the requirements. This allows you to install the project with `local=1` flag even without internet access |

In addition, some commands can behave differently when additional flags(`x=y`)
added to the command. For example, `install` command can install
`dev-requirements.txt` if flag `develop=1` added:

```sh
make install develop=1
```

| Commands              | Flag                        | Example              | Behavior                                                                                                                                                                         |
|-----------------------|-----------------------------|----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| sync*                 | alternative=PREFIX          | alternative=dev      | try using `<prefix>-<ext>`(i.e, `dev-spatial` instead of `remote-spatial`) definition of extensions before falling back to `remote-<ext>`. Default alternative value is `remote` |
| install*              | develop=ANYTHING            | develop=1            | install dev-requirements if present                                                                                                                                              |
| install*              | local=ANYTHING              | local=1              | use local packages instead of PyPI(you need to build it first via `make local-index`)                                                                                            |
| install*              | pyright_compatible=ANYTHING | pyright_compatible=1 | make sure pyright can find installed packages during typechecking(via exporting `SETUPTOOLS_ENABLE_FEATURES="legacy-editable"`)                                                  |
| install*, local-index | index=FOLDER                | index=pypi           | path to local package index(relative to parent directory: `../`). By default: pypi                                                                                               |
