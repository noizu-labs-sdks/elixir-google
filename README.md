# Noizu Google

<!-- 〚📁:445b4db8-2b0c-5dfb-95da-d73cc52a1c50〛 Noizu Google README :: Install, configuration, per-API examples, error and scope tables. -->

[![Hex.pm](https://img.shields.io/hexpm/v/noizu_google.svg)](https://hex.pm/packages/noizu_google)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/noizu_google/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/noizu-labs/elixir-google/blob/main/LICENSE)

Google REST API client for Elixir.

OAuth2 bearer auth (authorize, token exchange, refresh, or service-account JWT
bearer), a Finch + Jason HTTP stack, structured errors, and thin wrappers for
the marketing APIs: Search Console, GA4 Admin/Data, AdSense Management, and
Google Ads.

This is a hand-written REST client, not a generated Google API surface. Pass a
`%Noizu.Google.Client{}` on each call, or omit it to use application config.

## Installation

```elixir
def deps do
  [
    {:noizu_google, "~> 0.2.4"}
  ]
end
```

The application starts a named Finch pool (`Noizu.Google.Finch`). Runtime
dependencies are Finch and Jason only.

## Configuration

```elixir
# config/runtime.exs
config :noizu_google,
  access_token: System.get_env("GOOGLE_ACCESS_TOKEN"),
  refresh_token: System.get_env("GOOGLE_REFRESH_TOKEN"),
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
  # Service account (alternative to user OAuth):
  credentials_file: System.get_env("GOOGLE_APPLICATION_CREDENTIALS"),
  # Google Ads only:
  developer_token: System.get_env("GOOGLE_ADS_DEVELOPER_TOKEN"),
  login_customer_id: System.get_env("GOOGLE_ADS_LOGIN_CUSTOMER_ID")
```

Or build a client explicitly and pass it on each call:

```elixir
client = Noizu.Google.client(
  access_token: "...",
  client_id: "...",
  client_secret: "..."
)

Noizu.Google.Api.SearchConsole.Sites.list(client: client)
```

`Noizu.Google.Client.ensure_access_token/1` fills `access_token` from, in
order: an existing bearer token, a service-account JSON file/map
(`:credentials_file` / `:service_account`), or an OAuth refresh token.

Service-account keys must not be committed. Point `:credentials_file` at a
local JSON key (or set `GOOGLE_APPLICATION_CREDENTIALS`). For Search Console
the service account email must be added as a user on each property.

## Quick examples

### Search Console — sites

```elixir
client = Noizu.Google.client(access_token: System.fetch_env!("GOOGLE_ACCESS_TOKEN"))

{:ok, %{siteEntry: sites}} =
  Noizu.Google.Api.SearchConsole.Sites.list(client: client)

{:ok, site} =
  Noizu.Google.Api.SearchConsole.Sites.get("https://example.com/", client: client)
```

### Search Console — search analytics

```elixir
{:ok, report} =
  Noizu.Google.Api.SearchConsole.SearchAnalytics.query(
    "https://example.com/",
    %{
      startDate: "2026-01-01",
      endDate: "2026-01-31",
      dimensions: ["query"],
      rowLimit: 25
    },
    client: client
  )
```

### Search Console — sitemaps

```elixir
site = "https://example.com/"

{:ok, %{sitemap: maps}} =
  Noizu.Google.Api.SearchConsole.Sitemaps.list(site, client: client)

{:ok, _} =
  Noizu.Google.Api.SearchConsole.Sitemaps.submit(
    site,
    "https://example.com/sitemap.xml",
    client: client
  )
```

### GA4 Admin — properties and streams

```elixir
{:ok, %{properties: props}} =
  Noizu.Google.Api.AnalyticsAdmin.Properties.list(
    filter: "parent:accounts/123456",
    client: client
  )

{:ok, prop} =
  Noizu.Google.Api.AnalyticsAdmin.Properties.get("properties/789", client: client)

{:ok, %{dataStreams: streams}} =
  Noizu.Google.Api.AnalyticsAdmin.DataStreams.list("properties/789", client: client)
```

### GA4 Data — runReport

```elixir
{:ok, report} =
  Noizu.Google.Api.AnalyticsData.Reports.run_report(
    "properties/789",
    %{
      dateRanges: [%{startDate: "7daysAgo", endDate: "yesterday"}],
      dimensions: [%{name: "sessionDefaultChannelGroup"}],
      metrics: [%{name: "sessions"}]
    },
    client: client
  )
```

### AdSense

```elixir
{:ok, %{accounts: accounts}} =
  Noizu.Google.Api.AdSense.Accounts.list(client: client)

{:ok, %{adClients: clients}} =
  Noizu.Google.Api.AdSense.AdClients.list("accounts/pub-XXXX", client: client)

{:ok, report} =
  Noizu.Google.Api.AdSense.Reports.generate(
    "accounts/pub-XXXX",
    start_date: ~D[2026-01-01],
    end_date: ~D[2026-01-31],
    metrics: ["ESTIMATED_EARNINGS", "PAGE_VIEWS"],
    dimensions: ["DATE"],
    client: client
  )
```

### Google Ads

Requires an OAuth token with the `adwords` scope plus a developer token
(`:developer_token` on the call, application env, or
`GOOGLE_ADS_DEVELOPER_TOKEN`). MCC logins can pass `:login_customer_id`.

```elixir
cid = "1234567890"
ads_opts = [client: client, developer_token: System.fetch_env!("GOOGLE_ADS_DEVELOPER_TOKEN")]

{:ok, campaigns} =
  Noizu.Google.Api.Ads.Customers.list_campaigns(cid, ads_opts)

{:ok, _} =
  Noizu.Google.Api.Ads.Customers.search(
    cid,
    %{query: "SELECT campaign.id, campaign.name FROM campaign LIMIT 10"},
    ads_opts
  )

{:ok, _} =
  Noizu.Google.Api.Ads.Customers.create_conversion_action(
    cid,
    Keyword.merge(ads_opts, name: "Purchase", dry_run: true)
  )
```

`dry_run: true` (or `validate_only: true`) maps to Google Ads `validateOnly`.

### OAuth2

```elixir
url =
  Noizu.Google.OAuth.authorize_url(
    client_id: "CLIENT_ID",
    redirect_uri: "https://example.com/oauth/callback",
    scope: Noizu.Google.Scopes.marketing_default(),
    access_type: "offline",
    prompt: "consent"
  )

{:ok, tokens} =
  Noizu.Google.OAuth.token(
    code: code,
    redirect_uri: "https://example.com/oauth/callback",
    client: client
  )

{:ok, refreshed} =
  Noizu.Google.OAuth.refresh_token(tokens["refresh_token"], client: client)
```

CLI helpers (from this project, or any Mix project that depends on it):

```sh
mix google.oauth.authorize
mix google.oauth.exchange --code CODE
```

See the [OAuth & secrets runbook](docs/oauth-secrets-runbook.md) for consent
screen setup, scopes, and storing a refresh token.

## Errors

API calls return `{:ok, decoded}` or `{:error, %Noizu.Google.Error{}}`.

| `tag` / `reason` | Meaning |
|------------------|---------|
| HTTP status + `tag` from Google (`PERMISSION_DENIED`, …) | API error body |
| `:transport` | Finch / network failure |
| `:codec` | JSON encode/decode failure |
| `:config` | Missing token, credentials, or Ads developer token |

JSON decode defaults to atom keys (`decode: :atoms`). Pass `decode: :strings`
or `decode: :raw` to change that.

## Scopes

Use `Noizu.Google.Scopes` instead of pasting URLs:

| Helper | Scope |
|--------|--------|
| `search_console/0` | `https://www.googleapis.com/auth/webmasters` |
| `search_console_readonly/0` | `…/webmasters.readonly` |
| `analytics/0` | `…/analytics` |
| `analytics_readonly/0` | `…/analytics.readonly` |
| `analytics_edit/0` | `…/analytics.edit` |
| `adsense/0` | `…/adsense` |
| `adsense_readonly/0` | `…/adsense.readonly` |
| `adwords/0` | `…/adwords` |
| `marketing_default/0` | Search Console + Analytics edit/readonly + AdSense readonly + Ads |

`marketing_default/0` is the offline-consent set used by the Mix tasks. Narrow
it in production.

## Architecture

| Module | Role |
|--------|------|
| `Noizu.Google` | Facade (`client/0`, base URL helpers) |
| `Noizu.Google.Client` | Credentials + per-product base URLs |
| `Noizu.Google.HTTP` | GET/POST/PUT/PATCH/DELETE JSON + bearer auth |
| `Noizu.Google.OAuth` | Authorize URL, token exchange, refresh, JWT bearer |
| `Noizu.Google.ServiceAccount` | Service-account JSON + JWT assertion |
| `Noizu.Google.Scopes` | OAuth scope constants |
| `Noizu.Google.Error` | HTTP / transport / codec / config |
| `Noizu.Google.Api.SearchConsole.*` | Sites, SearchAnalytics, Sitemaps |
| `Noizu.Google.Api.AnalyticsAdmin.*` | Accounts, Properties, DataStreams |
| `Noizu.Google.Api.AnalyticsData.Reports` | `runReport` |
| `Noizu.Google.Api.AdSense.*` | Accounts, AdClients, AdUnits, Reports |
| `Noizu.Google.Api.Ads.Customers` | GAQL search, mutate, conversion actions |

HTTP stack: **Finch** + **Jason**.

How this library sits next to the Terraform provider and MCP server is in
[ADR-001](docs/ADR-001-marketing-control-plane.md).

## Development

```sh
mix deps.get
mix test
mix test --cover
mix docs
mix hex.build          # tarball only; does not publish
```

## License

[MIT](https://github.com/noizu-labs/elixir-google/blob/main/LICENSE)
