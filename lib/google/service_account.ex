defmodule Noizu.Google.ServiceAccount do
  @moduledoc """
  〚📦:4ce34583-9584-5b80-a47e-7436c61ba227〛 Noizu.Google.ServiceAccount :: Service-account JSON validation, RS256 assertion, token mint.

  Google service-account JSON credentials (JWT bearer).

  Loads a standard GCP service-account key (`type: "service_account"`) and
  exchanges a signed RS256 JWT for an OAuth2 access token via
  `urn:ietf:params:oauth:grant-type:jwt-bearer`.

      {:ok, creds} = Noizu.Google.ServiceAccount.load_file(path)

      {:ok, token} =
        Noizu.Google.ServiceAccount.access_token(creds,
          scope: Noizu.Google.Scopes.search_console()
        )

  Used by `Noizu.Google.Client.ensure_access_token/1` when `credentials_file`
  or `service_account` is set. Prefer `GOOGLE_APPLICATION_CREDENTIALS` at the
  MCP / process-env layer rather than committing key files.
  """

  alias Noizu.Google.Client
  alias Noizu.Google.Error
  alias Noizu.Google.OAuth
  alias Noizu.Google.Scopes

  @token_uri "https://oauth2.googleapis.com/token"
  @max_lifetime 3600

  @type creds :: %{optional(String.t()) => term()}

  @doc """
  Read and validate a service-account JSON file.

  Path is expanded (`~` allowed). Does not log key material.
  """
  @spec load_file(String.t()) :: {:ok, creds()} | {:error, Error.t()}
  def load_file(path) when is_binary(path) do
    expanded = Path.expand(path)

    case File.read(expanded) do
      {:ok, bin} ->
        decode_and_validate(bin)

      {:error, :enoent} ->
        {:error, Error.config("service account file not found: #{expanded}")}

      {:error, :eacces} ->
        {:error, Error.config("service account file not readable: #{expanded}")}

      {:error, reason} ->
        {:error, Error.config("failed to read service account file (#{inspect(reason)})")}
    end
  end

  @doc "Validate a decoded service-account map (string or atom keys)."
  @spec validate(map()) :: {:ok, creds()} | {:error, Error.t()}
  def validate(map) when is_map(map) do
    creds = stringify_keys(map)
    type = creds["type"]
    email = creds["client_email"]
    key = creds["private_key"]

    cond do
      is_binary(type) and type != "service_account" ->
        {:error, Error.config("credentials type is #{inspect(type)}, expected service_account")}

      blank?(email) ->
        {:error, Error.config("service account missing client_email")}

      blank?(key) ->
        {:error, Error.config("service account missing private_key")}

      true ->
        {:ok, creds}
    end
  end

  def validate(_), do: {:error, Error.config("service account credentials must be a JSON object")}

  @doc """
  Mint a short-lived access token from a file path or validated creds map.

  ## Options
  * `:scope` / `:scopes` — space-separated string or list of scope URLs.
    Defaults to Search Console (`webmasters`).
  * `:subject` — user email to impersonate (domain-wide delegation).
  * `:client` — `%Noizu.Google.Client{}` used for HTTP / oauth base.
  * `:lifetime` — JWT lifetime in seconds (default 3600, max 3600).
  """
  @spec access_token(String.t() | map(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def access_token(source, opts \\ []) do
    with {:ok, creds} <- resolve_creds(source),
         {:ok, jwt} <- assertion(creds, opts),
         {:ok, body} <- exchange(creds, jwt, opts) do
      take_access_token(body)
    end
  end

  @doc """
  Build a signed JWT assertion (does not call Google).

  Exposed for tests and for callers that want to inspect the grant.
  """
  @spec assertion(map(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def assertion(creds, opts \\ []) do
    with {:ok, creds} <- resolve_creds(creds),
         {:ok, key} <- decode_pem(creds["private_key"]) do
      now = System.system_time(:second)
      lifetime = opts |> Keyword.get(:lifetime, @max_lifetime) |> min(@max_lifetime) |> max(1)
      aud = creds["token_uri"] || @token_uri
      scope = normalize_scopes(Keyword.get(opts, :scope) || Keyword.get(opts, :scopes))
      subject = Keyword.get(opts, :subject)

      claims =
        %{
          "iss" => creds["client_email"],
          "scope" => scope,
          "aud" => aud,
          "iat" => now,
          "exp" => now + lifetime
        }
        |> maybe_put("sub", subject)

      header = %{"alg" => "RS256", "typ" => "JWT"}

      with {:ok, header_json} <- Jason.encode(header),
           {:ok, claims_json} <- Jason.encode(claims) do
        signing_input = url_b64(header_json) <> "." <> url_b64(claims_json)
        sig = :public_key.sign(signing_input, :sha256, key)
        {:ok, signing_input <> "." <> url_b64(sig)}
      else
        {:error, reason} -> {:error, Error.codec(reason)}
      end
    end
  end

  defp exchange(creds, jwt, opts) do
    client = Keyword.get(opts, :client) || Client.new(access_token: nil)
    url = creds["token_uri"] || Client.normalize_base(client.oauth_base) <> "token"
    OAuth.jwt_bearer(jwt, client: client, url: url, decode: :strings)
  end

  defp take_access_token(%{"access_token" => token}) when is_binary(token) and token != "" do
    {:ok, token}
  end

  defp take_access_token(%{access_token: token}) when is_binary(token) and token != "" do
    {:ok, token}
  end

  defp take_access_token(other) do
    {:error, Error.config("service account token response missing access_token: #{inspect(other)}")}
  end

  defp resolve_creds(path) when is_binary(path), do: load_file(path)
  defp resolve_creds(map) when is_map(map), do: validate(map)
  defp resolve_creds(_), do: {:error, Error.config("service account credentials required")}

  defp decode_and_validate(bin) do
    case Jason.decode(bin) do
      {:ok, map} when is_map(map) ->
        validate(map)

      {:ok, _} ->
        {:error, Error.config("service account file must contain a JSON object")}

      {:error, reason} ->
        {:error, Error.codec(reason)}
    end
  end

  defp decode_pem(pem) when is_binary(pem) and pem != "" do
    case :public_key.pem_decode(pem) do
      [entry] ->
        {:ok, :public_key.pem_entry_decode(entry)}

      [] ->
        {:error, Error.config("service account private_key is not a valid PEM")}

      _multiple ->
        {:error, Error.config("service account private_key PEM must contain one key")}
    end
  rescue
    e ->
      {:error, Error.config("failed to decode service account private_key (#{Exception.message(e)})")}
  end

  defp decode_pem(_), do: {:error, Error.config("service account missing private_key")}

  defp normalize_scopes(nil), do: Scopes.search_console()
  defp normalize_scopes(""), do: Scopes.search_console()

  defp normalize_scopes(scopes) when is_list(scopes) do
    scopes
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> Scopes.search_console()
      list -> Enum.join(list, " ")
    end
  end

  defp normalize_scopes(scopes) when is_binary(scopes), do: scopes

  defp stringify_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, _k, ""), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(v) when is_binary(v), do: false
  defp blank?(_), do: true

  defp url_b64(bin) when is_binary(bin), do: Base.url_encode64(bin, padding: false)
end
