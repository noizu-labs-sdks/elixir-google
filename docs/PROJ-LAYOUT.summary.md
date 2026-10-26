# Project Layout — Summary

`noizu_google` v0.2.4 — Elixir Mix library, no persistence, no server, no deploy surface.

```text
elixir-google/
├── lib/
│   ├── noizu_google.ex          # facade: client/0 + base URL getters
│   ├── application.ex           # Finch pool (Noizu.Google.Finch)
│   ├── google/
│   │   ├── api.ex               # use-macro + opts/URL helpers
│   │   ├── client.ex            # %Client{}: credentials, base URLs, token resolution
│   │   ├── http.ex              # verb wrappers, JSON, bearer auth, form_post
│   │   ├── oauth.ex             # authorize/token/refresh/jwt_bearer
│   │   ├── service_account.ex   # SA JSON + RS256 assertion + token mint
│   │   ├── scopes.ex            # scope constants, marketing_default/0
│   │   ├── error.ex             # %Noizu.Google.Error{}
│   │   └── api/{search_console,analytics_admin,analytics_data,adsense,ads}/
│   └── mix/tasks/               # google.oauth.authorize / .exchange
├── config/{config,dev,test}.exs # no runtime.exs, no prod.exs
├── docs/                        # ADR-001, oauth runbook, PROJ-*/THREAT-MODEL (+layout/)
├── test/                        # ExUnit + Mimic(Finch); support/ fixtures
├── .github/workflows/ci.yml     # compile --warnings-as-errors + mix test
├── mix.exs / mix.lock           # Hex package (deps: finch, jason)
├── .tool-versions               # elixir 1.20.1-otp-29 / erlang 29.0.2
├── .formatter.exs
├── .gitignore                   # _build, deps, cover, doc, tarballs, .claude/worktrees
├── CHANGELOG.md                 # version-keyed (0.2.4)
├── README.md
└── LICENSE                      # MIT
```

Entry points: `Noizu.Google.client/0`, `Noizu.Google.Api.*`, `Noizu.Google.OAuth`,
`Noizu.Google.ServiceAccount`.

Requires configuration: credentials via app env or env vars (`GOOGLE_ACCESS_TOKEN`,
`GOOGLE_REFRESH_TOKEN`, `GOOGLE_CLIENT_ID`/`_SECRET`, `GOOGLE_APPLICATION_CREDENTIALS`,
`GOOGLE_ADS_DEVELOPER_TOKEN`). No `.envrc`/`.env.example` in repo.

Detail: [`PROJ-LAYOUT.md`](PROJ-LAYOUT.md), [`layout/lib.md`](layout/lib.md),
[`layout/test.md`](layout/test.md).
