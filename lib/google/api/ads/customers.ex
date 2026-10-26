defmodule Noizu.Google.Api.Ads.Customers do
  @moduledoc """
  〚📦:bd50cea6-6fa5-5b1a-bb67-5c802b5046c5〛 Noizu.Google.Api.Ads.Customers :: Google Ads v17 REST helpers: GAQL search, mutate, conversion actions.

  Google Ads API — thin REST helpers (search + mutate).

  Base: `https://googleads.googleapis.com/v17/`

  Requires:
  * OAuth access token with adwords scope
  * `developer-token` header (opts `:developer_token` or app env `:developer_token`)
  * Optional `login-customer-id` for MCC (opts `:login_customer_id`)

  Mutates support `:validate_only` / `:dry_run` (maps to API `validateOnly`) so
  callers can preview without applying.

  Docs: https://developers.google.com/google-ads/api/docs/start
  """

  use Noizu.Google.Api

  @doc """
  POST `customers/{customerId}/googleAds:search`

  `customer_id` is digits only (no dashes). Body is a map, typically:

      %{query: "SELECT campaign.id, campaign.name FROM campaign LIMIT 10"}
  """
  @spec search(String.t(), map(), opts()) :: result()
  def search(customer_id, body, opts \\ [])
      when is_binary(customer_id) and is_map(body) do
    client = Api.client(opts)
    opts = Api.normalize_opts(opts)
    cid = digits(customer_id)
    path = "customers/#{cid}/googleAds:search"

    with {:ok, headers} <- ads_headers(opts) do
      HTTP.post(path, body,
        base: :google_ads,
        headers: headers,
        decode: Api.decode_opt(opts),
        client: client
      )
    end
  end

  @doc """
  POST `customers/{customerId}/googleAds:mutate`

  Body must include `mutateOperations` (list). Optional opts:
  * `:dry_run` / `:validate_only` — when true, sets `validateOnly: true` (no apply)
  * `:partial_failure` — default true

  ## Example

      Customers.mutate("1234567890", %{
        mutateOperations: [
          %{
            campaignOperation: %{
              update: %{
                resourceName: "customers/1234567890/campaigns/1",
                status: "PAUSED"
              },
              updateMask: "status"
            }
          }
        ]
      }, dry_run: true, developer_token: "…", client: client)
  """
  @spec mutate(String.t(), map(), opts()) :: result()
  def mutate(customer_id, body, opts \\ [])
      when is_binary(customer_id) and is_map(body) do
    client = Api.client(opts)
    opts = Api.normalize_opts(opts)
    cid = digits(customer_id)
    path = "customers/#{cid}/googleAds:mutate"
    payload = mutate_body(body, opts)

    with {:ok, headers} <- ads_headers(opts) do
      HTTP.post(path, payload,
        base: :google_ads,
        headers: headers,
        decode: Api.decode_opt(opts),
        client: client
      )
    end
  end

  @doc """
  Create a conversion action via mutate.

  Options:
  * `:name` (required)
  * `:type` — default `"WEBPAGE"`
  * `:category` — default `"DEFAULT"`
  * `:status` — default `"ENABLED"`
  * `:dry_run` — validate only
  * developer token / login customer as usual
  """
  @spec create_conversion_action(String.t(), opts()) :: result()
  def create_conversion_action(customer_id, opts \\ []) when is_binary(customer_id) do
    opts = Api.normalize_opts(opts)
    name = Keyword.get(opts, :name)

    if is_nil(name) or name == "" do
      {:error, Noizu.Google.Error.config("conversion action :name is required")}
    else
      create = %{
        name: name,
        type: Keyword.get(opts, :type, "WEBPAGE"),
        category: Keyword.get(opts, :category, "DEFAULT"),
        status: Keyword.get(opts, :status, "ENABLED")
      }

      create =
        case Keyword.get(opts, :view_through_lookback_window_days) ||
               Keyword.get(opts, :viewThroughLookbackWindowDays) do
          nil -> create
          n -> Map.put(create, :viewThroughLookbackWindowDays, n)
        end

      body = %{
        mutateOperations: [
          %{
            conversionActionOperation: %{
              create: create
            }
          }
        ]
      }

      mutate(customer_id, body, opts)
    end
  end

  @doc """
  Convenience: list conversion actions via GAQL.

      Customers.list_conversion_actions("1234567890", client: client, developer_token: "…")
  """
  @spec list_conversion_actions(String.t(), opts()) :: result()
  def list_conversion_actions(customer_id, opts \\ []) when is_binary(customer_id) do
    query = """
    SELECT conversion_action.id, conversion_action.name, conversion_action.type,
           conversion_action.status, conversion_action.resource_name,
           conversion_action.category
    FROM conversion_action
    ORDER BY conversion_action.id
    """

    body = %{query: String.trim(query)}
    search(customer_id, body, opts)
  end

  @doc """
  Convenience: list campaigns (read-only) via GAQL.
  """
  @spec list_campaigns(String.t(), opts()) :: result()
  def list_campaigns(customer_id, opts \\ []) when is_binary(customer_id) do
    limit = Keyword.get(Api.normalize_opts(opts), :limit, 50)

    query = """
    SELECT campaign.id, campaign.name, campaign.status, campaign.advertising_channel_type
    FROM campaign
    ORDER BY campaign.id
    LIMIT #{limit}
    """

    search(customer_id, %{query: String.trim(query)}, opts)
  end

  defp mutate_body(body, opts) do
    dry? =
      truthy?(Keyword.get(opts, :dry_run)) or truthy?(Keyword.get(opts, :validate_only)) or
        truthy?(Keyword.get(opts, :validateOnly))

    partial =
      case Keyword.fetch(opts, :partial_failure) do
        {:ok, v} -> truthy?(v)
        :error ->
          case Keyword.fetch(opts, :partialFailure) do
            {:ok, v} -> truthy?(v)
            :error -> true
          end
      end

    body
    |> stringify_keys_shallow()
    |> Map.put("partialFailure", partial)
    |> then(fn b -> if dry?, do: Map.put(b, "validateOnly", true), else: b end)
  end

  # Preserve atom keys for Jason; API accepts both. Prefer existing map keys.
  defp stringify_keys_shallow(map) when is_map(map) do
    # Leave as-is — Jason encodes atom keys as strings.
    map
  end

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?("1"), do: true
  defp truthy?(1), do: true
  defp truthy?(_), do: false

  defp ads_headers(opts) do
    token =
      Keyword.get(opts, :developer_token) ||
        Keyword.get(opts, :developerToken) ||
        Application.get_env(:noizu_google, :developer_token) ||
        System.get_env("GOOGLE_ADS_DEVELOPER_TOKEN")

    login =
      Keyword.get(opts, :login_customer_id) ||
        Keyword.get(opts, :loginCustomerId) ||
        Application.get_env(:noizu_google, :login_customer_id) ||
        System.get_env("GOOGLE_ADS_LOGIN_CUSTOMER_ID")

    cond do
      is_nil(token) or token == "" ->
        {:error, Noizu.Google.Error.config("Google Ads developer_token is required")}

      true ->
        headers = [{"developer-token", token}]

        headers =
          if is_binary(login) and login != "" do
            headers ++ [{"login-customer-id", digits(login)}]
          else
            headers
          end

        {:ok, headers}
    end
  end

  defp digits(id), do: String.replace(id, ~r/\D/, "")
end
