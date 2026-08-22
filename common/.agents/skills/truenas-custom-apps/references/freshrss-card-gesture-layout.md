# FreshRSS card gestures and metadata overlays

Use this reference when changing a local FreshRSS card-view extension that combines touch gestures, media-first cards, and compact entry metadata.

## Interaction contract

- During a horizontal touch/pen drag, move only the card surface and reveal the configured action beneath it.
- After a committed swipe, animate the card directly back to its starting position. Do not fling it off-screen and then re-center it; that creates a distracting double movement.
- Delay action execution until the return animation completes. Keep the JavaScript action delay synchronized with the CSS settling duration so read/favorite state changes do not interrupt the snap-back.
- A tested mobile-friendly settle duration was 280 ms: slower than 210 ms without feeling sluggish. Treat it as a starting point and preserve `prefers-reduced-motion` behavior.
- Continue suppressing the synthetic post-swipe click long enough to cover the settle and action window.

## Integrated metadata layout

Prefer metadata integrated into the media rather than a separate opaque footer:

1. Use one grid row for the media, title, favorite control, feed identity, and date.
2. Place a non-interactive `::after` gradient at the bottom of `.flux_header`, behind the title and metadata.
3. Put favorite/feed/date in the same media row with `align-self: end`, a shared metadata height, and a z-index above the gradient.
4. Increase the title's bottom padding by the metadata height so title text cannot overlap the row.
5. Remove the old `auto var(--meta-height)` second row entirely; otherwise an apparently empty footer remains.
6. Apply equivalent bottom spacing to text-only cards so their summaries do not collide with overlaid metadata.
7. Keep action buttons such as read and inline-reader as independent top-corner overlays.

The gradient should remain transparent at its upper edge and darken only enough at the bottom to maintain text contrast. Metadata remains clickable; the gradient must use `pointer-events: none`.

## Image-height containment

FreshRSS/Youlag lays cards out as CSS-grid items, whose default cross-axis behavior is `stretch`. An image card can therefore grow to the height of a taller text-only neighbor even when its thumbnail remains 16:9, leaving an empty surface below the image.

- On the collapsed outer `div.flux`, use `align-self: start` and a content-sized height so the card does not stretch to the grid row.
- When the requested behavior is “show the whole source image,” do not keep a fixed `aspect-ratio` on the thumbnail **or on its `<img>`**. Youlag applies `aspect-ratio: 16 / 9` directly to the image, so resetting only the container makes a correctly tall card with a narrow 16:9 image and large black bars. Override the image with `width: 100%`, `height: auto`, `max-height: none`, `aspect-ratio: auto !important`, and `object-fit: contain`.
- If black/letterbox bars remain because companion CSS or lazy-loading keeps a stale media height, synchronize the loaded image dimensions explicitly: on initial decoration and the image `load` event, read `naturalWidth` / `naturalHeight`, set a thumbnail custom property such as `--cmc-media-aspect-ratio: <width> / <height>`, and consume it with `aspect-ratio: var(--cmc-media-aspect-ratio, auto) !important`. Remove the property when dimensions are unavailable or the image fails so text-card fallback still works.
- Load the complete cascade in the Chromium regression fixture—FreshRSS base theme, selected theme (Mapco), Youlag, Compact Media Cards, then OLED overlay. A CMC-only fixture misses Youlag's image-level 16:9 rule and can report a false pass.
- Test the JavaScript dimension handoff in jsdom by defining non-zero `naturalWidth` / `naturalHeight` and asserting the custom property. Keep the Chromium 3:4 colored-band fixture as the CSS/layout proof.
- Do not let overlaid title padding contribute intrinsic height to `.flux_header`. Position the title layer absolutely within the relatively positioned header, reset `top: auto !important` (the full theme stack can otherwise pin it to the top), and keep it above the metadata row.
- Do not put large top/bottom padding on the same element that uses `-webkit-line-clamp`; Chromium can expose an extra partial line or place the ellipsis mid-layout. Put the extended gradient on `.flux_header::after`, then make the title itself a padding-free, bottom-anchored maximum-three-line block.
- Keep no-image cards content-sized; do not force the image aspect ratio onto text-only cards.
- Test with an image card next to a deliberately taller no-image card in the same grid row. Require outer card height = header height = media height.

