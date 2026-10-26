# OAuth & secrets runbook — Google marketing plane

<!-- 〚📁:5c52f4ab-6cb7-56b3-a873-e5bd6316dcfb〛 OAuth and secrets runbook :: GCP project, scopes, refresh-token bootstrap, dc/Infisical mapping, safety. -->

Credentials for MCP (`:noizu_google_mcp`) and the OpenTofu provider
(`noizu/google-marketing`). **Never commit tokens.**

## 1. GCP project (Plane A)

1. Create or reuse a GCP project for marketing automation.
2. Enable APIs:
   - Search Console API (`webmasters`)
   - Google Analytics Admin API
   - Google Analytics Data API
   - AdSense Management API
   - Google Ads API
3. Configure OAuth consent screen (Internal or External as appropriate).
4. Create OAuth client credentials: **Desktop app** or **Web** with a localhost redirect for CLI bootstrap.

## 2. Scopes

Recommended offline scope set (narrow in production):

```text
https://www.googleapis.com/auth/webmasters
https://www.googleapis.com/auth/analytics.edit
https://www.googleapis.com/auth/analytics.readonly
https://www.googleapis.com/auth/adsense.readonly
https://www.googleapis.com/auth/adwords
```

Elixir helper:

```elixir
Noizu.Google.Scopes.marketing_default()
```

## 3. Bootstrap refresh token (once)

### Preferred: CLI

```bash
export GOOGLE_CLIENT_ID=...          # Desktop OAuth client for marketing APIs
export GOOGLE_CLIENT_SECRET=...
# Optional dedicated marketing client under google.marketing.* later

# Interactive (prints authorize URL, prompts for code, writes via dc):
bash terraform/marketing/scripts/bootstrap-oauth.sh

# Or step-by-step from Portfolio/Libs/api/elixir-google:
mix google.oauth.authorize
mix google.oauth.exchange --code 'CODE' --write-dc
```

`--write-dc` stores `secrets google.marketing.{client_id,client_secret,refresh_token}` without printing the refresh token.

### Manual (iex)

```elixir
# iex -S mix  (from Portfolio/Libs/api/elixir-google)
url =
  Noizu.Google.OAuth.authorize_url(
    client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
    redirect_uri: "http://127.0.0.1:8080/oauth2callback",
    scope: Noizu.Google.Scopes.marketing_default(),
    access_type: "offline",
    prompt: "consent"
  )

IO.puts(url)
# Open URL, complete consent, capture ?code=

{:ok, tokens} =
  Noizu.Google.OAuth.token(
    code: "CODE_FROM_REDIRECT",
    redirect_uri: "http://127.0.0.1:8080/oauth2callback",
    client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
    client_secret: System.fetch_env!("GOOGLE_CLIENT_SECRET")
  )

# tokens["refresh_token"], tokens["access_token"]
```

Store **refresh_token**, **client_id**, **client_secret** in Infisical / `dc` (not git).

### dc (source of truth for local)

```bash
dc config set secrets google.marketing.client_id --value '...'
dc config set secrets google.marketing.client_secret --value '...'
dc config set secrets google.marketing.refresh_token --value '...'
dc config set secrets google.marketing.ads_developer_token --value '...'
# optional MCC:
dc config set secrets google.marketing.ads_login_customer_id --value '...'
```

### Infisical (declared in `.infisical-secrets.yaml`)

Section id: **`marketing-google`** → path `/marketing/google`  
(Separate from Mautic `/marketing` so keys are not pulled into `marketing-app-secrets`.)

```bash
infisical-populate-secrets --include marketing-google
```

| Infisical key | dc path |
|---------------|---------|
| `OAUTH_CLIENT_ID` | `secrets google.marketing.client_id` |
| `OAUTH_CLIENT_SECRET` | `secrets google.marketing.client_secret` |
| `OAUTH_REFRESH_TOKEN` | `secrets google.marketing.refresh_token` |
| `ADS_DEVELOPER_TOKEN` | `secrets google.marketing.ads_developer_token` |
| `ADS_LOGIN_CUSTOMER_ID` | `secrets google.marketing.ads_login_customer_id` |

Load into a shell without printing values:

```bash
eval "$(bash terraform/marketing/scripts/load-env.sh)"
```

## 4. Environment variables

| Variable | Used by |
|----------|---------|
| `GOOGLE_ACCESS_TOKEN` | SDK, MCP, TF (short-lived) |
| `GOOGLE_MARKETING_ACCESS_TOKEN` | Preferred alias for MCP/TF |
| `GOOGLE_REFRESH_TOKEN` | MCP via `Client.ensure_access_token/1` |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Refresh |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to service-account JSON (JWT bearer) |
| `GOOGLE_CREDENTIALS_FILE` / `GOOGLE_SERVICE_ACCOUNT_FILE` | Aliases for the JSON path |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Inline service-account JSON (MCP; avoid in shell history) |
| `GOOGLE_SCOPES` | Space-separated scopes for the service-account grant |
| `GOOGLE_SUBJECT` / `GOOGLE_IMPERSONATE` | Domain-wide delegation subject |
| `GOOGLE_ADS_DEVELOPER_TOKEN` | Ads API (MCP + TF ads resources) |
| `GOOGLE_ADS_LOGIN_CUSTOMER_ID` | MCC |

MCP also accepts `GOOGLE_MARKETING_REFRESH_TOKEN` / `_CLIENT_ID` / `_CLIENT_SECRET`.

### Service account (Search Console)

1. Create a GCP service account and download the JSON key. **Do not commit it.**
2. Enable the Search Console API on the project.
3. In Search Console, **Settings → Users and permissions**, add the service
   account email (`...@....iam.gserviceaccount.com`) on each property.
4. Point the SDK / MCP at the file:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/path/to/sa.json"
export GOOGLE_SCOPES="https://www.googleapis.com/auth/webmasters"
```

`Client.ensure_access_token/1` signs a JWT and exchanges it at
`https://oauth2.googleapis.com/token`. User OAuth (access / refresh token)
still wins when those env vars are set.

## 5. MCP

```bash
cd Portfolio/Libs/ai/elixir-google-mcp
export GOOGLE_ACCESS_TOKEN=...   # or refresh trio or GOOGLE_APPLICATION_CREDENTIALS
export GOOGLE_ADS_DEVELOPER_TOKEN=...  # for Ads tools
mix run --no-halt
```

## 6. Terraform provider

```bash
Portfolio/Libs/api/terraform-provider-google-marketing/scripts/build-provider.sh
export GOOGLE_MARKETING_ACCESS_TOKEN=...
export GOOGLE_ADS_DEVELOPER_TOKEN=...   # for conversion actions
cd terraform/marketing
terragrunt plan
```

## 7. Google Ads extra gates

- Apply for a **developer token** in Google Ads API Center.
- For MCC: set `login-customer-id` / `GOOGLE_ADS_LOGIN_CUSTOMER_ID`.
- Conversion actions and mutates need Ads API access on the customer.

## 8. Safety

- Ads mutates in MCP default to **`dry_run=true`** (`validateOnly`).
- Live mutates require **`confirm=true`**.
- Do not put refresh tokens in `.tf` files or state intentionally; use env/CI secrets.
- Campaigns/bids are **not** Terraform resources.
