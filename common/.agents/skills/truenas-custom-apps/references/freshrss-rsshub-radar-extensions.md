# FreshRSS extensions that convert websites through RSSHub

Use this pattern when FreshRSS should accept a normal website URL (or a compact route shorthand) and turn it into a feed on a private RSSHub instance, analogous to an RSS-Bridge integration.

## Architecture

- Implement a **system extension** using `Minz_HookType::CheckUrlBeforeAdd`.
- Register before RSS-Bridge (for example priority `-20`, versus RSS-Bridge's default `0`) so RSSHub is preferred when Radar has a usable rule; return the original URL on no match or error so native FreshRSS discovery and RSS-Bridge remain fallbacks.
- Fetch rule JSON only from the administrator-configured RSSHub base URL at `/api/radar/rules`; cache it for several hours in a mode-`0600` file whose name contains only a hash, never the access secret.
- Match the serialisable Radar subset: grouped domain/subdomain rules, static and named path segments, optional parameters, regex constraints, wildcards, and common query captures. Skip executable/function-style targets safely.
- Support an explicit shorthand such as `rsshub://namespace/route/parameters`. This is essential when Radar offers several valid feeds for one page or uses a target that cannot be represented in JSON.

## RSSHub access control

RSSHub supports two relevant client URL forms:

- `key=<ACCESS_KEY>` — simple, but exposes the reusable master key anywhere the complete feed URL is recorded.
- `code=md5(request_path + ACCESS_KEY)` — a route-specific code; compute it from the final URL path, including any RSSHub base-path prefix but excluding the query string.

**Prefer `code=` for generated and stored FreshRSS feed URLs.** FreshRSS/SimplePie logs complete feed URLs during fetches. A master `key=` therefore appears in process/application logs even if the extension itself never logs it. Route-specific `code=` limits that exposure. Existing `key=` subscriptions require a deliberate migration before rotating `ACCESS_KEY`; do not rotate blindly.

The Radar rules request should use the same access mode. If a key-bearing URL must be fetched, suppress native PHP wrapper warnings (which may include the full URL) and emit only a generic extension log message.

## FreshRSS configuration pitfalls

- `Minz_Request::param()` and the default `paramString()` mode HTML-encode values. This corrupts URLs or secrets containing `&`, quotes, or other special characters.
- Read administrator configuration as plaintext with `Minz_Request::paramString($name, true)`, validate it, and escape only when rendering HTML (`htmlspecialchars(..., ENT_QUOTES, 'UTF-8')`).
- Render the access secret in a blank password field with “leave blank to preserve” plus an explicit clear checkbox. Never echo the stored secret back into the page.
- Only administrators can configure system extensions, but keep the normal FreshRSS CSRF token in `configure.phtml`.

## Multi-match behaviour

Radar often returns several legitimate routes for the same page. A generic Git repository page, for example, may match branches, issues, pulls, contributors, activity, and other feeds. The one-to-one FreshRSS hook cannot present a chooser.

- Preserve Radar rule order only as a convenience default; do not claim it identifies user intent.
- Document and support the manual `rsshub://...` route syntax for deterministic selection.
- For a future richer UI, add a dedicated route picker rather than inventing opaque ranking rules.

## Safe deployment on Luke's TrueNAS FreshRSS

1. Inspect the live FreshRSS version, extension mount, enabled system-extension list, existing RSS-Bridge extension, and RSSHub access-control mode.
2. Before installation, back up:
   - the complete persistent extensions tree;
   - FreshRSS `data/config.php`;
   - a PostgreSQL custom-format dump (`pg_dump -Fc`).
3. Stage and lint every PHP/PHTML file inside the live FreshRSS container; the Hermes container may not have PHP.
4. Install under `/mnt/Apps/Applications/freshrss/extensions/<extension>` with ownership/modes matching existing extensions. Leave genuinely local extensions unmanaged by Extension Manager rather than inventing an upstream source marker.
5. Enable it in the **system** `extensions_enabled` map and configure the internal/LAN RSSHub base URL plus access mode. Pass secrets through stdin or another non-logging channel, not command arguments or tool output.
6. Verification must cover:
   - unit fixtures for path/query/optional/wildcard matching and key/code URL generation;
   - PHP syntax checks in the live image;
   - authenticated `/api/radar/rules` fetch and JSON decode;
   - direct manual-route hook conversion;
   - automatic conversion of a representative supported website;
   - HTTP 200 plus RSS/Atom XML from the generated route;
   - one real `FreshRSS_feed_Controller::addFeed()` test followed by verified deletion of the temporary feed;
   - managed FreshRSS stop/start and repeat hook/feed verification so persistence is proven.
7. Sanitize verification output: print only scheme, host, path, and query **key names**. FreshRSS itself may still print full fetch URLs; redirect or capture those logs securely during tests.

## Related cleanup signal

A real feed-add smoke can surface warnings from unrelated extensions. Treat those separately: back up the affected extension, reproduce the warning, patch only if the fix is verified, and do not let unrelated warnings invalidate an otherwise successful RSSHub route test.
