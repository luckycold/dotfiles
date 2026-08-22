# FreshRSS OLED theme overlays and extension-update audits

Use this reference when Luke wants true OLED black over FreshRSS/Mapco/Youlag or asks to update all installed FreshRSS extensions while preserving local overlays.

## Choose an overlay, not a forked theme

- Youlag is a user extension that forces the user theme to Mapco and appends its own `theme.min.css`.
- For color-only customization, create a separate **user extension** that appends one stylesheet. A full FreshRSS theme is unnecessary unless typography/layout/assets must diverge from Mapco itself.
- Keep Youlag and other upstream extensions byte-identical. Do not patch their CSS, even for a one-line color change.
- Add the overlay after Youlag and any card/layout extension in the user's ordered `extensions_enabled` array. Later CSS plus deliberate specificity is the upgrade-safe seam.

Minimal extension shape:

```text
xExtension-OledBlackOverlay/
├── extension.php
├── metadata.json
└── static/oled-black.css
```

`extension.php` should call:

```php
Minz_View::appendStyle($this->getFileUrl('oled-black.css'));
```

## OLED CSS strategy

1. Override shared variables first:
   - `--yl-color-body-background: #000`
   - `--cmc-card-background: #000`
   - Mapco surface variables such as `--sid-bg`, `--sid-bg-alt`, `--grey-light`, and `--grey-lighter`
2. Then cover explicit upstream gradients/colors that bypass variables:
   - Youlag active/inactive cards and expanded article content
   - thumbnail/no-thumbnail placeholders
   - theater, miniplayer, tags modal, article split pane, and related-video surfaces
   - Compact Media Cards text-only fallbacks
   - Mapco settings/forms/tables that otherwise use white surfaces
3. Preserve semantic colors: favorite/watch-later states, unread badges, swipe actions, warnings, and active blue accents. OLED means true-black surfaces, not monochrome controls.
4. Neutral elevated hover/input surfaces may use `#090909`–`#181818`; avoid blue-tinted near-black values.
5. Do not override swipe-action pseudo-elements or their variables. Add a test proving the action gradient still exists.

### Unifying neutral controls with Youlag

When the user likes Youlag's **Configure view** button, treat it as the canonical neutral-control surface instead of introducing another gray:

- surface: `rgb(255 255 255 / 4%)`;
- hover/open surface: `rgb(255 255 255 / 8%)`;
- border: `rgb(255 255 255 / 9%)`;
- text: `#f6f7f9`;
- radius: `999px` for a true pill rather than Mapco's grouped 5px squircles.

