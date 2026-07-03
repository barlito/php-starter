# Vars
stack_name=starter
app_container_id = $(shell docker ps --filter name="$(stack_name)_php" -q)
db_container_id = $(shell docker ps --filter name="$(stack_name)_db" -q)
prod_host=starter.example.com
backup_path=/srv/$(stack_name)/backups

# Config paths
config_cs_fixer=vendor/barlito/utils/config/.php-cs-fixer.dist.php
config_phpcs=vendor/barlito/utils/config/phpcs.xml.dist
config_phpmd=vendor/barlito/utils/config/phpmd.xml

# Include all make rules from submodule
include make/entrypoint.mk

### Project-specific rules

# PHPStan
phpstan:
	docker exec -t $(app_container_id) php -d "memory_limit=512M" vendor/bin/phpstan analyse

phpstan.install:
	docker exec -t $(app_container_id) bash -c "composer require --dev phpstan/phpstan phpstan/phpstan-symfony phpstan/phpstan-doctrine"

# Aggregate quality check
quality:
	make cs_fixer.dry_run
	make phpcs
	make phpmd
	make phpstan

# Database backup (pg_dump, skipped if DB not running)
db.backup:
	@cid="$$(docker ps --filter name='$(stack_name)_db' -q | head -1)"; \
	if [ -n "$$cid" ]; then \
		ts="$$(date +%Y%m%d-%H%M%S)"; \
		echo "Backup DB -> $(backup_path)/$(stack_name)-$$ts.dump (container $$cid)"; \
		docker exec -t "$$cid" sh -c "pg_dump -U $(stack_name) -F c -d $(stack_name) -f /backups/$(stack_name)-$$ts.dump"; \
	else \
		echo "DB container not found, backup skipped (first deploy?)"; \
	fi

# Smoke test (curl GET / -> fail if non-2xx)
smoke.test:
	@echo "Smoke test https://$(prod_host)/..."
	@curl -fsS -o /dev/null -w "  HTTP %{http_code}\n" https://$(prod_host)/ || (echo "Smoke test FAILED" && exit 1)
	@echo "Smoke test OK"

# Override deploy.prod: chains backup -> migrate -> smoke test
deploy.prod:
	make docker.deploy.prod
	castor barlito:castor:wait-php-container
	castor barlito:castor:wait-db-container
	make db.backup
	make doctrine.migrate
	make smoke.test

### npm rules (one-shot container)
npm_exec_params=--rm -v $(shell pwd):/app -w /app
npm_image=node:22

npm.command:
	docker run $(npm_exec_params) $(npm_image) npm $(args)

npm.install:
	make npm.command args="install"

npm.build:
	make npm.command args="run build"

npm.dev:
	make npm.command args="run dev"

npm.watch:
	make npm.command args="run watch"
