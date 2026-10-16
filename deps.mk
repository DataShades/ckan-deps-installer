_installer_version = v0.0.34
_version ?= $(_installer_version)

develop =
local =
pyright_compatible = 1

root_dir = ..
index ?= pypi
outdated_jobs ?= 8

alternative ?= remote
remote-ckan ?= https://github.com/ckan/ckan.git tag $(ckan_tag)
upgrade_requirements ?= 1

constraints =
CDM_USE_UV ?=
with_submodules =

vpath ckanext-% $(root_dir)
vpath ckan $(root_dir)

define pip-file
$(if $(pyright_compatible),SETUPTOOLS_ENABLE_FEATURES="legacy-editable" )$(if $(CDM_USE_UV),uv ,)pip install $(if $(2),-U )-r "$(1)"$(if $(local), --no-index -f "$(root_dir)/$(index)") $(if $(constraints),-c $(constraints)) || exit 1;
endef

define self-install
$(if $(pyright_compatible),SETUPTOOLS_ENABLE_FEATURES="legacy-editable" )$(if $(CDM_USE_UV),uv ,)pip install -e'.$(if $(1),[$(1)])' $(if $(local), --no-index -f "$(root_dir)/$(index)") $(if $(constraints),-c $(constraints)) || exit 1;
endef

define resolve-package-extras
$(package_extras-$(alternative)-$(1))
endef

define deps-install
for f in requirements.txt pip-requirements.txt; do \
	if [ -f "$$f" ]; then $(call pip-file,$$f,$(upgrade_requirements)) fi; \
done;
endef

define dev-install
if [ "$(develop)" != "" ] && [ -f "dev-requirements.txt" ]; then \
	$(call pip-file,dev-requirements.txt) \
fi;
endef

define	ensure-ckan
@if [ ! -d "$(root_dir)/ckan" ]; then \
	echo "CKAN is not available at $(root_dir)/ckan"; \
	exit 0; \
fi;
endef

define checkout-branch
git checkout -B $(1) origin/$(1); \
git reset --hard origin/$(1);
endef

define checkout-tag
git checkout $(1);
endef

define checkout-commit
git checkout $(1);
endef

define checkout-target
$(call checkout-$(2),$(1))
endef

define download-branch-or-tag
$(eval remote := $(1))
$(eval target := $(2))
$(eval ext_path := $(3))
@echo "Running: git clone $(shell echo '$(remote)' | sed 's|://[^@]*@|://*****:*****@|') --depth 1 $(ext_path)"
@git clone $(remote) --branch $(target) --depth 1 $(ext_path) && rm -rf $(ext_path)/$*/.git;
endef

define download-branch
$(call download-branch-or-tag,$(1),$(2),$(3))
endef

define download-tag
$(call download-branch-or-tag,$(1),$(2),$(3))
endef

define download-commit
$(eval remote := $(1))
$(eval target := $(2))
$(eval ext_path := $(3))
git clone --filter=blob:none --no-checkout $(remote) $(ext_path); \
cd $(ext_path); \
git checkout $(target)
endef

define download-target
$(call download-$(2),$(1),$(3),$(4))
endef

