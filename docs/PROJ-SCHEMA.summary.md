# Project Schema — Summary

**No persistence layer.** `noizu_google` is a stateless REST client library: no database,
no Ecto schemas, no Liquibase changelogs, no KV store, no static data files. No ERD
applies; the sections below cover the non-relational data this repo does define.

**Configuration schema** — `:noizu_google` app env, mirrored by `Client.new/1` opts
(opts win, credentials default `nil`):

| Group | Keys |
|-------|------|
| Credentials | `access_token`, `refresh_token`, `client_id`, `client_secret`, `credentials_file`, `service_account`, `subject`, `scopes` |
| Ads extras | `developer_token`, `login_customer_id` |
| Base URLs | `api_base`, `webmasters_base`, `analytics_admin_base`, `analytics_data_base`, `adsense_base` (v2), `google_ads_base` (v17), `oauth_base`, `authorize_url` |
| Timeouts | `receive_timeout` 120 000 ms, `pool_timeout` 60 000 ms |
| Test seam | `request_fun` (fun/1 or fun/4), unset by default |

`config/test.exs` pins a placeholder token. No `prod.exs` / `runtime.exs` (host app owns
runtime config).

**Env-var contract** (mapped by README/runbook/MCP, not read by the library):
`GOOGLE_ACCESS_TOKEN`, `GOOGLE_REFRESH_TOKEN`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`,
`GOOGLE_APPLICATION_CREDENTIALS` (+ aliases), `GOOGLE_SCOPES`, `GOOGLE_SUBJECT`,
`GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_LOGIN_CUSTOMER_ID`.

**Interface schemas** — request bodies/query are plain maps or keyword lists; responses
are Google JSON decoded per `:decode`. Path encoding via `Api.encode_site_url/1` /
`encode_feedpath/1`; Ads customer ids stripped to digits. Return contract everywhere:
`{:ok, decoded}` | `{:error, %Noizu.Google.Error{message,status,body,reason,summary,tag}}`.

**Fixtures** — `sa_fixture.ex` (runtime-generated RSA key + SA map), `finch_stub.ex`
(`%Finch.Response{}` builders). No seed data.

**Migrations** — none.

Detail: [`PROJ-SCHEMA.md`](PROJ-SCHEMA.md).
