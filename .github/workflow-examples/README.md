# Example CI workflows

Ready-to-use GitHub Actions workflows for a project bootstrapped from this starter.
They live here (and **not** in `.github/workflows/`) so they don't run on the starter
repository itself — copy them into a real project to activate them.

## What they do

| File | Purpose |
| ---- | ------- |
| `entrypoint.yaml` | Runs on every `push`; fans out to the two reusable workflows below. |
| `test.yaml` | Boots the CI stack, installs dependencies, migrates the test DB, runs **PHPUnit** and **Behat**. |
| `code-quality.yaml` | Boots the CI stack and runs **php-cs-fixer** (dry-run), **phpcs**, **phpmd**. |

Everything goes through the `make` targets from the [`php-make-rules`](https://github.com/barlito/php-make-rules)
submodule, so the workflows are project-agnostic (no stack name hardcoded).

## How to use

1. Copy the three `*.yaml` files into your project's `.github/workflows/`:
   ```bash
   cp .github/workflow-examples/{entrypoint,test,code-quality}.yaml .github/workflows/
   ```
2. Make sure the targets they call exist (they ship with `php-make-rules`):
   `docker.deploy.ci`, `composer.install`, `doctrine.migrate.ci`, `phpunit`,
   `behat.install`, `behat.init`, `behat`, `cs_fixer.dry_run`, `phpcs`, `phpmd`,
   `docker.undeploy.ci`.
3. Install the quality toolchain once (configs come from `barlito/utils`):
   ```bash
   make package.barlito_utils.install
   make cs_fixer.install
   make phpcs.install
   make phpmd.install
   ```

## Notes

- **Docker Hub login is optional.** Set the `DOCKER_HUB_USERNAME` / `DOCKER_HUB_ACCESS_TOKEN`
  repository secrets to avoid pull rate limits; the step is skipped when they're absent.
- `code-quality.yaml` skips the database migration (the linters don't need it).
- The default `GITHUB_TOKEN` is used for Composer's GitHub OAuth to avoid API rate limits.
- Behat is optional: drop the three `Behat` steps in `test.yaml` if your project has no functional suite.
- Actions are pinned to `checkout@v6` / `cache@v5` / `setup-castor@v1.0.0`.
