# Adaptive Omarchy media bars

Opt-in, user-local customization for the native MPRIS media widget and the
Music Assistant plugin. Both title viewports fill the unused space on their
side of the centered clock. Scrolling runs only when the title still overflows.
Each monitor gets its own allocation; the clock and the other widgets retain
space. No playback, global keybinding, or remote-speaker routing changes.

## Apply / reapply

Prerequisites: Omarchy's Quickshell shell with the stock centered `omarchy.clock`
anchor, Python 3, and the Music Assistant plugin already installed. This is a
bootstrap (not a Stow package), so it does not affect other machines when the
usual profiles are stowed.

```bash
python3 ~/dotfiles/bootstrap/omarchy-media-layout/apply.py --check
python3 ~/dotfiles/bootstrap/omarchy-media-layout/apply.py --apply
omarchy-restart-shell
```

The apply command:

- Preflights both widgets and refuses changed/ambiguous upstream code.
- Creates the native widget's personal clone with the supported
  `omarchy-plugin-clone omarchy.media` command if needed.
- Uses the clone's own service facade, preserving native MPRIS arbitration.
- Patches only the two user-local widgets and installs the small shared allocator.
- Backs up touched files and shell configuration under
  `~/.local/state/omarchy-media-layout/` and reads installed bytes back.

No sudo, system-file edits, whole-shell replacement, automatic updater, or
background width-polling process is involved. Reapplying is idempotent. The
native clone is intentionally a snapshot: after updating/recreating it from
Omarchy, re-run the preflight and apply commands. If preflight fails, review the
new widget rather than forcing a patch. A plugin update may also require reapply.

## Configuration / undo

The widget layout entries accept `"fillAvailable": false` to restore their
original bounded width. Omit it or set it to `true` to fill. For another native
center anchor, set each widget's `fillAnchor` to the **actual configured anchor
ID**. Vertical bars and missing anchors use the original 180px title cap.
Extremely narrow bars can still overflow when fixed controls plus minimum icon
widths alone exceed the screen; the customization does not hide controls.

To fully undo, restore the widget files from the printed backup and restart the
shell. If the bootstrap created the native clone, remove it via Omarchy's plugin
manager to switch back to the stock media widget. Retain the Music Assistant
plugin and helper unless you intend to uninstall playback too.

## Related Music Assistant implementation

`music-assistant-source.json` records the source repository/ref for the verified
plugin and separate local playback helper, including the keyboard-focus/library
fixes and local-device-only MPRIS adapter. Keep source development in that fork,
not a duplicate vendor tree in dotfiles. The fork's `local-player/install.sh`
installs its helper and companion user units without starting playback.

The installed plugin belongs at
`~/.config/omarchy/plugins/io.github.manologarciadev.music-assistant/`.
Runtime configuration stays private at `~/.config/music-assistant/config.json`;
its token, server connection, browser profile, and player identity are **not**
tracked here. Do not copy the live shell.json wholesale into dotfiles either.

## Tests and verified behavior

```bash
cd ~/dotfiles/bootstrap/omarchy-media-layout
python3 -m unittest test_apply.py
node --test tests/*.test.cjs
# Optional native fixture in the logged-in Wayland session (no audio backend):
python3 tests/run_native_width_test.py
```

The allocator has 14 unit/scene-adapter tests; the patcher has 7 tests including
idempotence, upstream drift/duplicate-marker refusal, artist-only visibility,
and the clone's own-service lookup. The isolated native QML fixture passed
long-to-short marquee reset, resize, artist-only, fill toggles, and hide/reappear
checks with clean logs; it uses synthetic metadata without starting audio.
Run native checks with displays awake: DPMS-off can suspend Qt layout polishing
and compositor resize delivery even while IPC continues to respond. The tests
do not change display power or unlock the session.
Native acceptance on the laptop plus two external displays verified:

- Laptop widget widths expanded to 475px (native) and 320px (Music Assistant).
- Both 2560-logical-pixel external bars expanded to 1090px and 880px.
- Center clock retained its position, with approximately 8px between groups.
- Both widgets returned to stock bounded widths with filling disabled, then
  expanded again when reenabled; temporary settings were restored.
- No new layout/plugin binding errors; full-width bar screenshots checked.

The exact widths adapt to visible indicators/workspaces/controls. Tests using
JavaScript scene fixtures are not substitutes for native Quickshell rendering.
The shared files match the Music Assistant fork; synchronize them when updating
this bootstrap. Native widget snippets derive from Omarchy's MIT-licensed
`basecamp/omarchy` shell, `plugins/services/media/BarWidget.qml`.
