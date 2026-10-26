defmodule Noizu.Google.OAuth do
  @moduledoc """
  〚📦:c87ec7a5-21d5-5430-ad2f-5e6d519f8cdc〛 Noizu.Google.OAuth :: OAuth2 helpers: authorize URL, code exchange, refresh, JWT bearer.

  OAuth2 helpers for Google APIs.

  ## Authorization URL

      Noizu.Google.OAuth.authorize_url(
        client_id: "CLIENT_ID",
        redirect_uri: "https://example.com/oauth/callback",
        scope: "https://www.googleapis.com/auth/webmasters.readonly",
        access_type: "offline",
        prompt: "consent"
      )

  ## Exchange code

      Noizu.Google.OAuth.token(
        code: code,
        redirect_uri: redirect_uri,
        client: client
      )

  ## Refresh

      Noizu.Google.OAuth.refresh_token(refresh_token, client: client)
  """

  alias Noizu.Google.Client
  alias Noizu.Google.Error
  alias Noizu.Google.HTTP

  @type options :: keyword() | map()

  @doc """
  Build the user authorization URL.

  ## Options
  * `:client_id` (required unless on client)
  * `:redirect_uri`
  * `:response_type` — default `"code"`
  * `:scope` — space-separated scopes
  * `:state`
  * `:access_type` — `"offline"` for refresh tokens
  * `:prompt` — e.g. `"consent"`
  * `:include_granted_scopes`
  * `:login_hint`
  * `:code_challenge` / `:code_challenge_method` — PKCE
  """
  @spec authorize_url(options()) :: String.t() | {:error, Error.t()}
  def authorize_url(opts \\ []) do
    opts = normalize(opts)
    client = Keyword.get(opts, :client) || Client.default()
    client_id = Keyword.get(opts, :client_id) || client.client_id

    if is_nil(client_id) or client_id == "" do
      {:error, Error.config("client_id required for authorize_url")}
    else
      params =
        [
          {"client_id", client_id},
          {"response_type", Keyword.get(opts, :response_type, "code")}
        ]
        |> maybe_put("redirect_uri", Keyword.get(opts, :redirect_uri))
        |> maybe_put("scope", Keyword.get(opts, :scope))
        |> maybe_put("state", Keyword.get(opts, :state))
        |> maybe_put("access_type", Keyword.get(opts, :access_type))
        |> maybe_put("prompt", Keyword.get(opts, :prompt))
        |> maybe_put("include_granted_scopes", bool_param(Keyword.get(opts, :include_granted_scopes)))
        |> maybe_put("login_hint", Keyword.get(opts, :login_hint))
        |> maybe_put("code_challenge", Keyword.get(opts, :code_challenge))
        |> maybe_put("code_challenge_method", Keyword.get(opts, :code_challenge_method))

      client.authorize_url <> "?" <> URI.encode_query(params)
    end
  end

  @doc """
  Exchange an authorization code for tokens.

  ## Options
  * `:code` (required)
  * `:redirect_uri` (required for web apps)
  * `:client` / `:client_id` / `:client_secret`
  * `:code_verifier` — PKCE
  """
  @spec token(options()) :: {:ok, map()} | {:error, Error.t()}
  def token(opts \\ []) do
    opts = normalize(opts)
    client = Keyword.get(opts, :client) || Client.default()
    client_id = Keyword.get(opts, :client_id) || client.client_id
    client_secret = Keyword.get(opts, :client_secret) || client.client_secret
    code = Keyword.get(opts, :code)

    cond do
      is_nil(code) or code == "" ->
        {:error, Error.config("code required for token exchange")}

      is_nil(client_id) or client_id == "" ->
        {:error, Error.config("client_id required for token exchange")}

      true ->
        form =
          [
            grant_type: "authorization_code",
            code: code,
            client_id: client_id
          ]
          |> maybe_kw(:client_secret, client_secret)
          |> maybe_kw(:redirect_uri, Keyword.get(opts, :redirect_uri))
          |> maybe_kw(:code_verifier, Keyword.get(opts, :code_verifier))

        url = Client.normalize_base(client.oauth_base) <> "token"

        HTTP.form_post(url, form,
          client: client,
          auth: :none,
          decode: Keyword.get(opts, :decode, :strings)
        )
    end
  end

  @doc """
  Refresh an access token.

      Noizu.Google.OAuth.refresh_token(refresh_token, client: client)
  """
  @spec refresh_token(String.t(), options()) :: {:ok, map()} | {:error, Error.t()}
  def refresh_token(refresh_token, opts \\ []) when is_binary(refresh_token) do
    opts = normalize(opts)
    client = Keyword.get(opts, :client) || Client.default()
    client_id = Keyword.get(opts, :client_id) || client.client_id
    client_secret = Keyword.get(opts, :client_secret) || client.client_secret

    cond do
      refresh_token == "" ->
        {:error, Error.config("refresh_token required")}

      is_nil(client_id) or client_id == "" ->
        {:error, Error.config("client_id required for refresh_token")}

      true ->
        form =
          [
            grant_type: "refresh_token",
            refresh_token: refresh_token,
            client_id: client_id
          ]
          |> maybe_kw(:client_secret, client_secret)

        url = Client.normalize_base(client.oauth_base) <> "token"

        HTTP.form_post(url, form,
          client: client,
          auth: :none,
          decode: Keyword.get(opts, :decode, :strings)
        )
    end
  end

  @doc """
  Exchange a signed JWT for an access token (service-account grant).

      Noizu.Google.OAuth.jwt_bearer(assertion, client: client)

  ## Options
  * `:client`
  * `:url` — token endpoint (default `client.oauth_base <> "token"`)
  * `:decode` — passed to `HTTP.form_post/3`
  """
  @jwt_bearer "urn:ietf:params:oauth:grant-type:jwt-bearer"

  @spec jwt_bearer(String.t(), options()) :: {:ok, map()} | {:error, Error.t()}
  def jwt_bearer(assertion, opts \\ []) when is_binary(assertion) do
    opts = normalize(opts)
    client = Keyword.get(opts, :client) || Client.default()

    if assertion == "" do
      {:error, Error.config("jwt assertion required")}
    else
      url =
        Keyword.get(opts, :url) || Client.normalize_base(client.oauth_base) <> "token"

      HTTP.form_post(
        url,
        [grant_type: @jwt_bearer, assertion: assertion],
        client: client,
        auth: :none,
        decode: Keyword.get(opts, :decode, :strings)
      )
    end
  end

  defp normalize(nil), do: []
  defp normalize(opts) when is_list(opts), do: opts
  defp normalize(opts) when is_map(opts), do: Map.to_list(opts)

  defp maybe_put(params, _k, nil), do: params
  defp maybe_put(params, _k, ""), do: params
  defp maybe_put(params, k, v), do: params ++ [{k, v}]

  defp maybe_kw(kw, _k, nil), do: kw
  defp maybe_kw(kw, _k, ""), do: kw
  defp maybe_kw(kw, k, v), do: Keyword.put(kw, k, v)

  defp bool_param(true), do: "true"
  defp bool_param(false), do: "false"
  defp bool_param(other), do: other
end
