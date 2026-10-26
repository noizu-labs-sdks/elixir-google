# Transport and error mapping

## Request path

`Api.*` → `Noizu.Google.HTTP.<verb>` → `request_json/4` → `do_exchange/6` →
`do_request/6` → Finch.

1. Resolve client (`opts[:client]` or `Client.default()`).
2. Resolve base URL from `:base` (`:api` | `:webmasters` | `:analytics_admin` |
   `:analytics_data` | `:adsense` | `:google_ads` | absolute URL string), join path,
   append `URI.encode_query/1` of `:query`.
3. `maybe_require_token/2` — only when `:auth` is `:user` (the default).
4. Encode body (JSON for POST/PUT/PATCH maps/lists/binary; `nil` for GET/DELETE).
5. Build headers: `Content-Type: application/json` only when a body was encoded,
   always `Accept: application/json`, then `Authorization: Bearer <token>`, then
   `opts[:headers]`.
6. `Finch.build/4` + `Finch.request/3` with `receive_timeout`, `pool_timeout`,
   `request_timeout` (opts override, else client defaults 120 s / 60 s).

`form_post/3` bypasses JSON: urlencoded body, `application/x-www-form-urlencoded`, and
forces `decode: :strings` by default — that is the OAuth token path.

## Decode modes

| `:decode` | Result |
|-----------|--------|
| `:atoms` (default) | `Jason.decode(body, keys: :atoms)` |
| `:strings` | `Jason.decode(body, keys: :strings)` |
| `:raw` | Body returned as-is |
| module | Decode with atom keys, then `module.from_json/1` |

Empty body, `nil`, or "" decode to `{:ok, nil}`.

## Error mapping

| Condition | Error |
|-----------|-------|
| 2xx | `{:ok, decoded}` |
| non-2xx | `Error.from_response/2` — `:http_error`, `status`, decoded body, `summary` from `error.message`, `tag` from `error.status`/`error.code` |
| Finch failure | `Error.transport/1` — `tag: :transport` |
| JSON encode/decode failure | `Error.codec/1` — `tag: :codec` |
| Missing token / credentials / Ads developer token | `Error.config/1` — `tag: :config` |

`Error` is a `defexception`, but the transport layer never raises it; callers
pattern-match on `{:error, %Error{}}`. `message/1` falls back through
`message` → `summary` → `"Google API error status=… reason=…"`.

## Test seams

`Application.get_env(:noizu_google, :request_fun)` — when set to a function of arity 1
(request map) or 4 (`method, url, headers, body`), it replaces the Finch call entirely.
Tests use Mimic on `Finch` instead, so the hook is normally unset. It is a full request
interceptor: see THREAT-MODEL T-004.

## Deliberate omissions

No retries, no backoff, no rate-limit handling (Google 429s surface as `:http_error`),
no response caching, no pagination helpers, no TLS configuration knobs (every base URL
is `https://`, and Finch's defaults are used unchanged).
