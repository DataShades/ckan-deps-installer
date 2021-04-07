_version = 0.0.8
_installer_version ?= $(_version)

ifneq ($(_installer_version),$(_version))
$(warning You are using outdated version of installer($(_version) instead of $(_installer_version)))
$(warning Update it with `make prepare`)
$(error Aborted)
endif

root_dir = ..
vpath ckanext-% $(root_dir)


help:
	@echo Set all extensions to the correct state and reset all customizations
	@echo -e \\tmake sync [install_extension=true]
	@echo
	@echo Check whether extensions are up-to-date
	@echo -e \\tmake check
	@echo
	@echo Check whether CKAN version is correct
	@echo -e \\tmake check-ckan
	@echo
	@echo Download extension and switch it to the required branch
	@echo -e \\tmake ckanext-NAME \# i.e, make ckanext-scheming
	@echo
	@echo Synchronize singe extension
	@echo -e \\tmake sync-NAME  [install-extension=true] \# i.e, make sync-scheming
	@echo
	@echo Check single extension
	@echo -e \\tmake check-NAME \# i.e, make check-scheming
	@echo

prepare:
	curl -O https://raw.githubusercontent.com/DataShades/ckan-deps-installer/v$(_installer_version)/deps.mk

ckanext-% check-% sync-% install-%: type = $(word 2, $(remote-$(ext)))
ckanext-% check-% sync-% install-%: remote = $(firstword $(remote-$(ext)))
ckanext-% check-% sync-% install-%: target = $(lastword $(remote-$(ext)))

install: $(ext_list:%=install-%)
install-%: ext = $(@:install-%=%)
install-%: ckanext-%
	cd $(root_dir)/ckanext-$(ext); \
	pip install -e.; \
	for f in requirements.txt pip-requirements.txt; do \
		echo $$f; \
		if [[ -f "$$f" ]]; then pip install -r "$$f"; fi; \
	done;

ckanext: $(ext_list:%=ckanext-%)
ckanext-%: ext = $(@:ckanext-%=%)
ckanext-%:
	@echo [Clone $(ext) into $(root_dir)/ckanext-$(ext)]
	cd $(root_dir); \
	git clone $(remote);
	cd $(root_dir)/ckanext-$(ext); \
	if [[ "$(type)" == "branch" ]]; then \
		git checkout -B $(target) origin/$(target); \
	fi

sync: $(patsubst %,sync-%,$(ext_list))
sync-%: ext = $(@:sync-%=%)
sync-%: ckanext-%
	@echo Synchronize $(ext)

	cd $(root_dir)/ckanext-$(ext); \
	git remote set-url origin $(remote); \
	git fetch origin;
	if [[ "$(type)" == "branch" ]]; then \
		cd $(root_dir)/ckanext-$(ext); \
		git checkout -B $(target) origin/$(target); \
		git reset --hard origin/$(target); \
	fi;
ifneq (,$(install_extension))
	make install-$(@:sync-%=%)
endif

check: ckan-check $(ext_list:%=check-%)
check-%: ext=$(@:check-%=%)
check-%: ext_path=$(root_dir)/ckanext-$(ext)
check-%:
	@if [[ ! -d "$(ext_path)" ]]; then \
		echo $(ext_path) does not exist; \
		exit 0; \
	fi; \
	cd "$(ext_path)"; \
	remote_url=$$(git remote get-url origin); \
	if [[ "$$remote_url" != "$(remote)" ]]; then \
		echo $(ext) remote is different from $(remote): $$remote_url; \
		exit 0; \
	fi; \
	if [[ "$(type)" == "branch" ]]; then \
	    branch=$$(git branch --show-current); \
	    if [[ "$$branch" != "$(target)" ]]; then \
		    echo $(ext) branch is different from $(target): $$branch; \
		    exit 0; \
	    fi; \
	    git fetch origin; \
	    if [[ "$$(git log ..origin/$$branch)" != "" ]]; then \
		    echo $(ext) remote has extra commits; \
		    exit 0; \
	    fi; \
	fi; \
	echo $(ext) is up-to-date;

ckan-check:
		@if [[ ! -d "$(root_dir)/ckan" ]]; then \
		echo "CKAN is not available at $(root_dir)/ckan"; \
		exit 0; \
	fi; \
	cd $(root_dir)/ckan; \
	current_tag=$$(git describe --tags); \
	if [[ "$$current_tag" != "$(ckan_tag)" ]]; then \
		echo "CKAN is using wrong tag: $$current_tag. Expected: $(ckan_tag)"; \
		exit 0; \
	else \
		echo "CKAN is using correct tag: $$current_tag"; \
	fi;
