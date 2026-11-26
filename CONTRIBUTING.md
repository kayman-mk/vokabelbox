# Contributing

Thanks for helping improve Vokabelhain. The repository is currently in the planning stage, so changes should keep the implementation aligned with [the specification](docs/SPECIFICATION.md).

## Before you start

- Search existing issues and pull requests to avoid duplicate work.
- For substantial behavior or architecture changes, open an issue first and describe the user need and proposed approach.
- Keep changes focused. Update the specification when a product decision changes.
- Do not commit credentials, real user data, uploaded vocabulary files, or production configuration.

## Pull requests

1. Create a branch from `main`; do not push feature work directly to `main`.
2. Make one cohesive change and include relevant documentation.
3. Run the checks applicable to the changed files and describe the results. When application code is added, its implementation PR should add or update the relevant automated checks.
4. Open a pull request with a clear title and a concise description of the change, motivation, and verification.
5. Link related issues and include screenshots for user-facing UI changes when useful.

Pull requests are squash-merged. The PR title and description are used as the squash commit message on `main`, so write them as a clear, durable summary of the change. Titles must follow Conventional Commits, for example `docs: add repository guidance` or `feat(vocabulary): add list management`. A `feat` title increments the minor version, a title with `!` increments the major version, and all other types increment the patch version. For example, `feat!: replace the import format` is a major change.

## Scope and review

Keep changes consistent with the selected Flutter/Dart client, PHP REST API, and MySQL architecture unless an approved decision changes it. Avoid adding dependencies or generated files without explaining why. Maintainers may request revisions or split changes that combine unrelated work.

## Licensing contributions

By submitting a contribution for inclusion in Vokabelhain, you agree that your contribution is offered under the project's [PolyForm Noncommercial License 1.0.0](LICENSE). Submit only work that you have the right to contribute under these terms.

## Community standards

By participating, you agree to follow the expectations in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
