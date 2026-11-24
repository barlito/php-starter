# barlito/php-starter

[![CI](https://github.com/barlito/php-starter/actions/workflows/symfony_starter.yaml/badge.svg?branch=master)](https://github.com/barlito/php-starter/actions/workflows/symfony_starter.yaml)

Symfony starter template with FrankenPHP, Docker Swarm, and a full CI/CD pipeline.

## Stack

- **FrankenPHP** (PHP 8.5) — single-binary server with Caddy
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

Active workflows in `.github/workflows/`. Release, deploy, rollback, scan and compose check are thin
callers of the reusable workflows of [barlito/ci](https://github.com/barlito/ci) (`@v1`); the project-specific
part lives in the `Makefile` (stack, image and service names, production host) and in the
[`php-make-rules`](https://github.com/barlito/php-make-rules) production rules.

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `symfony_starter.yaml` | Push | Validates the starter itself (bootstrap + PHPUnit/Behat) |
| `docker-check.yaml` | PR | Builds the prod targets and validates `docker-compose-prod.yml` |
| `security.yaml` | Weekly cron | Trivy image scan (`image-scan`) |
| `release.yaml` | GitHub Release | Build + push Docker images (`docker-release`) |
| `deploy.yaml` | Manual, `--ref vX.Y.Z` | Image-only rolling update, or full stack deploy with `re-deploy` (`swarm-deploy`, never `stack rm`) |
| `rollback.yaml` | Manual | Rollback to a tag, migrations reverted or database restored (`swarm-rollback`) |
| `dependabot-auto-merge.yaml` | PR | Auto-merge patch updates |

Deploy from the release tag: `gh workflow run deploy.yaml --ref v1.2.3` (add `-f re-deploy=true` for a full deploy).

A copy-paste CI workflow for real projects (`php-ci`) lives in [`.github/workflow-examples/`](.github/workflow-examples/)
(it doesn't run on the starter).

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
- The image-only path (`deploy.yaml` without `re-deploy`, i.e. `make deploy.update`) does not apply compose changes: run a `re-deploy` after
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

The stack name lives in the `Makefile` (`stack_name`, which also drives the image names, the DB user and name,
the backup path...), `castor.php`, the compose files and the image names of `release.yaml`, `deploy.yaml` and
`rollback.yaml`. Update all at once:

```bash
castor barlito:castor:set-stack-name my_project
```

Then set `prod_host` in the `Makefile` and the host rules in `docker-compose-prod.yml`.

## Secrets and variables for deploy

Set on the `production` environment of the repository (see [barlito/ci](https://github.com/barlito/ci#variables-and-secrets)):

| Kind | Name | Purpose |
|------|------|---------|
| variable | `SERVER_HOST` | Production server hostname |
| secret | `SERVER_USERNAME`, `SERVER_PORT` | SSH user and port |
| secret | `SERVER_HOST_KEY` | `known_hosts` line of the server ed25519 key |
| secret | `SSH_PRIVATE_KEY` | SSH access to production server |
| secret | `DOCKER_HUB_USERNAME`, `DOCKER_HUB_READ_ONLY_ACCESS_TOKEN` | Docker Hub pull |
| secret | `DB_PASSWORD`, `APP_SECRET` | Production database password, Symfony `APP_SECRET` (listed in `env-secrets`) |

Repository level, for `release.yaml`: `DOCKER_HUB_USERNAME` and `DOCKER_HUB_READ_WRITE_DELETE_ACCESS_TOKEN`.

## Related

- [barlito/traefik-base](https://github.com/barlito/traefik-base) — Traefik proxy stack
- [barlito/php-make-rules](https://github.com/barlito/php-make-rules) — Reusable Make rules submodule
- [barlito/utils](https://github.com/barlito/utils) — Shared code quality configs
