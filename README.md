# Catalog

Catalog is a Rails inventory management application with configurable inventory numbers, typed custom fields and collaborative editing.

## Requirements

- Ruby 4.0.7 (see `.ruby-version`), Bundler and Rails 8.1
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

Adjust the port and database settings to your local PostgreSQL installation. Open `http://localhost:3000`. Use separate development and test databases.

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