For translucent image controls, lower the button surface alpha rather than the icon alpha so the image remains visible while the control stays legible. Preserve the hit area and focus/hover affordances.

Luke's current persistent top-corner card-control preference (Compact Media Cards 1.3.9) is a genuinely translucent dark surface rather than either an opaque gray disc or a completely bare glyph. Apply the surface to the clickable anchor—not its positioning wrapper—using 32% black normally, 48% black on hover/focus, a subtle 12% white border, full circular radius, no shadow, and no backdrop blur. This leaves the thumbnail visibly readable through the button. Keep swipe-reveal action icons plain unless separately requested; they are revealed beside the moving card rather than persistently over its thumbnail.

- A FreshRSS card may temporarily carry `.current` while remaining collapsed. Keep the picture-card CSS active for `.current`; exclude only `.active` expanded entries. Excluding both `.active` and `.current` makes selected cards fall back to Youlag's footer layout and creates apparent per-card inconsistency.
- Some YouTube `hqdefault.jpg` / `sddefault.jpg` thumbnails are 4:3 JPEGs with a 16:9 picture physically letterboxed inside the file. CSS cannot remove those encoded bars without cropping. For `*.ytimg.com`, probe `maxresdefault`, then `hq720`, then 16:9 `mqdefault`; accept only a successfully loaded candidate with a wide aspect ratio and adequate width, then replace the card image and recalculate its media ratio. Keep the original if no valid candidate is available.
- When the requested control treatment is “icon only,” remove visible surfaces from both swipe-reveal `.cmc-swipe-icon` and persistent top-corner controls: zero border, transparent background, no shadow, no backdrop blur, and no circular border radius. Preserve the existing top-control width/height as an invisible hit area.

## Test-first workflow

1. Add a failing jsdom test before changing production code.
   - Construct the FreshRSS card DOM with a real `div.flux`, `.flux_header`, title, date, bookmark, feed identity, and action anchors.
   - jsdom may need `MouseEvent` instances augmented with `pointerId`, `pointerType: 'touch'`, and `isPrimary` to exercise delegated pointer handlers.
   - For swipe behavior, cross the commit threshold and assert the released card immediately targets `--drag-x: 0px`, not `±(card width + margin)`.
   - Assert the action does not execute before the settle duration and does execute afterward.
2. Add CSS contract assertions for the single-row layout, gradient pseudo-element, row placement, and title padding.
3. Render a representative fixture with headless Chromium and record `getBoundingClientRect()` for the header, media, title, favorite, feed, and date. Require:
   - header height equals media height;
   - title and every metadata element stay within media bounds;
   - metadata elements share the same bottom edge.
4. Use actual selector structure in the fixture. A fixture using `article.flux` gives misleading failures when production CSS targets `div.flux`.
5. Re-run JavaScript syntax checks, metadata JSON validation, and PHP lint.

## Safe deployment and verification

- Work from a copy of the live extension so existing configuration and DOM assumptions are preserved.
- Bump the extension patch version for browser cache invalidation and auditability.
- Before deployment, back up the extension directory, target user configuration, and PostgreSQL database.
- Stage files, verify expected SHA-256 hashes, preserve ownership/modes, then deploy only tested files.
- Restart through TrueNAS `app.stop` / `app.start`, wait for `RUNNING`, and require the FreshRSS container to be healthy.
- After restart, compare live hashes with tested files, confirm the extension remains enabled, and verify that the removed footer-row rule has not returned.
- Browser/PWA caches may retain old CSS or JavaScript; tell the user to refresh or reopen the installed web app once.

## Upgrade caution

These selectors were validated against FreshRSS 1.29.1 plus local card-related extensions. Re-inspect the live DOM and core event behavior after FreshRSS or companion-extension upgrades rather than assuming the structure is unchanged.
