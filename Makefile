###############################################################################
#                             requirements: start                             #
###############################################################################
ckan_tag = ckan-2.12.0

ext_list = files file-keeper-cloud 

remote-file-keeper-cloud = https://github.com/ckan/ckanext-file-keeper-cloud commit 50954e8 # 2026-05-14
remote-files = https://github.com/DataShades/ckanext-files tag v1.3.2
###############################################################################
#                              requirements: end                              #
###############################################################################

_version = master

-include deps.mk

prepare:
	curl -O https://raw.githubusercontent.com/DataShades/ckan-deps-installer/$(_version)/deps.mk