define outdated-target
row() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$$@"; }; \
case "$(3)" in \
	branch) \
		if [ ! -d "$(5)/.git" ]; then \
			row error "$(1)" branch "$(4)" - error; \
			exit 0; \
		fi; \
		cd "$(5)"; \
		if ! git fetch -q origin "$(4)" 2>/dev/null; then \
			row error "$(1)" branch "$(4)" - error; \
			exit 0; \
		fi; \
		behind=$$(git rev-list --count HEAD..FETCH_HEAD); \
		latest=$$(git rev-parse --short=8 FETCH_HEAD); \
		status=outdated; \
		if [ "$$behind" = "0" ]; then status=ok; fi; \
		row $$status "$(1)" branch "$(4)" "$$latest" "$$behind commits"; \
		;; \
	commit) \
		if ! head=$$(git ls-remote "$(2)" HEAD 2>/dev/null | cut -f1) || [ -z "$$head" ]; then \
			row error "$(1)" commit "$(4)" - error; \
			exit 0; \
		fi; \
		latest=$$(echo $$head | cut -c1-8); \
		case "$$head" in \
			"$(4)"*) \
				row ok "$(1)" commit "$(4)" "$$latest" "0 commits"; \
				exit 0; \
				;; \
		esac; \
		if [ ! -d "$(5)/.git" ]; then \
			row outdated "$(1)" commit "$(4)" "$$latest" "?"; \
			exit 0; \
		fi; \
		cd "$(5)"; \
		if ! git fetch -q origin HEAD 2>/dev/null \
			|| ! behind=$$(git rev-list --count "$(4)..FETCH_HEAD" 2>/dev/null); then \
			row outdated "$(1)" commit "$(4)" "$$latest" "?"; \
			exit 0; \
		fi; \
		row outdated "$(1)" commit "$(4)" "$$latest" "$$behind commits"; \
		;; \
	tag) \
		if ! refs=$$(git ls-remote --tags --refs "$(2)" 2>/dev/null); then \
			row error "$(1)" tag "$(4)" - error; \
			exit 0; \
		fi; \
		target_ref="$(4)"; \
		prefix=$$(printf '%s' "$$target_ref" | sed -E 's/[0-9].*$$//'); \
		tags=$$(printf '%s\n' "$$refs" | sed 's|.*refs/tags/||' \
			| awk -v p="$$prefix" 'index($$0, p) == 1 && substr($$0, length(p) + 1) ~ /^[0-9]+(\.[0-9]+)*$$/' \
			| sort -V); \
		latest=$$(printf '%s\n' "$$tags" | tail -n1); \
		if [ -z "$$latest" ]; then \
			row error "$(1)" tag "$(4)" - error; \
			exit 0; \
		fi; \
		newer=$$(printf '%s\n' "$$tags" "$(4)" | sort -Vu \
			| awk -v t="$(4)" 'found { n++ } $$0 == t { found = 1 } END { print n + 0 }'); \
		status=outdated; \
		if [ "$$newer" = "0" ]; then status=ok; latest="$(4)"; fi; \
		row $$status "$(1)" tag "$(4)" "$$latest" "$$newer releases"; \
		;; \
	*) \
		row error "$(1)" "$(3)" "$(4)" - error; \
		;; \
esac;
endef

define outdated-table
color=""; \
if [ -t 1 ] && [ -z "$$NO_COLOR" ]; then color=1; fi; \
{ \
	printf 'header\tName\tType\tPinned\tLatest\tBehind\n'; \
	$(MAKE) -s -j$(outdated_jobs) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) $(1); \
} | awk -F '\t' -v color="$$color" -v order="$(patsubst _outdated-%,%,$(patsubst _ckan-outdated,ckan,$(1)))" ' \
	function render(r,    line, i) { \
		line = ""; \
		for (i = 2; i <= 6; i++) line = line sprintf("%-" width[i] "s  ", cell[r, i]); \
		sub(/ +$$/, "", line); \
		if (color) line = "\033[" code[status[r]] "m" line "\033[0m"; \
		print line; \
	} \
	{ status[NR] = $$1; row[$$2] = NR; for (i = 2; i <= NF; i++) { cell[NR, i] = $$i; if (length($$i) > width[i]) width[i] = length($$i) } } \
	END { \
		code["ok"] = "32"; code["outdated"] = "31"; code["error"] = "33"; code["header"] = "1"; \
		render(1); \
		n = split(order, names, " "); \
		for (k = 1; k <= n; k++) { rank[names[k]] = k; if (names[k] in row) render(row[names[k]]); } \
		for (r = 2; r <= NR; r++) if (!(cell[r, 2] in rank)) render(r); \
	}'
endef


define download-packages
pip download . -d "$(root_dir)/$(index)"; \
for f in requirements.txt pip-requirements.txt dev-requirements.txt; do \
	if [ -f "$$f" ]; then pip download -r "$$f" -d "$(root_dir)/$(index)"; fi; \
done;
endef

define resolve-remote
$(or $($(alternative)-$(1)),$(remote-$(1)),$(call ckan-maintained-remote,$(1)))
endef

define ckan-maintained-remote
https://github.com/ckan/ckanext-$(1).git branch master
endef

