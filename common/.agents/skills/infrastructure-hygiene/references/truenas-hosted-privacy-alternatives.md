# TrueNAS apps → hosted alternatives: privacy assessment method

Use this when Luke asks whether TrueNAS media/library/game apps can be replaced by hosted or subscription services without losing privacy.

## Strict privacy test

Do not equate “private instance,” TLS, GDPR, no ads, or an operator promise not to inspect files with self-hosting-equivalent privacy.

A hosted replacement is **not equivalent to home self-hosting** when any provider controls the compute/storage and can technically access:

- plaintext media needed for indexing, transcoding, reading, or playback;
- application databases, watch history, requests, saves, or user activity;
- service/API tokens and encryption keys available to the running app;
- account, billing, traffic, or legal-disclosure metadata.

Server-side or at-rest encryption is not zero knowledge when the running hosted service can obtain the key. A provider policy limiting staff access is useful but contractual, not cryptographic. For media servers, true zero knowledge is generally incompatible with server-side indexing/transcoding. State this plainly; where no equivalent exists, say so rather than stretching a partial substitute.

## Research workflow

1. Confirm the current date and use current official product, pricing, privacy, and support pages.
2. Identify the exact function being replaced, not merely an app with a similar name.
3. Prefer lawful personal-media hosting or licensed subscriptions; do not recommend acquisition automation when the user excludes the *Arr suite.
4. Record the advertised entry price and all material qualifiers: tax/VAT, storage, bandwidth, GPU/transcoding tier, BYO storage, app licence, or required companion subscription.
5. Separate:
   - **same app, managed elsewhere**;
   - **SaaS approximation** with reduced functionality;
   - **no equivalent**.
6. Assess architecture, not marketing adjectives. Look for zero-knowledge/E2EE claims, who controls keys, operator access policy, jurisdiction, telemetry, and legal-disclosure terms.
7. Prefer official URLs in the result. When exact prices are dynamic, label them “from” and identify the checkout-variable component rather than inventing precision.
8. For a stack, note consolidation economics separately from per-app prices: one hosted app box may run several apps, but it also concentrates credentials and behavioral data with one provider.

## August 2026 reference points (re-check before reuse)

These are research leads, not permanent prices:

- **Bytesized AppBox:** advertised from €11/month with 1 TB and one-click Plex/Jellyfin/Tautulli/Audiobookshelf; useful for stack consolidation, but operator-hosted and not zero knowledge. Official: `https://bytesized-hosting.com/`
- **PikaPods:** resource-based pricing; Aug 2026 app list showed Kavita from $3.40/month and Audiobookshelf from $2.80/month, exclusive of VAT. July 2026 privacy policy said pod data is not sold/used for ads and staff access requires support authorization. Strong policy compromise, still not technically equivalent. Official: `https://www.pikapods.com/apps/`, `https://www.pikapods.com/privacy/`
- **Plex Pass:** $6.99/month, $69.99/year, $749.99 lifetime after 1 July 2026. Re-check `https://www.plex.tv/plans/`.
- **Trakt:** closest hosted bridge for Plex/Jellyfin watched state, but centralizes viewing history; about $60/year for VIP/Plex hosted sync in 2026. Not a privacy-equivalent replacement for local JellyPlex-Watched.
- **Minecraft Realms:** Bedrock small Realm $3.99/month; 10-player Bedrock/Java $7.99/month. Invite-only is access control, not privacy from Microsoft.
- **Antstream Arcade:** $3.99/month, $39.99/year, $99.99 lifetime in Aug 2026. Licensed catalog subscription, not hosted RomM or personal-ROM ownership.
- **Libby:** free with a participating library card and a comparatively restrained privacy statement, but library/OverDrive can process loan records and users do not own a permanent collection.

## Functional caveats worth preserving

- Plex built-in language preferences are a free approximation, not Plex Auto Languages’ per-show/per-user memory.
- Trakt connectors do not guarantee exact bidirectional synchronization of every user, timestamp, and partial progress state.
- Seerr without Sonarr/Radarr remains discovery/request/approval/manual-fulfilment workflow; it is not automatic fulfilment.
- Plex Dash is less capable than Tautulli even when included with Plex Pass.
- Antstream does not accept a personal RomM library.
- Realms is substantially more constrained than a self-managed Minecraft server for mods, plugins, administration, player counts, and exports.
- Bookshelf is itself an ebook/audiobook acquisition manager. If acquisition automation is excluded, present lawful borrowing/purchase services only as partial substitutes and explicitly say no drop-in exists.

## Compact output format

Use a table with: **app/function | best hosted/subscription option | current price | privacy architecture + equivalent verdict | main limitation | official URLs**. Keep the overall conclusion short and explicit: which options are policy-based compromises, which consolidate economically, and which have no satisfactory replacement.
