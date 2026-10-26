defmodule Noizu.Google do
  @moduledoc """
  〚📦:2d5f7df1-66a0-5a7c-9bf4-f301b9577e48〛 Noizu.Google :: Public facade: client/0, base URL getters, API namespace map.

  Google REST API client for Elixir.

  OAuth2 bearer auth (user refresh tokens or service-account JWT), Finch + Jason
  HTTP, structured errors, and thin wrappers for Search Console, GA4 Admin/Data,
  AdSense Management, and Google Ads.

  ## Quick start

      # config/runtime.exs
      config :noizu_google,
        access_token: System.get_env("GOOGLE_ACCESS_TOKEN"),
        client_id: System.get_env("GOOGLE_CLIENT_ID"),
        client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

      client = Noizu.Google.client()

      {:ok, sites} = Noizu.Google.Api.SearchConsole.Sites.list(client: client)

      {:ok, report} =
        Noizu.Google.Api.SearchConsole.SearchAnalytics.query(
          "https://example.com/",
          %{
            startDate: "2026-01-01",
            endDate: "2026-01-31",
            dimensions: ["query"]
          },
          client: client
        )

      {:ok, props} =
        Noizu.Google.Api.AnalyticsAdmin.Properties.list(
          filter: "parent:accounts/123",
          client: client
        )

  ## Architecture

  * `Noizu.Google.Client` — credentials + base URLs
  * `Noizu.Google.HTTP` — REST GET/POST/PUT/PATCH/DELETE with JSON + bearer auth
  * `Noizu.Google.OAuth` — authorize URL, code exchange, refresh, JWT bearer
  * `Noizu.Google.ServiceAccount` — service-account JSON / JWT assertion
  * `Noizu.Google.Scopes` — common OAuth scope constants
  * `Noizu.Google.Api.*` — endpoint modules by Google product
  * `Noizu.Google.Error` — structured errors

  ## API namespaces

  | Module | Google surface |
  |--------|----------------|
  | `Api.SearchConsole.Sites` | Search Console sites |
  | `Api.SearchConsole.SearchAnalytics` | searchAnalytics/query |
  | `Api.SearchConsole.Sitemaps` | sitemaps list/get/submit/delete |
  | `Api.AnalyticsAdmin.Accounts` | GA4 Admin accounts |
  | `Api.AnalyticsAdmin.Properties` | GA4 properties |
  | `Api.AnalyticsAdmin.DataStreams` | GA4 data streams |
  | `Api.AnalyticsData.Reports` | GA4 Data API runReport |
  | `Api.AdSense.Accounts` | AdSense accounts |
  | `Api.AdSense.AdClients` | AdSense ad clients |
  | `Api.AdSense.AdUnits` | AdSense ad units |
  | `Api.AdSense.Reports` | AdSense reports:generate |
  | `Api.Ads.Customers` | Google Ads search / mutate / conversion actions |

  Pass `%Client{}` via `opts[:client]` (or omit to use application config defaults).

  See the HexDocs extras for the OAuth runbook and ADR-001 (MCP + Terraform).
  """

  alias Noizu.Google.Client

  @doc "Build a client from options / application config."
  @spec client(keyword() | map()) :: Client.t()
  def client(opts \\ []), do: Client.new(opts)

  @doc "Default general Google APIs base URL."
  def api_base, do: Client.default().api_base

  @doc "Default Search Console (webmasters v3) base URL."
  def webmasters_base, do: Client.default().webmasters_base

  @doc "Default GA4 Admin API base URL."
  def analytics_admin_base, do: Client.default().analytics_admin_base

  @doc "Default GA4 Data API base URL."
  def analytics_data_base, do: Client.default().analytics_data_base

  @doc "Default AdSense Management API base URL."
  def adsense_base, do: Client.default().adsense_base

  @doc "Default Google Ads API base URL."
  def google_ads_base, do: Client.default().google_ads_base
end
