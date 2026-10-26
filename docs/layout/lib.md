# `lib/` — module map

28 modules across three layers: facade/core, transport, and per-product endpoint
wrappers. Every public function returns `{:ok, term}` or `{:error, %Noizu.Google.Error{}}`
— nothing raises.

## Core (`lib/google/`)

| Module | Lines | Role |
|--------|-------|------|
| `Noizu.Google` (`lib/noizu_google.ex`) | ~95 | Facade: `client/0` plus base-URL getters that read `Client.default()`. |
| `Noizu.Google.Application` (`lib/application.ex`) | ~15 | Starts `{Finch, name: Noizu.Google.Finch}` under a `:one_for_one` supervisor. |
| `Noizu.Google.Api` (`lib/google/api.ex`) | ~60 | `use` macro (aliases + `opts`/`result` types) and helpers: `client/1`, `normalize_opts/1`, `decode_opt/1`, `http_opts/2`, `encode_site_url/1`, `encode_feedpath/1`. `@moduledoc false`. |
| `Noizu.Google.Client` (`lib/google/client.ex`) | ~210 | `%Client{}` — credentials (`access_token`, `refresh_token`, `client_id`, `client_secret`, `credentials_file`, `service_account`, `subject`, `scopes`), seven base URLs, two timeouts, Finch pool name. `new/1` merges opts over `Application.get_env(:noizu_google, key)`. `ensure_access_token/1` resolves token → SA → refresh. |
| `Noizu.Google.HTTP` (`lib/google/http.ex`) | ~250 | `get/post/put/patch/delete` (JSON) and `form_post/3` (urlencoded, used for OAuth). `:base` selects a client URL or absolute string; `:decode` is `:atoms` (default) / `:strings` / `:raw` / a `from_json/1` module; `:auth` is `:user`/`:none`. |
| `Noizu.Google.OAuth` (`lib/google/oauth.ex`) | ~210 | `authorize_url/1` (incl. PKCE params), `token/1`, `refresh_token/2`, `jwt_bearer/2`. |
| `Noizu.Google.ServiceAccount` (`lib/google/service_account.ex`) | ~220 | `load_file/1`, `validate/1`, `assertion/2` (RS256 JWT built with `:public_key`), `access_token/2` (assertion → jwt-bearer exchange). Lifetime clamped to 3600 s. |
| `Noizu.Google.Scopes` (`lib/google/scopes.ex`) | ~75 | Scope URL constants + `marketing_default/0` (webmasters + analytics.edit/readonly + adsense.readonly + adwords) and `join/1`. |
| `Noizu.Google.Error` (`lib/google/error.ex`) | ~105 | `defexception` with `message/status/body/reason/summary/tag`; constructors `from_response/2`, `transport/1`, `codec/1`, `config/1`. |

## Endpoint wrappers (`lib/google/api/`)

Each is a thin path/verb/query mapper over `Noizu.Google.HTTP`. No client-side caching,
pagination helpers, or retries.

| Module | Verb(s) | Google path |
|--------|---------|-------------|
| `Api.SearchConsole.Sites` | GET/PUT/DELETE | `webmasters/v3/sites[/{siteUrl}]` |
| `Api.SearchConsole.SearchAnalytics` | POST | `sites/{siteUrl}/searchAnalytics/query` |
| `Api.SearchConsole.Sitemaps` | GET/PUT/DELETE | `sites/{siteUrl}/sitemaps[/{feedpath}]` |
| `Api.AnalyticsAdmin.Accounts` | GET | `v1beta/accounts[/{account}]` |
| `Api.AnalyticsAdmin.Properties` | GET/POST/PATCH/DELETE | `v1beta/properties…` |
| `Api.AnalyticsAdmin.DataStreams` | GET/POST/PATCH/DELETE | `v1beta/properties/{p}/dataStreams…` |
| `Api.AnalyticsData.Reports` | POST | `v1beta/properties/{p}:runReport` |
| `Api.AdSense.Accounts` | GET | `v2/accounts[/{account}]` |
| `Api.AdSense.AdClients` | GET | `v2/accounts/{a}/adclients` |
| `Api.AdSense.AdUnits` | GET | `v2/accounts/{a}/adclients/{c}/adunits…` |
| `Api.AdSense.Reports` | GET | `v2/accounts/{a}/reports:generate` |
| `Api.Ads.Customers` | POST | `v17/customers/{cid}/googleAds:search` and `:mutate` |

`Api.Ads.Customers` is the only wrapper that adds headers of its own: `developer-token`
(from opts → app env → `GOOGLE_ADS_DEVELOPER_TOKEN`) and optional `login-customer-id`
(opts → app env → `GOOGLE_ADS_LOGIN_CUSTOMER_ID`). `dry_run`/`validate_only` sets
`validateOnly: true`; `partialFailure` defaults to `true`.

## Mix tasks (`lib/mix/tasks/`)

| Task | Behaviour |
|------|-----------|
| `mix google.oauth.authorize` | Prints a consent URL for `Scopes.marketing_default/0`; reads `GOOGLE_CLIENT_ID`/`GOOGLE_MARKETING_CLIENT_ID`. |
| `mix google.oauth.exchange` | Exchanges `--code` for tokens; never prints the refresh token; `--print-access` opts into printing the access token; `--write-dc` shells out to `dc config set secrets google.marketing.*`. |
