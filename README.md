# barlito/php-starter

[![CI](https://github.com/barlito/php-starter/actions/workflows/symfony_starter.yaml/badge.svg?branch=master)](https://github.com/barlito/php-starter/actions/workflows/symfony_starter.yaml)

Symfony starter template with FrankenPHP, Docker Swarm, and a full CI/CD pipeline.

## Stack

- **FrankenPHP** (PHP 8.3) — single-binary server with Caddy
- **PostgreSQL 18** — with healthcheck
- **Docker Swarm** — production orchestration with Traefik
- **Supervisor** — async Messenger worker management
- **Make + Castor** — task automation

## Quick Start

```bash
# Clone
git clone https://github.com/barlito/php-starter.git my-project
cd my-project && rm -rf .git && git init
git submodule update --init --recursive

# Configure
castor barlito:castor:set-stack-name my_project

# Deploy
make docker.deploy
make symfony.install
```

App runs at the URL configured in your Traefik setup (default: `starter.local.barlito.fr`).

## Requirements

- Docker (Swarm mode)
- Make
- [Castor](https://castor.jolicode.com/)
- [barlito/traefik-base](https://github.com/barlito/traefik-base) running

## Commands

### Stack

```bash
make docker.deploy          # Deploy dev stack
make docker.bash            # Shell into PHP container
make deploy.prod            # Full prod deploy (backup → rolling stack deploy → assert → migrate → smoke test → prune)
make deploy.assert_image    # Fail unless <stack>_php runs $TAG, was not rolled back and is healthy
make deploy.prune           # Remove the stack's stopped containers
make undeploy               # Remove stack
```

### Code Quality

```bash
make quality                # Run all checks
make cs_fixer               # Fix code style
make phpcs                  # PHP CodeSniffer
make phpmd                  # Mess Detector
make phpstan                # Static analysis (level 6)
```

### Testing

```bash
make phpunit                # Unit/functional tests
make behat                  # BDD tests
```

### Database

```bash
make doctrine.migrate       # Run migrations
make doctrine.diff          # Generate migration from entity changes
make doctrine.reset_db      # Drop + recreate database
make doctrine.load_fixtures # Load test fixtures
make db.backup              # pg_dump to backup directory
```

### npm

```bash
make npm.install            # Install node deps
make npm.build              # Production build
make npm.watch              # Watch mode
```

## CI/CD

Active workflows in `.github/workflows/`:

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `symfony_starter.yaml` | Push | Validates the starter itself (bootstrap + PHPUnit/Behat) |
| `security.yaml` | Called + Weekly cron | Trivy image vulnerability scan |
| `release.yaml` | GitHub Release | Build + push Docker images |
| `deploy.yaml` | Manual | Image-only rolling update, or full stack deploy (never `stack rm`) |
| `rollback.yaml` | Manual | Rollback to tag + optional migration revert |
| `dependabot-auto-merge.yaml` | PR | Auto-merge patch updates |

Copy-paste examples for real projects live in [`.github/workflow-examples/`](.github/workflow-examples/)
(they don't run on the starter): a reusable `entrypoint` that fans out to `test`
(PHPUnit + Behat) and `code-quality` (php-cs-fixer / phpcs / phpmd). See that folder's
README for details.

## Deployment safety

- `php` updates are **start-first** with `failure_action: rollback`: the old task keeps serving until the new one
  passes its healthcheck (Caddy `:2019/metrics` only — never PHP/DB, a schema-dependent check would roll back every
  deploy carrying a migration). Databases and the worker stay stop-first.
- Traefik routes through the Swarm VIP (`traefik.swarm.lbswarm=true`): without it, Traefik can keep the old task IP
  for a few seconds during start-first (502s). Drop the label if Traefik-side balancing is needed (sticky sessions).
- `docker service update` / `docker stack deploy` exit 0 even after Swarm rolled back: `make deploy.assert_image`
  is what fails the job.
- Migrations run **after** the new code is up, and old/new code overlap for a few seconds: keep them
  backward-compatible (expand/contract).
- The image-only path (`deploy.yaml` without `re-deploy`) does not apply compose changes: run a `re-deploy` after
  changing `docker-compose-prod.yml`.

## Docker Targets

The Dockerfile has multiple build targets:

| Target | Usage |
|--------|-------|
| `frankenphp_dev` | Local development with live reload |
| `frankenphp_worker_dev` | Dev Messenger worker (supervisor) |
| `frankenphp_prod` | Optimized production image |
| `frankenphp_worker_prod` | Production Messenger worker |

## Project Structure

```
.docker/
├── Dockerfile              # Multi-stage build
├── franken/Caddyfile       # FrankenPHP server config
├── php/app.ini             # Shared PHP config
├── php/app.prod.ini        # OPcache production tuning
└── supervisor.d/           # Messenger worker config

.github/
├── workflows/              # CI/CD pipelines
└── dependabot.yml          # Auto dependency updates

make/                       # Git submodule (barlito/php-make-rules)
├── app/                    # App rules (composer, doctrine, tests, style)
└── stack/                  # Docker & deployment rules
```

## Configuration

Stack name is centralized in 3 files (`Makefile`, `castor.php`, `docker-compose.yml`).
Update all at once:

```bash
castor barlito:castor:set-stack-name my_project
```

## Secrets Required for Deploy

| Secret | Purpose |
|--------|---------|
| `SSH_PRIVATE_KEY` | SSH access to production server |
| `DOCKER_HUB_USERNAME` | Docker Hub login |
| `DOCKER_HUB_ACCESS_TOKEN` | Docker Hub token |
| `DB_PASSWORD` | Production database password |
| `APP_SECRET` | Symfony APP_SECRET |

| Variable | Purpose |
|----------|---------|
| `SERVER_HOST` | Production server hostname |
| `SERVER_PORT` | SSH port |
| `SERVER_USERNAME` | SSH user |

## Related

- [barlito/traefik-base](https://github.com/barlito/traefik-base) — Traefik proxy stack
- [barlito/php-make-rules](https://github.com/barlito/php-make-rules) — Reusable Make rules submodule
- [barlito/utils](https://github.com/barlito/utils) — Shared code quality configs
