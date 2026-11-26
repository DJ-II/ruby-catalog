# Catalog

Catalog is a Rails inventory management application with configurable inventory numbers, typed custom fields and collaborative editing.

## Requirements

- Ruby 4.0.10 (see `.ruby-version`), Bundler and Rails 8.1
- PostgreSQL
- Git

## Local setup (PowerShell)

```powershell
bundle install
$env:PGHOST = "127.0.0.1"
$env:PGPORT = "5433"
$env:PGUSER = "postgres"
$env:PGPASSWORD = Read-Host "Local PostgreSQL password"
$env:PGSSLMODE = "disable"
$env:PGGSSENCMODE = "disable"
bundle exec ruby bin/rails db:create
bundle exec ruby bin/rails db:migrate
bundle exec ruby bin/rails db:seed
bundle exec ruby bin/rails server
```

Adjust `config/database.yml` to your local PostgreSQL installation if the host, port or database names differ. Open `http://localhost:3000`. Use separate development and test databases.

## Tests

```powershell
$env:RAILS_ENV = "test"
bundle exec ruby bin/rails db:migrate
Remove-Item Env:RAILS_ENV
$env:PARALLEL_WORKERS = "1"
bundle exec ruby bin/rails test
```

Never run tests with a production DATABASE_URL.

## Administrator

Register an account, then run the following against the intended environment:

```powershell
$env:EMAIL = Read-Host "Account email"
bundle exec ruby bin/rails admin:grant
```

## Deployment

The application uses PostgreSQL and can be deployed as a Render web service. The build script installs dependencies, precompiles assets, migrates the database and seeds predefined categories. Keep secrets in the deployment environment rather than Git.

| Environment variable | Purpose |
| --- | --- |
| RAILS_ENV | production |
| DATABASE_URL | PostgreSQL connection string |
| RAILS_MASTER_KEY | Rails credentials key |
| SECRET_KEY_BASE | Session signing and encryption secret |
| APP_URL | Public HTTPS origin |
| GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET | Google OAuth |
| GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET | GitHub OAuth |
| CLOUDINARY_CLOUD_NAME / CLOUDINARY_UPLOAD_PRESET | Direct image uploads |
| PRIVACY_CONTACT_EMAIL | Optional public contact email for privacy requests |

OAuth callback paths: `/auth/google_oauth2/callback` and `/auth/github/callback`. Configure them on the corresponding provider with the public HTTPS origin.

## Account settings and privacy

Users can change their username or delete their account. Account deletion requires the exact word `DELETE` and the current password or a fresh OAuth callback for an already linked identity. Owned inventories are deleted; items and comments in other inventories retain their content but lose the user association. Cloudinary assets are not automatically removed. Public privacy information is available at `/privacy`.

Set a real contact email before public release. The unsigned upload preset should be restricted to appropriate image formats; consider signed uploads for a wider public deployment.

## Search and authentication safeguards

Search uses PostgreSQL full-text indexes. Inventory results include titles, descriptions, tags, active field definitions and discussion text. Item results include inventory numbers and all stored typed values. The tag filter is independent of the item query.

Automatic inventory numbers use up to ten random candidates checked in one query. Explicitly supplied duplicate numbers are rejected.

Password sign-in allows ten requests per minute per client IP; signup allows five per ten minutes. Rate limits are stored in PostgreSQL using hashed client identifiers and atomic counter updates. The counters are shared across application processes and persist across application restarts. These limits do not cover external OAuth providers.

## Security checks

```powershell
bundle exec brakeman -q --no-pager
bundle exec bundler-audit check --update
```

The dependency scan requires internet access and the deployed project's actual Gemfile.lock. Review any warnings before releasing; do not suppress findings without investigating them.

## Continuous integration

GitHub Actions runs on pushes to `main` and pull requests. It checks Ruby and JavaScript syntax, runs Brakeman and Bundler Audit, and executes the Rails test suite against a dedicated PostgreSQL 18 database created for the job. No production credentials are required. The JavaScript syntax check does not audit third-party CDN dependencies.
