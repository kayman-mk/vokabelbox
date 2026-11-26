# VokabelBox

VokabelBox is a multi-user vocabulary learning application planned for desktop browsers, tablets, and phones. The planned client uses Flutter and Dart for web, Android, and iOS, backed by a PHP REST API and MySQL.

The product specification is in [docs/SPECIFICATION.md](docs/SPECIFICATION.md). The repository includes a runnable starter site and local development stack.

## Planned capabilities

- Private and shared vocabulary lists with per-user learning progress.
- Seven learning modes: 5-box Leitner, 7-box Leitner, FSRS, free flashcards, random practice, error practice, and exam mode.
- Self-assessment and typed-answer checking.
- CSV import with preview, column mapping, validation, and an import report.
- Responsive use on desktop, tablet, Android, and iOS.
- Online-first operation, with offline study planned for a later phase.

## Run locally

Requirements: Docker Desktop with Docker Compose.

```powershell
Copy-Item .env.example .env
# Edit .env and replace the local passwords before the first start.
docker compose up --build
```

Open [http://localhost:8081](http://localhost:8081) and sign in with the development account configured by `DEV_ADMIN_USERNAME` and `DEV_ADMIN_PASSWORD` in `.env`. The defaults in `.env.example` are for local development only. The site binds to localhost; do not use these defaults for a deployed environment.

Stop the services with `docker compose down`. MySQL data persists in a named volume. To reset the local database and delete its data, use `docker compose down --volumes`.

## Current implementation

The starter site supports login, creating private vocabulary lists, adding/listing word pairs, importing vocabulary from UTF-8 CSV files, and FSRS spaced-repetition study in both translation directions. FSRS review progress is stored per user, vocabulary card, method, and direction; the backend owns scheduling and keeps review events. Each vocabulary box has a statistics view with card progress, rating totals, and recent daily activity for each direction. CSV import supports comma or semicolon delimiters, a header row, prompt/answer column mapping, a preview, and a 500-row limit. Invalid rows are shown and excluded; duplicate prompt/answer pairs are skipped case-insensitively, without overwriting existing words. The confirmed valid rows are imported atomically. Screen widgets live in separate files under `client/lib/screens/`; shared presentation widgets and theme constants are in `client/lib/widgets/` and `client/lib/app_theme.dart`. Other learning methods, shared lists, mobile builds, and offline operation are not implemented yet. Database schema is managed with Phinx migrations in `backend/db/migrations/`. The initial migration creates UUIDv4-compatible `CHAR(36)` primary keys and upgrades the earlier integer schema while preserving rows and relationships. The API generates UUIDv4 identifiers. To inspect or run migrations, use `docker compose exec api php vendor/bin/phinx status -c /var/www/html/phinx.php -e development` or `docker compose exec api php vendor/bin/phinx migrate -c /var/www/html/phinx.php -e development`. The initial local account is created from `DEV_ADMIN_USERNAME` and `DEV_ADMIN_PASSWORD` only when that username is absent; changing `.env` will not reset an existing account. See [the specification](docs/SPECIFICATION.md) for the full product plan and open decisions.

## FSRS reference

VokabelBox has an independent PHP implementation of FSRS-4.5, using the published default parameters and 90% desired retention. See the [FSRS algorithm reference](https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm) for the formulas and version details, and the [Open Spaced Repetition `py-fsrs` project](https://github.com/open-spaced-repetition/py-fsrs) for a reference implementation.

The local stack uses Flutter Web, PHP-FPM, Nginx, and MySQL. Backend connection and development-account settings are centralized in `backend/config.php` and populated from the Compose environment. Only the web app is published to the host, on `127.0.0.1`; the API and database remain inside the Compose network. This development setup is not configured for public deployment (for example, it has no production TLS termination or login rate limiting).

## Tests

Run the UUID unit test with PHP 8.4 using `php backend/tests/uuid_test.php`. Run the CSV parser unit tests from `client/` with `flutter test`. Run the infrastructure tests with `python tests/run_infra_tests.py`. The infrastructure runner creates a uniquely named Compose project on port `18081`, with its own MySQL volume and `test` / `test` development account, then removes that test project's containers and volume when finished. It does not connect to or change the normal local stack on port `8081`.

## CI deployment package

Every pull request, push to `main`, and published GitHub Release builds the Flutter web app and publishes a `www` workflow artifact containing `www.tgz`. Publishing a Release also deploys the archive contents to the server over FTPS after all CI jobs pass. Set these GitHub Actions repository secrets:

- `FTPS_DEPLOY_HOST`: FTPS server hostname.
- `FTPS_DEPLOY_USERNAME` and `FTPS_DEPLOY_PASSWORD`: deployment credentials.
- `FTPS_DEPLOY_PATH`: server directory for the web document root, with a trailing slash (for example, `/public_html/`).

The deployment clears the target directory before uploading, so files there that are absent from the archive are deleted. Keep `FTPS_DEPLOY_PATH` scoped to the site's document root. The archive contains the static web client only; configure the web server to route `/api/` requests to the VokabelBox PHP API. The client is built with `/api/v1` as its API base URL.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request. Pull requests are merged using squash commits; the pull request title and description become the resulting commit message on `main`.

## Security

Please report security vulnerabilities privately. See [SECURITY.md](SECURITY.md).

## License

VokabelBox is licensed under the [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0). It permits use only for purposes allowed by that license; commercial purposes are not granted. Read [LICENSE](LICENSE) for the complete terms. This is a source-available license, not an OSI-approved open-source license.
