import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('vfx_save', ROOT / 'scripts/vfx_lab/serve.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


def preset():
    p = {'version': 1}
    p.update({f['key']: f['min'] for f in bridge.SCHEMA['numbers']})
    p.update({f['key']: [0, 128, 255] for f in bridge.SCHEMA['colors']})
    return p


class SaveTests(unittest.TestCase):
    def test_saves_complete_lua_and_rejects_invalid_without_overwriting(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'preset.lua'
            valid = preset()
            bridge.save(valid, path)
            source = path.read_text()
            self.assertIn('primary = { 0, 128, 255 }', source)
            self.assertIn('return {', source)
            invalid = dict(valid, height=float('nan'))
            with self.assertRaises(ValueError):
                bridge.save(invalid, path)
            self.assertEqual(path.read_text(), source)
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_shared_schema_bounds_and_shape_are_enforced(self):
        for key, value in [('count', 3.5), ('count', True), ('height', float('inf')),
                           ('radius', -1), ('primary', [0, 1, 256]), ('primary', [0, 1]),
                           ('path', '../../other.lua'), ('version', 2)]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                bridge.validate(dict(preset(), **{key: value}))


if __name__ == '__main__':
    unittest.main()
