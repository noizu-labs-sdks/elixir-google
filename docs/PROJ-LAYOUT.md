# Project Layout — `noizu_google`

A small, single-purpose Mix library (`:noizu_google`, v0.2.4): a hand-written REST
client for Google marketing APIs. There is no persistence layer, no web server, and
no release/deploy surface — the whole codebase is `lib/` (~1.5k LOC), `config/`, and
`test/`. This document maps where things live; it is deliberately short because the
project is.

```
elixir-google/
├── lib/
│   ├── noizu_google.ex             # Public facade: client/0 + per-product base URL helpers
│   ├── application.ex              # OTP app: starts the named Finch pool (Noizu.Google.Finch)
│   ├── google/
│   │   ├── api.ex                  # `use Noizu.Google.Api` macro + shared opts/URL helpers
│   │   ├── client.ex               # %Client{} struct: credentials, base URLs, token acquisition
│   │   ├── http.ex                 # GET/POST/PUT/PATCH/DELETE + form POST, JSON, bearer auth
│   │   ├── oauth.ex                # authorize_url, code exchange, refresh, JWT-bearer grant
│   │   ├── service_account.ex      # SA JSON load/validate, RS256 JWT assertion, token mint
│   │   ├── scopes.ex               # OAuth scope URL constants + marketing_default/0
│   │   ├── error.ex                # %Noizu.Google.Error{} (defexception; returned, not raised)
│   │   └── api/
│   │       ├── search_console/     # Sites, SearchAnalytics, Sitemaps
│   │       ├── analytics_admin/    # Accounts, Properties, DataStreams (GA4 Admin v1beta)
│   │       ├── analytics_data/     # Reports.run_report (GA4 Data v1beta)
│   │       ├── adsense/            # Accounts, AdClients, AdUnits, Reports (v2)
│   │       └── ads/                # Customers (Google Ads v17: search/mutate/conversions)
│   └── mix/tasks/
│       ├── google.oauth.authorize.ex  # `mix google.oauth.authorize` — print consent URL
│       └── google.oauth.exchange.ex   # `mix google.oauth.exchange` — code→tokens, --write-dc
├── config/
│   ├── config.exs                  # All app env defaults (nil credentials, base URLs, timeouts)
│   ├── dev.exs                     # Empty (imported by config.exs)
│   └── test.exs                    # Fixed test access_token + base URLs
├── docs/
│   ├── ADR-001-marketing-control-plane.md  # Why SDK + MCP + TF provider are three planes
│   ├── oauth-secrets-runbook.md            # GCP/consent/scopes/dc/Infisical bootstrap
│   └── PROJ-*.md / THREAT-MODEL.md         # Doc-sweep artifacts (this set)
├── test/
│   ├── noizu_google_test.exs       # Facade/base URL assertions
│   ├── api/                        # One suite per API surface + http/oauth/service-account
│   └── support/
│       ├── finch_stub.ex           # Builds %Finch.Response{} for Mimic'd Finch
│       └── sa_fixture.ex           # Generates a throwaway RSA key + SA map (never real)
├── .github/workflows/ci.yml        # compile --warnings-as-errors + mix test on push/PR
├── mix.exs                         # Hex package metadata, docs groups, deps
├── mix.lock                        # Locked dep versions
├── .formatter.exs                  # Standard Elixir formatter inputs
├── .tool-versions                  # elixir 1.20.1-otp-29 / erlang 29.0.2 (CI tracks this)
├── .gitignore                      # _build, deps, cover, doc, tarballs, .claude/worktrees
├── CHANGELOG.md                    # Version-keyed change log (0.2.4 is current)
├── README.md                       # Install, config, per-API examples, architecture table
└── LICENSE                         # MIT
```

## Key files requiring setup

| File | Action |
|------|--------|
| `config/runtime.exs` | **Does not exist.** README examples show one; credential wiring is the host app's job (env → app env). |
| `config/prod.exs` | **Does not exist** — `config/config.exs` does `import_config "#{config_env()}.exs"`, so any `MIX_ENV` other than `dev`/`test` fails to compile until one is added. Benign for a library consumed as a dependency (the host app's config wins), but true for standalone builds. |
| `~/.tool-versions` / asdf | Elixir 1.20.1-otp-29, Erlang 29.0.2 (CI pins the same). |
| Env vars | `GOOGLE_ACCESS_TOKEN`, `GOOGLE_REFRESH_TOKEN`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_APPLICATION_CREDENTIALS`, `GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_LOGIN_CUSTOMER_ID` — see `docs/oauth-secrets-runbook.md` §4. |

## Notes

- No `.envrc`/`.env.example`, no Dockerfile, no Helm/Terraform, no release config: this
  repo publishes to Hex (`mix hex.build`) and is consumed as a dependency.
- `.claude/worktrees/` is gitignored (repo convention: all work in worktrees).
- `mix.exs` `source_url` points at `github.com/noizu-labs/elixir-google` while `origin`
  is `github.com/noizu-labs-sdks/elixir-google` — cosmetic drift, documented here rather
  than silently corrected.

Per-directory detail lives in `docs/layout/*.md` when a directory outgrows one line.

- → [`layout/lib.md`](layout/lib.md) — module-by-module breakdown
- → [`layout/test.md`](layout/test.md) — test suite map
