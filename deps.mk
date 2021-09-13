_installer_version = v0.0.18
_version ?= $(_installer_version)

root_dir = ..
vpath ckanext-% $(root_dir)
vpath ckan $(root_dir)

help:
	@echo CKAN dependencies installer
	@echo Usage:
	@echo -e '\tmake [target]'
	@echo TLDR\;
	@echo -e '\tmake prepare && make sync install'
	@echo
	@echo Targets:
	@echo -e '\tversion - check if current version of installer is correct'
	@echo
	@echo -e '\tlist - list all dependencies'
	@echo
	@echo -e '\tckanext-NAME - clone the extension if missing and checkout to the required state'
	@echo -e '\tckanext - perform ckanext-NAME for every single dependency'
	@echo
	@echo -e '\tsync-NAME - clone, update origin, reset changes and checkout the extension'
	@echo -e '\tsync - perform sync-NAME for every single dependency'
	@echo
	@echo -e '\tinstall-NAME - install the extension and its pip-requirements'
	@echo -e '\tinstall - perform install-NAME for every single dependency'
	@echo
	@echo -e '\tckan-check - verify CKAN version'
	@echo -e '\tcheck-NAME - check whether the extension is in required state'
	@echo -e '\tcheck - perform check-NAME for every single dependency and do `ckan-check`'
	@echo
	@echo -e '\tckan - clone CKAN repository'
	@echo
	@echo -e '\tckan-sync - set CKAN to the expected tag'
	@echo
	@echo -e '\tckan-install - install CKAN with its requirements'
	@echo
	@echo -e '\tself-install - install current extension and its requirements'

version:
ifeq (master,$(_version))
	@echo You are using master branch of deps-installer.
	@echo 'Run `make prepare` in order to check/pull latest version'
else
ifneq ($(_installer_version),$(_version))
	@echo You are using incorrect version of installer: $(_version) instead of $(_installer_version)
	@echo 'Run `make prepare` in order to fix this problem'
else
	@echo Your version of installer is up-to-date
endif
endif

list:
	@echo $(ext_list)

.SECONDEXPANSION:

install ckanext sync check: $(ext_list:%=$$@-%)
ckanext-% check-% sync-% install-%: ext_path=$(root_dir)/ckanext-$*
ckanext-% check-% sync-% install-%: type = $(word 2, $(remote-$*))
ckanext-% check-% sync-% install-%: remote = $(firstword $(remote-$*))
ckanext-% check-% sync-% install-%: target = $(lastword $(remote-$*))

ckanext-%:
	@echo [Clone $* into $(ext_path)]
	git clone $(remote) $(ext_path);
	cd $(ext_path); \
	if [ "$(type)" = "branch" ]; then \
		git checkout -B $(target) origin/$(target); \
	fi

sync-%: ckanext-%
	@echo [Synchronize $*];
	cd $(ext_path); \
	git remote set-url origin $(remote); \
	git fetch origin;
	cd $(ext_path); \
	git reset --hard; \
	if [ "$(type)" = "branch" ]; then \
		git checkout -B $(target) origin/$(target); \
		git reset --hard origin/$(target); \
	fi;

ckan: ckan_path=$(root_dir)/ckan
ckan: remote=https://github.com/ckan/ckan.git
ckan:
	@echo [Clone ckan into $(ckan_path)]
	git clone $(remote) $(ckan_path);

ckan-sync: ckan
	@if [ ! -d "$(root_dir)/ckan" ]; then \
		echo "CKAN is not available at $(root_dir)/ckan"; \
		exit 0; \
	fi; \
	cd $(root_dir)/ckan; \
	git fetch origin;
	cd $(root_dir)/ckan; \
	git reset --hard; \
	git checkout $(ckan_tag);

ckan-install:
	@if [ ! -d "$(root_dir)/ckan" ]; then \
		echo "CKAN is not available at $(root_dir)/ckan"; \
		exit 0; \
	fi; \
	cd $(root_dir)/ckan; \
	pip install -rrequirement-setuptools.txt; \
	pip install -e. -rrequirements.txt; \
	if [ "$(develop)" != "" ] && [ -f "dev-requirements.txt" ]; then pip install -r "dev-requirements.txt"; fi;

self-install:
	pip install -e.; \
	for f in requirements.txt pip-requirements.txt; do \
		if [ -f "$$f" ]; then pip install -U -r "$$f"; fi; \
	done; \
	if [ "$(develop)" != "" ] && [ -f "dev-requirements.txt" ]; then pip install -r "dev-requirements.txt"; fi;

install-%: ckanext-%
	cd $(ext_path); \
	pip install -e.; \
	for f in requirements.txt pip-requirements.txt; do \
		if [ -f "$$f" ]; then pip install -r "$$f"; fi; \
	done; \
	if [ "$(develop)" != "" ] && [ -f "dev-requirements.txt" ]; then pip install -r "dev-requirements.txt"; fi;

check: ckan-check
check-%:
	@if [ ! -d "$(ext_path)" ]; then \
		echo $(ext_path) does not exist; \
		exit 0; \
	fi; \
	cd "$(ext_path)"; \
	remote_url=$$(git remote get-url origin); \
	if [ "$$remote_url" != "$(remote)" ]; then \
		echo $* remote is different from $(remote): $$remote_url; \
		exit 0; \
	fi; \
	if [ "$(type)" = "branch" ]; then \
	    branch=$$(git rev-parse --abbrev-ref HEAD); \
	    if [ "$$branch" != "$(target)" ]; then \
		    echo $* branch is different from $(target): $$branch; \
		    exit 0; \
	    fi; \
	    git fetch origin; \
	    if [ "$$(git log ..origin/$$branch)" != "" ]; then \
		    echo $* remote has extra commits; \
		    exit 0; \
	    fi; \
	fi; \
	echo $* is up-to-date;

ckan-check:
	@if [ ! -d "$(root_dir)/ckan" ]; then \
		echo "CKAN is not available at $(root_dir)/ckan"; \
		exit 0; \
	fi; \
	cd $(root_dir)/ckan; \
	current_tag=$$(git describe --tags); \
	if [ "$$current_tag" != "$(ckan_tag)" ]; then \
		echo "CKAN is using wrong tag: $$current_tag. Expected: $(ckan_tag)"; \
		exit 0; \
	else \
		echo "CKAN is using correct tag: $$current_tag"; \
	fi;
