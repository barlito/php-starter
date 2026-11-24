# Example CI workflow

Ready-to-use GitHub Actions workflow for a project bootstrapped from this starter.
It lives here (and **not** in `.github/workflows/`) so it doesn't run on the starter
repository itself, which validates its own bootstrap in `symfony_starter.yaml`.

`ci.yaml` calls the reusable `php-ci` and `docker-check` workflows of
[`barlito/ci`](https://github.com/barlito/ci): the CI stack is started with `make deploy.ci`,
every check then every test target is run, and the stack is always removed.
Everything goes through the `make` targets of the [`php-make-rules`](https://github.com/barlito/php-make-rules)
submodule, so nothing project-specific is hardcoded in the workflow.

## How to use

1. Copy it into your project's `.github/workflows/`:
   ```bash
   cp .github/workflow-examples/ci.yaml .github/workflows/
   ```
2. Install the quality toolchain once (configs come from `barlito/utils`):
   ```bash
   make package.barlito_utils.install
   make cs_fixer.install
   make phpcs.install
   make phpmd.install
   make phpstan.install
   make phpunit.install
   ```
   Drop `behat` from `tests` if your project has no functional suite; otherwise run
   `make behat.install behat.init` once.

## Notes

- `DOCKER_HUB_USERNAME` / `DOCKER_HUB_READ_ONLY_ACCESS_TOKEN` are optional here: when set, the
  workflow logs in to Docker Hub to avoid pull rate limits.
- The default `GITHUB_TOKEN` is used for Composer's GitHub OAuth to avoid API rate limits.
- `checks` and `tests` are lists of make targets: add your own (`rector`, `behat`...).