info:
	@echo CKAN dependencies installer
	@echo
	@echo Usage:
	@echo -e '\tmake [target]'
	@echo TLDR\;
	@echo -e '\tmake prepare'
	@echo -e '\tmake full-upgrade'
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
	@echo -e '\tckan-outdated - check whether newer CKAN tag is available'
	@echo -e '\toutdated-NAME - check whether newer tag/commit of the extension is available'
	@echo -e '\toutdated - perform outdated-NAME for every single dependency and do `ckan-outdated`'
	@echo
	@echo -e '\tckan - clone CKAN repository'
	@echo -e '\tckan-sync - set CKAN to the expected tag'
	@echo -e '\tckan-install - install CKAN with its requirements'
	@echo
	@echo -e '\tself-install - install current extension and its requirements'
	@echo
	@echo -e '\tdownload - download extension source without git history'
	@echo
	@echo -e '\tfull-upgrade - synchronize and install everything(it is just a combination of `sync ckan-sync install ckan-install self-install`)'
	@echo
	@echo -e '\tlocal-index - download all the requirements. This allows you to install the project with `local=1` flag even without internet access'
	@echo
	@echo 'Flags:'
	@echo -e '\tsync*:'
	@echo -e '\t\talternative=<prefix> - try using `<prefix>-<ext>` definition of extensions before falling back to `remote-<ext>`'
	@echo
	@echo -e '\tinstall*:'
	@echo -e '\t\tdevelop=1 - install dev-requirements if present'
	@echo -e '\t\tlocal=1   - use local packages instead of PyPI(you need to build it first via `make local-index`)'
	@echo
	@echo -e '\tinstall*, local-index:'
	@echo -e "\t\tindex=pypi - path to local package index(relative to $$(realpath $(root_dir))). By default: $(index)"
	@echo

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

install ckanext sync check local-index download: $(ext_list:%=$$@-%)
ckanext-% check-% _outdated-% sync-% install-% local-index-% download-% %.tar: ext_path=$(root_dir)/ckanext-$*
ckanext-% check-% _outdated-% sync-% install-% download-%: type = $(word 2, $(call resolve-remote,$*))
ckanext-% check-% _outdated-% sync-% install-% download-%: remote = $(firstword $(call resolve-remote,$*))
ckanext-% check-% _outdated-% sync-% install-% download-%: target = $(word 3, $(call resolve-remote,$*))
install-%: package_extras = $(call resolve-package-extras,$*)
archive: $(ext_list:%=%.tar)

install-ckan:
	$(error Use 'ckan-install' rule if you need to install CKAN core)

ckanext-%:
	@echo [Clone $* into $(ext_path)]
	@echo "Running: git clone $(shell echo '$(remote)' | sed 's|://[^@]*@|://*****:*****@|') $(ext_path)"
	@git clone $(if $(with_submodules),--recurse-submodules )$(remote) $(ext_path);
	cd $(ext_path); \
	$(call checkout-target,$(target),$(type))

sync-%: ckanext-%
	@echo [Synchronize $*];
	cd $(ext_path); \
	git remote set-url origin $(remote); \
	git fetch origin --tags;
	cd $(ext_path); \
	git reset --hard; \
	$(call checkout-target,$(target),$(type)) \
	git clean -df;


download-%:
	@echo [Download $* into $(ext_path) - $(type) $(target)]
	@echo "Removing existing $* folder"
	rm -rf $(ext_path); \
	$(call download-target,$(target),$(type),$(remote),$(ext_path))


ckan ckan-download: ckan_path=$(root_dir)/ckan

ckan ckan-sync _ckan-outdated ckan-download: type = $(word 2, $(call resolve-remote,ckan))
ckan ckan-sync _ckan-outdated ckan-download: remote = $(firstword $(call resolve-remote,ckan))
ckan ckan-sync ckan-check _ckan-outdated ckan-download: target = $(lastword $(call resolve-remote,ckan))
ckan:
	@echo [Clone ckan into $(ckan_path)]
	@echo "Running: git clone $(shell echo '$(remote)' | sed 's|://[^@]*@|://*****:*****@|') $(ext_path)"
	@git clone $(remote) $(ckan_path);