Apply that palette to `#yl_nav_menu_container_content .btn` (including Mark as read, its dropdown toggle, reading-mode buttons, refresh/sort/actions, and Youlag's More settings shortcut), but only replace the background on neutral buttons. Preserve `.active`, `.btn-important`, and `.btn-attention` backgrounds so blue selection and semantic alert/action colors remain intact. Add about 5px of internal group gap; otherwise individually pill-shaped buttons still touch like a segmented control.

**Mapco dropdown-icon pitfall:** Mapco hides the child `<img class="icon">` inside dropdown toggles and normally paints `icons/more.svg` as the button's `background-image`. Therefore, never use the `background` shorthand on neutral `.btn` rules—it resets that image and creates apparently empty circles. Use `background-color` for normal and hover surfaces. When explicit semantic icons are clearer, narrowly set `background-image: none` and restore the existing child icon with `display: inline-block` for `#toggle-userqueries`, the Mark-as-read dropdown, and `#toggle-order`; test non-zero rendered icon dimensions, not merely that the `<img>` exists.

Treat Mark as read plus its dropdown as one split pill: set the form gap to zero, use `999px 0 0 999px` on the primary action and `0 999px 999px 0` on the dropdown segment, remove the primary button's right border, and retain a one-pixel left border on the dropdown as the internal separator. Keep the dropdown segment stretched to the pill height and center its icon.

Use the same quiet surface on Youlag's Manage feed, Filter category, category-filter action controls, the global header settings gear (`header.header .item.configure .dropdown > .btn.dropdown-toggle`), and the phone-only search trigger (`#dropdown-search-wrapper.only-mobile > #toggle-search`). Youlag hard-codes both circular header controls to opaque `#26272a`; the gear also has a `#57575a` hover. Override them with the canonical 4%/8% surfaces, 9% border, full circular radius, and no shadow while preserving their 40×40 hit areas and visible glyphs. Scope the search override to `@media (max-width: 840px)` and its neutral background to `:not(.active)` so an active search keeps its semantic blue state. Include hover, keyboard focus, and the respective `:target + .btn` open states. Use `background-color`, not the `background` shorthand, to avoid removing icon imagery.

For sidebar counts, target the generated pseudo-elements on `.title[data-unread]` and `a.item-title[data-unread]`; exclude `.category.important` so its semantic orange treatment remains. Match the Configure view background, border, text, shadow, and radius exactly.

The full-cascade Chromium fixture should include a real `#aside_feed` id, Youlag's `youlag-loaded` body class, an open `#yl_nav_menu_container_content.nav_menu`, representative neutral and active buttons, and a sidebar `data-unread` pseudo-element. Assert computed-style equality against Configure view, require `999px` radii and group gaps, and separately prove the active blue gradient is different and preserved.

## Test-first contract

Before production files exist, create a representative fixture that loads, in order:

1. FreshRSS base-theme CSS
2. Mapco CSS
3. Youlag CSS
4. Compact Media Cards CSS
5. the new overlay CSS

Model the real header markup when testing the global gear: title, search form/button, and `nav.item.configure > .dropdown > .btn.dropdown-toggle`. Also model FreshRSS's post-Youlag mobile search wrapper (`#dropdown-search-wrapper.only-mobile`, `#dropdown-search.dropdown-target`, and `#toggle-search.dropdown-toggle.btn`) after the category toolbar. Assert at a 390px-wide viewport that the phone search trigger's computed surface, border, radius, text color, and shadow match the gear; its box remains at least 40×40; and its magnifier remains visible. At a desktop viewport, assert that the mobile trigger is hidden so the desktop search-field geometry is not affected. Render one isolated Chromium result per viewport and reuse its computed values across assertions (or give every process a unique `--user-data-dir`); overlapping/repeated headless processes can intermittently expose a partially applied local-file cascade.

Run the test once and require it to fail because the computed base color is Youlag's near-black (for example `rgb(25, 25, 26)`) or because the extension files do not exist.

Then implement and require:

- metadata name/entrypoint/type/version are exact;
- extension PHP appends the expected stylesheet;
- Chromium computed styles for HTML, body, header, sidebar, stream, toolbar, cards, text-only fallback, panel, settings box, and inputs are `rgb(0, 0, 0)`;
- swipe action pseudo-element retains a non-black gradient;
- CSS parses/formats cleanly and PHP lints in the live FreshRSS container.

A static fixture validates the cascade but is not an authenticated live-page screenshot. Report that distinction honestly.

## Auditing extension updates

Treat “update my extensions” as an inventory and source audit, not permission to reinstall everything.

1. Enumerate every live extension's directory, `metadata.json`, version, and `.extmgr-source.json`.
2. Split extensions into:
   - source-backed GitHub installs;
   - source-backed non-GitHub installs from the current FreshRSS `extensions.json` registry;
   - genuinely local extensions.
3. Clone each verified repository at its recorded branch. For registry-only entries, use the registry's current canonical URL and directory.
4. Compare complete trees by relative path and SHA-256, excluding only `.git/` and `.extmgr-source.json`.
5. If installed and upstream trees are equal, report **already current** and do not rewrite them.
6. Never invent a source for a local extension. Extension Manager accepts GitHub repositories only; keep Codeberg/Sitosis/local extensions unmanaged unless its capabilities change.
7. Record repository commits for auditability, but do not persist commit IDs in memory/skills as current state.

This catches the important case where metadata versions match but files differ, and avoids claiming an update merely because no files needed changing.

## Safe deployment

Before installing the overlay:

- archive the entire persistent extensions tree;
- copy system and target-user config;
- create a PostgreSQL custom-format dump;
- verify every backup artifact is non-empty.

Stage only production files outside the extensions directory. Validate expected hashes and metadata, copy the staged tree into the live PHP container, and run `php -l` on that exact staged `extension.php` before publishing. Publish atomically, preserve the extension-tree ownership convention, and enable the overlay after the extensions it overrides.

## Load-order and runtime verification

FreshRSS CLI can verify the real extension cascade without browser credentials:

```php
require '/var/www/FreshRSS/cli/_cli.php';
cliInitUser('lucky');
$styles = Minz_View::headStyle();
```

Require the positions of `theme.min.css`, the card extension CSS, and `oled-black.css` to exist and require the OLED stylesheet position to be last. Also require `Minz_ExtensionManager::findExtension('OLED Black Overlay')` to return the expected class.

After a TrueNAS-managed `app.stop` / `app.start`:

- require app `RUNNING`, container `running`, and health `healthy`;
- repeat CLI class/load-order checks;
- fetch the generated `/ext.php?f=...oled-black.css` asset directly from the FreshRSS backend and require HTTP 200, `text/css`, and the expected `#000` variable;
- compare deployed hashes with tested files;
- recompute the upstream Youlag tree digest to prove it stayed unchanged;
- inspect recent logs for parse/fatal/overlay errors.

Tell Luke to refresh or reopen the installed web app once so cached CSS is replaced.
