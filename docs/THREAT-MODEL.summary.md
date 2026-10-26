# Threat Model — Summary

Client-side library: no listening surface, no storage. Risk concentrates on credentials
(service-account private key, OAuth refresh token, bearer, Ads developer token) and on
write authority over money and property config (Ads spend, AdSense, GA4, Search Console).

**Trust boundaries:** host app ↔ library (in-process, trusted) · library ↔ Google REST
APIs over TLS · library ↔ OAuth token endpoint · repo ↔ developer machine (key files) ·
CI ↔ Hex/GitHub Actions · secret store ↔ runtime env.

**Register (10 open · 1 partial · 1 mitigated):**

| ID | Sev | Issue | Status |
|----|-----|-------|--------|
| T-001 | High | `%Client{}` has no redacting `Inspect` — `inspect/1` or crash reports expose access/refresh tokens, client secret, and the SA map incl. `private_key` | Open |
| T-002 | Medium | `:base` accepts arbitrary absolute URLs with the bearer token attached | Open (accepted) |
| T-003 | Medium | `authorize_url/1` forwards `state`/PKCE but generates and validates neither | Open |
| T-004 | Medium | `:request_fun` app-env hook intercepts every request including credentials | Open (test seam) |
| T-005 | Medium | No library-level guardrail on destructive calls (`delete`, Ads `mutate` apply immediately) | Open (by design) |
| T-006 | Medium | `.gitignore` does not exclude `*.json` — an SA key in the checkout can be committed | Open |
| T-007 | Medium | `:atoms` JSON decode of remote responses creates atoms | Open |
| T-008 | Low | Error bodies/messages retain Google response payloads and `inspect(response)` | Open |
| T-009 | Low | GAQL `LIMIT #{limit}` interpolated without coercion | Open |
| T-010 | Low | SA key file read without mode/ownership check | Open |
| T-011 | Low | CI actions tag-pinned except setup-beam; Hex deps semver-ranged | Partial |
| T-012 | Low | Path-segment encoding + digit-only customer ids prevent injection | Mitigated |

**Residual risk accepted:** caller is trusted code; destructive writes are the product
(guardrails belong to the MCP layer, per ADR-001); no audit trail, no rate limiting,
no retries.

Detail: [`THREAT-MODEL.md`](THREAT-MODEL.md).
