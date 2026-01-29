# Key Facts

Project configuration, infrastructure details, and frequently-needed reference information.

**Never store passwords, API keys, or secrets here.** Use `.env` files or secret managers.

## Tech Stack

- **Elixir**: 1.20 (OTP 28) - managed via asdf (`.tool-versions`)
- **Phoenix**: 1.8.1 + LiveView 1.1
- **PostgreSQL**: 18 (Docker)
- **CSS**: Tailwind CSS v4
- **Bundler**: esbuild
- **Job Queue**: Oban
- **HTTP Client**: Req (not HTTPoison/Tesla)
- **Observability**: OpenTelemetry, ErrorTracker

## Local Development

- **Dev server**: `http://localhost:4000`
- **Live Dashboard**: `http://localhost:4000/dev/dashboard`
- **Email Preview**: `http://localhost:4000/dev/mailbox`
- **Error Tracker**: `http://localhost:4000/dev/errors`
- **Database**: PostgreSQL on `localhost:5432` (user: `postgres`, pass: `postgres`, db: `klass_hero_dev`)
- **Test Database**: Docker-managed (`klass_hero_test`)

## Infrastructure

- **Hosting**: Fly.io (see `fly.toml`)
- **CI/CD**: GitHub Actions (`.github/workflows/`)
- **Deployment config**: `Dockerfile`, `rel/` directory

## Internationalization

- **Languages**: English (`en`), German (`de`)
- **Framework**: Gettext (`priv/gettext/`)

## Payment Integration

- **Provider**: SumUp
- **Merchant code attribute**: `sumup.merchant.code`

## User Roles

- **Parent**: Can browse programs, book, view participation history (`/parent/*`)
- **Provider**: Can manage sessions, track attendance, broadcast messages (`/provider/*`)
- **Admin**: Future role (not yet implemented)

## Key Module Paths

- **Router**: `lib/klass_hero_web/router.ex`
- **Auth helpers**: `lib/klass_hero_web/user_auth.ex`
- **Components**: `lib/klass_hero_web/components/`
- **Theme/design tokens**: `lib/klass_hero_web/components/theme.ex`
- **Web module**: `lib/klass_hero_web.ex` (html_helpers block for app-wide imports)
