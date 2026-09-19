import importlib.util
from pathlib import Path
import unittest

# Minimal source excerpts; no machine-local files are needed by the unit suite.
COMMON_SOURCE = '''  property real maxLabelWidth: 180
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
          id: scrollAnim
'''
NATIVE_SOURCE = COMMON_SOURCE + '''  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
      visible: !root.bar.vertical && root.title !== ""
'''
MA_SOURCE = COMMON_SOURCE + '      visible: !root.bar.vertical\n'

class PatchTests(unittest.TestCase):
    def setUp(self):
        p = Path(__file__).with_name('apply.py')
        self.assertTrue(p.exists(), 'reproducible layout installer is missing')
        spec = importlib.util.spec_from_file_location('apply_layout', p)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def test_transform_both_upstreams_and_idempotence(self):
        for suffix in ['// native media', '// Music Assistant']:
            original = '\n'.join(old for old, _ in self.module.CHANGES) + suffix
            updated = self.module.transform(original)
            self.assertIn('FlexibleMediaWidth {', updated)
            self.assertEqual(updated, self.module.transform(updated))
            self.assertIn('onRunningChanged: if (!running) labelText.x = 0', updated)

    def test_clone_uses_its_own_service_facade(self):
        original = '\n'.join(old for old, _ in self.module.CHANGES)
        original += '\nbar?.shell?.firstPartyServiceFor("omarchy.media")'
        self.assertIn('firstPartyServiceFor(root.moduleName)', self.module.transform(original))

    def test_native_visibility_and_existing_layout_upgrade(self):
        original = NATIVE_SOURCE
        previous = original
        for old, new in self.module.CHANGES:
            previous = previous.replace(old, new, 1)
        previous = previous.replace('firstPartyServiceFor("omarchy.media")', 'firstPartyServiceFor(root.moduleName)')
        old_visibility = '      visible: !root.bar.vertical && root.title !== ""'
        new_visibility = '      visible: !root.bar.vertical && (root.fillMediaWidth || root.title !== "")'
        for source in (original, previous):
            with self.subTest(upgrade=source == previous):
                updated = self.module.transform(source)
                self.assertIn(new_visibility, updated)
                self.assertEqual(previous.replace(old_visibility, new_visibility), updated)
                self.assertEqual(updated, self.module.transform(updated))
                expression = new_visibility.split('visible: ', 1)[1]
                for vertical in (False, True):
                    for fill in (False, True):
                        for title in ('', 'track'):
                            evaluated = expression.replace('root.bar.vertical', repr(vertical)).replace('root.fillMediaWidth', repr(fill)).replace('root.title', repr(title)).replace('!==', '!=').replace('&&', ' and ').replace('||', ' or ').replace('!', 'not ', 1)
                            self.assertEqual(eval(evaluated), not vertical and (fill or bool(title)))

    def test_native_visibility_drift_rejected(self):
        original = NATIVE_SOURCE
        drifted = original.replace('visible: !root.bar.vertical && root.title !== ""', 'visible: root.hasMedia')
        with self.assertRaises(ValueError):
            self.module.transform(drifted)

    def test_mixed_duplicate_each_marker_rejected(self):
        original = NATIVE_SOURCE
        patched = self.module.transform(original)
        markers = [old for old, _ in self.module.CHANGES]
        markers.append('      visible: !root.bar.vertical && root.title !== ""')
        for marker in markers:
            with self.subTest(marker=marker):
                with self.assertRaises(ValueError):
                    self.module.transform(patched + '\n' + marker)

    def test_already_patched_music_assistant_unchanged(self):
        source = self.module.transform(MA_SOURCE)
        self.assertEqual(source, self.module.transform(source))
        self.assertIn('      visible: !root.bar.vertical\n', source)

    def test_unknown_upstream_rejected(self):
        with self.assertRaises(ValueError):
            self.module.transform('BarWidget { property real maxLabelWidth: 200 }')

if __name__ == '__main__':
    unittest.main()
