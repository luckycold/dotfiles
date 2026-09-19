#!/usr/bin/env python3
"""Opt-in, user-local Omarchy media viewport patch; no credentials or sudo."""
import argparse
import getpass
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

CHANGES = [
    ('  property real maxLabelWidth: 180', '''  property real maxLabelWidth: 180
  // Only the title viewport grows; playback and media-source routing are unchanged.
  readonly property bool fillMediaWidth: setting("fillAvailable", true) === true
  readonly property real minimumMediaWidth: glyph.implicitWidth + row.spacing + Style.space(14)
  FlexibleMediaWidth {
    id: flexWidth
    widget: root
    anchorId: String(root.setting("fillAnchor", "omarchy.clock"))
  }'''),
    ('      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)', '''      width: flexWidth.allocatedWidth >= 0
        ? Math.max(0, flexWidth.allocatedWidth - root.minimumMediaWidth)
        : Math.min(root.maxLabelWidth, labelText.implicitWidth)'''),
    ('          id: scrollAnim', '''          id: scrollAnim
          onRunningChanged: if (!running) labelText.x = 0'''),
]


NATIVE_VISIBILITY = (
    '      visible: !root.bar.vertical && root.title !== ""',
    '      visible: !root.bar.vertical && (root.fillMediaWidth || root.title !== "")',
)


def transform(text):
    # The native service declaration survives cloning and previous layout patches.
    changes = CHANGES + ([NATIVE_VISIBILITY] if 'readonly property var mediaService:' in text else [])
    for old, new in changes:
        if new in text:
            if text.count(new) != 1 or text.count(old) != new.count(old):
                raise ValueError('Duplicate layout patch; inspect widget manually')
            continue
        if text.count(old) != 1:
            raise ValueError('Upstream widget changed; refusing an ambiguous layout patch')
        text = text.replace(old, new, 1)
    # The clone's scoped facade accepts its injected id, not the built-in alias.
    return text.replace('firstPartyServiceFor("omarchy.media")', 'firstPartyServiceFor(root.moduleName)')


def atomic_write(path, data):
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as f:
        tmp = Path(f.name)
        f.write(data)
    try:
        tmp.chmod(0o644)
        tmp.replace(path)
    finally:
        tmp.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true', help='clone if needed and apply layout')
    mode.add_argument('--check', action='store_true', help='preflight only (the default)')
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    home = Path.home()
    plugins = home / '.config/omarchy/plugins'
    native = plugins / (getpass.getuser() + '.media')
    ma = plugins / 'io.github.manologarciadev.music-assistant'
    upstream = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'shell/plugins/services/media'
    source = native if native.exists() else upstream
    # Preflight every target before making any changes. Never fetch credentials/config.
    targets = [(native, (source / 'BarWidget.qml').read_text()),
               (ma, (ma / 'BarWidget.qml').read_text())]
    patched = [(folder, text, transform(text)) for folder, text in targets]
    helpers = {name: (here / name).read_bytes() for name in ['FlexibleMediaWidth.qml', 'MediaWidthAllocator.js']}
    if not args.apply:
        print('PASS: both widgets support the patch; ' + ('native clone exists' if native.exists() else 'apply will create the native media clone'))
        return
    backup = home / '.local/state/omarchy-media-layout' / str(time.time_ns())
    backup.mkdir(parents=True, mode=0o700)
    config = home / '.config/omarchy/shell.json'
    shutil.copy2(config, backup / 'shell.json')
    (backup / 'shell.json').chmod(0o600)
    for folder, original, _ in patched:
        saved = backup / folder.name
        saved.mkdir()
        (saved / 'BarWidget.qml').write_text(original)
        for name in helpers:
            if (folder / name).exists():
                shutil.copy2(folder / name, saved / name)
    if not native.exists():
        subprocess.run(['omarchy-plugin-clone', 'omarchy.media'], check=True)
    # Detect intervening edits, including changes made during clone creation.
    for folder, original, _ in patched:
        if (folder / 'BarWidget.qml').read_text() != original:
            raise RuntimeError('Widget changed during preflight; no layout files written')
    for folder, _, updated in patched:
        for name, content in helpers.items():
            if not (folder / name).exists() or (folder / name).read_bytes() != content:
                atomic_write(folder / name, content)
        if (folder / 'BarWidget.qml').read_text() != updated:
            atomic_write(folder / 'BarWidget.qml', updated.encode())
    for folder, _, updated in patched:
        assert (folder / 'BarWidget.qml').read_text() == updated
        for name, content in helpers.items():
            assert (folder / name).read_bytes() == content
    print('Applied and verified both media layouts. Backup:', backup)
    print('Reload with: omarchy-restart-shell')


if __name__ == '__main__':
    main()
