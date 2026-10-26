# Project Architecture — Summary

`noizu_google` is a hand-written REST client library for Elixir covering five Google
marketing APIs (Search Console, GA4 Admin, GA4 Data, AdSense Management, Google Ads v17).
Not generated; each `Api.*` module maps a dozen-ish calls onto documented REST paths.
One process only: a named Finch pool started by the application. No server, no storage,
no deploy surface.

**Layers:** facade (`Noizu.Google`) → endpoint modules (`Api.*`) → `HTTP` (verbs, JSON,
bearer headers) → `Client` (creds, base URLs) → `OAuth`/`ServiceAccount` (token
acquisition) with `Error` returned everywhere (nothing raises).

**Credential resolution** (`Client.ensure_access_token/1`), first hit wins:
1. `access_token` on client/app env
2. service account (`service_account` map or `credentials_file`) → RS256 JWT → jwt-bearer grant (≤3600 s, optional `sub`)
3. OAuth `refresh_token` + client id/secret → `oauth2.googleapis.com/token`

`HTTP` never acquires tokens itself — it uses `Client.require_token/1` and returns a
`:config` error when the bearer is missing.

**Transport:** Finch (single pool `Noizu.Google.Finch`) + Jason. `:base` selects one of
seven product base URLs or an absolute URL; `:decode` is `:atoms` (default), `:strings`,
`:raw`, or a module; `:auth` is `:user`/`:none`. Errors map to `from_response`
(`:http_error`), `transport` (`:transport`), `codec`, `config`. No retries, no
pagination, no caching, no TLS knobs.

**Key decisions:** hand-written over generated; tagged-tuple returns over exceptions;
client passed by struct (multi-tenant credentials per VM); mutation `validateOnly`
guardrails are the MCP layer's job, not the library's.

**Stack:** Elixir 1.20.1/OTP 29, finch ~> 0.18, jason ~> 1.4, `:public_key` for RS256;
tests ExUnit + Mimic(Finch); published to Hex.

Detail: [`PROJ-ARCH.md`](PROJ-ARCH.md), [`arch/credentials.md`](arch/credentials.md),
[`arch/transport.md`](arch/transport.md).
