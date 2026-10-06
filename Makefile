# Vars
stack_name=starter
app_container_id = $(shell docker ps --filter name="$(stack_name)_php" -q)
db_container_id = $(shell docker ps --filter name="$(stack_name)_db" -q)
prod_host=starter.example.com
backup_path=/srv/$(stack_name)/backups
# Same default as docker-compose-prod.yml; the deploy workflows export DOCKER_IMAGE
image_name=$(or $(DOCKER_IMAGE),$(stack_name))
prod_compose_file=docker-compose-prod.yml
deploy_timeout=300
assert_timeout=180
assert_settle=10

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

# Rolling stack deploy, never `stack rm`: a recreated service has nothing to roll back to
deploy.prod:
	make db.backup
	make docker.deploy.prod
	make deploy.assert_image
	castor barlito:castor:wait-db-container
	make doctrine.migrate
	make smoke.test
	make deploy.prune

# Waits for convergence or rollback; a crash-looping new service never converges, assert_image reports it
docker.deploy.prod:
	docker compose -f $(prod_compose_file) pull
	@timeout $(deploy_timeout) docker stack deploy --detach=false -c $(prod_compose_file) $(stack_name) \
		|| { rc=$$?; [ $$rc -eq 124 ] && echo "$(stack_name) not converged after $(deploy_timeout)s"; [ $$rc -eq 124 ]; }

# Swarm rollbacks exit 0: fail unless the service really runs the tag, healthy (php-make-rules castor task)
deploy.assert_image:
	castor barlito:castor:assert-deployed $(stack_name)_php $(image_name):$(or $(TAG),latest) --timeout=$(assert_timeout) --settle=$(assert_settle)

# Removes the stack's stopped containers (old tasks); prune never touches running ones
deploy.prune:
	docker container prune -f --filter label=com.docker.stack.namespace=$(stack_name)

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
