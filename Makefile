# Vars
stack_name=stack_name
project_url=starter.local.barlito.fr
app_container_id = $(shell docker ps --filter name="$(stack_name)_nginx" -q)

# Config paths
config_cs_fixer=vendor/barlito/utils/config/.php-cs-fixer.dist.php
config_phpcs=vendor/barlito/utils/config/phpcs.xml.dist
config_phpmd=vendor/barlito/utils/config/phpmd.xml

# Include all make rules from submodule
include make/entrypoint.mk