ckan-download:
	@echo [Download CKAN into $(ckan_path) - $(type) $(target)]
	@echo "Removing existing $* folder"
	rm -rf $(ckan_path); \
	$(call download-target,$(target),$(type),$(remote),$(ckan_path))

ckan-sync: ckan
	$(call ensure-ckan)
	cd $(root_dir)/ckan; \
	git remote set-url origin $(remote); \
	git fetch origin --tags;
	cd $(root_dir)/ckan; \
	git reset --hard; \
	$(call checkout-target,$(target),$(type)) \
	git clean -df;

ckan-install:
	$(call ensure-ckan)
	cd $(root_dir)/ckan; \
	$(call self-install) \
	$(call deps-install) \
	$(call dev-install)

self-install:
	$(call self-install) \
	$(call deps-install) \
	$(call dev-install)

install-%: ckanext-%
	cd $(ext_path); \
	$(call self-install,$(package_extras)) \
	$(call deps-install) \
	$(call dev-install)

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
		git fetch origin --tags; \
		if [ "$$(git log ..origin/$$branch)" != "" ]; then \
			echo $* remote has extra commits; \
			exit 0; \
		fi; \
	elif [ "$(type)" = "commit" ] || [ "$(type)" = "tag" ]; then \
		expected=$$(git rev-list -n1 $(target)); \
		current=$$(git rev-list -n1 HEAD); \
		if [ "$$current" != "$$expected" ]; then \
			if [ "$(type)" = "tag" ]; then\
				echo "$* commit is different from $(target)($$expected): $$current"; \
			else \
				echo "$* commit is different from $(target): $$current"; \
			fi; \
			exit 0; \
		fi; \
	fi; \
	echo $* is up-to-date;

ckan-check:
	$(call ensure-ckan)
	@cd $(root_dir)/ckan; \
	current_tag=$$(git describe --tags); \
	if [ "$$current_tag" != "$(target)" ]; then \
		echo "CKAN is using wrong tag: $$current_tag. Expected: $(target)"; \
		exit 0; \
	else \
		echo "CKAN is using correct tag: $$current_tag"; \
	fi;

outdated:
	@$(call outdated-table,_ckan-outdated $(ext_list:%=_outdated-%))

outdated-%:
	@$(call outdated-table,_outdated-$*)

ckan-outdated:
	@$(call outdated-table,_ckan-outdated)

_outdated-%:
	@$(call outdated-target,$*,$(remote),$(type),$(target),$(ext_path))

_ckan-outdated:
	@$(call outdated-target,ckan,$(remote),$(type),$(target),$(root_dir)/ckan)

full-upgrade: ckan-sync sync ckan-install install self-install

local-index:
	$(call ensure-ckan)
	cd $(root_dir)/ckan; \
	pip download wheel setuptools -d "$(root_dir)/$(index)"; \
	$(call download-packages)

local-index-%:
	cd $(ext_path); \
	$(call download-packages)

%.tar:
	tar cvf $(root_dir)/$@ --exclude-vcs $(ext_path)

archive:
	tar cvf $(root_dir)/src.tar --exclude-vcs $(root_dir)/ckan;
	for ext in $(ext_list); do \
		tar Af $(root_dir)/src.tar --exclude-vcs "$(root_dir)/$$ext.tar"; \
		rm -f $(root_dir)/$$ext.tar; \
	done;
	self=$$(basename $$PWD); \
	tar cvf "$(root_dir)/$$self.tar" "$(root_dir)/$$self/deps.mk" --exclude-vcs "$(root_dir)/$$self"; \
	tar Af $(root_dir)/src.tar "$(root_dir)/$$self.tar"; \
	rm -f "$(root_dir)/$$self.tar"

	tar cvf "$(root_dir)/$(index).tar" "$(root_dir)/$(index)"; \
	tar Af $(root_dir)/src.tar "$(root_dir)/$(index).tar"; \
	rm -f "$(root_dir)/$(index).tar"

	gzip < "$(root_dir)/src.tar" > "$(root_dir)/src.tar.gz"
	rm -f "$(root_dir)/src.tar"
