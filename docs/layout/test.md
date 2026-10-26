# `test/` — suite map

ExUnit with **Mimic** stubbing `Finch`, so no test touches the network. `test_helper.exs`
is just `ExUnit.start()` + `Mimic.copy(Finch)`.

| File | Covers |
|------|--------|
| `test/noizu_google_test.exs` | Facade + default base URLs |
| `test/api/http_test.exs` | Verb/header/query assembly, decode modes, error mapping, `:auth` behaviour |
| `test/api/oauth_test.exs` | Authorize URL params, code exchange form, refresh, JWT-bearer grant |
| `test/api/service_account_test.exs` | SA JSON validation, PEM decoding, assertion claims, token mint |
| `test/api/search_console_test.exs` | Sites / SearchAnalytics / Sitemaps paths + URL encoding |
| `test/api/analytics_admin_test.exs` | Accounts / Properties / DataStreams |
| `test/api/adsense_ads_test.exs` | AdSense accounts/clients/units/reports + Google Ads search/mutate/conversion actions |

## Support

| File | Purpose |
|------|---------|
| `test/support/finch_stub.ex` | `json_response/2` builds `%Finch.Response{}` values for the Mimic'd `Finch`. |
| `test/support/sa_fixture.ex` | Generates a throwaway RSA-2048 key at runtime and wraps it in a service-account map — never a real Google key, never written to the repo. |

`test/support` is only compiled in `:test` (`elixirc_paths/1` in `mix.exs`).

CI (`.github/workflows/ci.yml`) runs `mix deps.get`, `mix compile --warnings-as-errors`,
then `mix test` on `ubuntu-22.04` with Elixir 1.20.1 / OTP 29.0.2. Coverage threshold in
`mix.exs` is a lenient 30%.
