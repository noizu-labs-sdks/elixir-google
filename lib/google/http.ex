defmodule Noizu.Google.HTTP do
  @moduledoc """
  〚📦:6c1bf133-d2c3-57b0-93d9-254c20a6c771〛 Noizu.Google.HTTP :: JSON REST transport: verbs, bearer auth, decode modes, form POST.

  Low-level HTTP helpers for Google REST APIs.

  JSON GET/POST/PUT/PATCH/DELETE with OAuth2 bearer tokens. `:base` selects a
  client URL (`:api`, `:webmasters`, `:analytics_admin`, `:analytics_data`,
  `:adsense`, `:google_ads`) or an absolute URL string.
  """

  alias Noizu.Google.Client
  alias Noizu.Google.Error

  @type options :: keyword() | map() | nil
  @type result :: {:ok, term()} | {:error, Error.t()}

  @doc """
  HTTP GET with optional query params.

  ## Options
  * `:client` — `%Noizu.Google.Client{}` (default: `Client.default()`)
  * `:base` — `:api` (default), `:webmasters`, `:analytics_admin`,
    `:analytics_data`, `:adsense`, `:google_ads`, or an absolute base URL string
  * `:query` — query map/keyword list
  * `:decode` — `:atoms` (default), `:strings`, `:raw`, or a module with `from_json/1`
  * `:auth` — `:user` (default bearer), `:none`
  * `:headers` — extra headers
  * `:timeout` — receive timeout override
  """
  @spec get(String.t(), options()) :: result()
  def get(path, opts \\ []) do
    request_json(:get, path, nil, opts)
  end

  @doc "HTTP POST JSON body → JSON response."
  @spec post(String.t(), map() | list() | nil, options()) :: result()
  def post(path, body \\ %{}, opts \\ []) do
    request_json(:post, path, body, opts)
  end

  @doc "HTTP PUT JSON body → JSON response."
  @spec put(String.t(), map() | list() | nil, options()) :: result()
  def put(path, body \\ %{}, opts \\ []) do
    request_json(:put, path, body, opts)
  end

  @doc "HTTP PATCH JSON body → JSON response."
  @spec patch(String.t(), map() | list() | nil, options()) :: result()
  def patch(path, body \\ %{}, opts \\ []) do
    request_json(:patch, path, body, opts)
  end

  @doc "HTTP DELETE (optional JSON body)."
  @spec delete(String.t(), options()) :: result()
  def delete(path, opts \\ []) do
    body = opts |> normalize_opts() |> Keyword.get(:body)
    request_json(:delete, path, body, opts)
  end

  @doc "POST `application/x-www-form-urlencoded` (OAuth token endpoints)."
  @spec form_post(String.t(), keyword() | map(), options()) :: result()
  def form_post(url, form, opts \\ []) do
    opts = normalize_opts(opts)
    client = client(opts)
    body = URI.encode_query(Enum.into(form, %{}))

    headers =
      [
        {"Content-Type", "application/x-www-form-urlencoded"},
        {"Accept", "application/json"}
      ]
      |> Kernel.++(Keyword.get(opts, :headers, []))

    do_exchange(:post, url, headers, body, client, opts)
    |> decode_json_response(Keyword.put(opts, :decode, Keyword.get(opts, :decode, :strings)))
  end

  # ---------------------------------------------------------------------------
  # Internals
  # ---------------------------------------------------------------------------

  defp request_json(method, path, body, opts) do
    opts = normalize_opts(opts)
    client = client(opts)
    base = resolve_base(client, Keyword.get(opts, :base, :api))
    url = url(base, path, Keyword.get(opts, :query))

    with {:ok, client} <- maybe_require_token(client, opts),
         {:ok, encoded} <- encode_body(method, body),
         {:ok, headers} <- build_headers(client, opts, method, encoded) do
      do_exchange(method, url, headers, encoded, client, opts)
      |> decode_json_response(opts)
    end
  end

  defp do_exchange(method, url, headers, body, client, opts) do
    case do_request(method, url, headers, body, client, opts) do
      {:ok, %Finch.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, status, resp_body}

      {:ok, %Finch.Response{status: status, body: resp_body}} ->
        {:error, Error.from_response(status, decode_error_body(resp_body))}

      {:error, reason} ->
        {:error, Error.transport(reason)}
    end
  end

  defp do_request(method, url, headers, body, client, opts) do
    timeout = Keyword.get(opts, :timeout, client.receive_timeout)
    pool_timeout = Keyword.get(opts, :pool_timeout, client.pool_timeout)

    case Application.get_env(:noizu_google, :request_fun) do
      fun when is_function(fun, 1) ->
        fun.(%{
          method: method,
          url: url,
          headers: headers,
          body: body,
          client: client,
          opts: opts
        })

      fun when is_function(fun, 4) ->
        fun.(method, url, headers, body)

      _ ->
        Finch.build(method, url, headers, body)
        |> Finch.request(client.finch,
          receive_timeout: timeout,
          pool_timeout: pool_timeout,
          request_timeout: timeout
        )
    end
  end

  defp decode_json_response({:ok, _status, body}, opts) do
    case Keyword.get(opts, :decode, :atoms) do
      :raw ->
        {:ok, body}

      :strings ->
        decode_json(body, keys: :strings)

      :atoms ->
        decode_json(body, keys: :atoms)

      module when is_atom(module) ->
        with {:ok, json} <- decode_json(body, keys: :atoms) do
          {:ok, apply(module, :from_json, [json])}
        end
    end
  end

  defp decode_json_response({:error, _} = err, _opts), do: err

  defp decode_json("", _opts), do: {:ok, nil}
  defp decode_json(nil, _opts), do: {:ok, nil}

  defp decode_json(body, opts) when is_binary(body) do
    case Jason.decode(body, opts) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, Error.codec(reason)}
    end
  end

  defp decode_error_body(body) when is_binary(body) do
    case Jason.decode(body, keys: :atoms) do
      {:ok, json} -> json
      _ -> body
    end
  end

  defp decode_error_body(body), do: body

  # GET/DELETE with no body must not send Content-Type with empty body noise.
  defp encode_body(method, nil) when method in [:get, :delete], do: {:ok, nil}
  defp encode_body(_method, nil), do: {:ok, nil}
  defp encode_body(_method, body) when is_binary(body), do: {:ok, body}

  defp encode_body(_method, body) when is_map(body) or is_list(body) do
    case Jason.encode(body) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, Error.codec(reason)}
    end
  end

  defp build_headers(client, opts, method, body) do
    auth = Keyword.get(opts, :auth, :user)

    base =
      cond do
        is_binary(body) and method in [:post, :put, :patch] ->
          [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

        true ->
          [{"Accept", "application/json"}]
      end

    headers =
      base
      |> Kernel.++(auth_headers(client, auth))
      |> Kernel.++(Keyword.get(opts, :headers, []))

    {:ok, headers}
  end

  defp auth_headers(%Client{access_token: token}, :user)
       when is_binary(token) and token != "" do
    [{"Authorization", "Bearer #{token}"}]
  end

  defp auth_headers(_client, :none), do: []
  defp auth_headers(_client, :user), do: []

  defp maybe_require_token(client, opts) do
    case Keyword.get(opts, :auth, :user) do
      :user -> Client.require_token(client)
      _ -> {:ok, client}
    end
  end

  defp client(opts), do: Keyword.get(opts, :client) || Client.default()

  defp normalize_opts(nil), do: []
  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)

  defp resolve_base(%Client{} = client, :api), do: client.api_base
  defp resolve_base(%Client{} = client, :webmasters), do: client.webmasters_base
  defp resolve_base(%Client{} = client, :analytics_admin), do: client.analytics_admin_base
  defp resolve_base(%Client{} = client, :analytics_data), do: client.analytics_data_base
  defp resolve_base(%Client{} = client, :adsense), do: client.adsense_base
  defp resolve_base(%Client{} = client, :google_ads), do: client.google_ads_base
  defp resolve_base(%Client{}, base) when is_binary(base), do: base

  defp url(base, path, query) do
    base = Client.normalize_base(base)
    path = String.trim_leading(path, "/")
    full = base <> path

    case query do
      nil ->
        full

      q when q == %{} or q == [] ->
        full

      q when is_map(q) or is_list(q) ->
        full <> "?" <> URI.encode_query(Enum.into(q, []))
    end
  end
end
