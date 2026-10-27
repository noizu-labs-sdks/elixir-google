# AGENT-README

> Orientation for AI coding agents working in this repo. Human docs: README.md.

## Type

elixir-lib

## Purpose

Google REST API client for Elixir (`Noizu.Google`): OAuth2 (authorize, token exchange, refresh, service-account JWT bearer), Finch + Jason HTTP stack, structured errors, and thin wrappers for Search Console, GA4 Admin/Data, AdSense Management, and Google Ads. Hand-written client, not a generated surface.

## Stack

Elixir (~> 1.14). Runtime deps: Finch + Jason only; mimic + junit_formatter for test. OTP app `:noizu_google` v0.2.4 — starts a named Finch pool (`Noizu.Google.Finch`).

## Dev mode

```bash
mix deps.get && mix compile
```

## Ports / URLs

- none (library/CLI)

## Tests

```bash
mix test
```

## Gotchas

- App config reads `GOOGLE_ACCESS_TOKEN`, `GOOGLE_REFRESH_TOKEN`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_APPLICATION_CREDENTIALS` (service-account JSON), plus `GOOGLE_ADS_DEVELOPER_TOKEN` / `GOOGLE_ADS_LOGIN_CUSTOMER_ID` for Google Ads.
- Service-account keys must never be committed — point `:credentials_file` at a local key file.
- Search Console: the service-account email must be added as a user on each property.
- Test coverage threshold is 30% (`mix.exs`).
