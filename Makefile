###############################################################################
#                             requirements: start                             #
###############################################################################
ckan_tag = ckan-2.10.0
ext_list = spatial

remote-spatial = https://github.com/ckan/ckanext-spatial.git tag v1.1.0

###############################################################################
#                              requirements: end                              #
###############################################################################

_version = master

-include deps.mk

prepare:  ## download function definitions
	curl -O https://raw.githubusercontent.com/DataShades/ckan-deps-installer/$(_version)/deps.mk

ihelp:  ## show internal documentation
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

changelog:  ## compile changelog
	git changelog -o CHANGELOG.md -c conventional
