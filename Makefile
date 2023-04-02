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

prepare:
	curl -O https://raw.githubusercontent.com/DataShades/ckan-deps-installer/$(_version)/deps.mk
