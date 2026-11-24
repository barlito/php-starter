# Vars
stack_name=starter
app_container_id = $(shell docker ps --filter name="$(stack_name)_php" -q)
db_container_id = $(shell docker ps --filter name="$(stack_name)_db" -q)
prod_host=starter.example.com
image_name=barlito/$(stack_name)
worker_image_name=$(image_name)-worker
# Read by docker-compose-prod.yml
export DOCKER_IMAGE=$(image_name)

# Config paths
config_cs_fixer=vendor/barlito/utils/config/.php-cs-fixer.dist.php
config_phpcs=vendor/barlito/utils/config/phpcs.xml.dist
config_phpmd=vendor/barlito/utils/config/phpmd.xml

# Include all make rules from submodule
include make/entrypoint.mk

### Project-specific rules

# PHPMD: Kernel.php is framework boilerplate (Symfony 8.1's private getAllowedEnvs() is called by the framework, not by our code), excluded like in PHPStan
phpmd:
	docker exec -t $(app_container_id) vendor/bin/phpmd src/ ansi $(config_phpmd) --exclude src/Migrations/,src/Kernel.php,tests/

# Aggregate quality check
quality:
	make cs_fixer.dry_run
	make phpcs
	make phpmd
	make phpstan
