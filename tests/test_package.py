"""Exercise the device/simulator and OS guards without claiming a real build."""
import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('ipa', Path(__file__).parents[1] / 'ios/package-ipa.py')
ipa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ipa)


def image(platform=2, minimum=16 << 16, cpu=0x0100000C):
    return (struct.pack('<8I', 0xFEEDFACF, cpu, 0, 2, 1, 24, 0, 0)
            + struct.pack('<6I', 0x32, 24, platform, minimum, 18 << 16, 0))


class DevicePackageTests(unittest.TestCase):
    def test_rejects_simulator_even_when_arm64(self):
        with self.assertRaisesRegex(ValueError, 'simulator'):
            ipa.macho_info(image(platform=7))

    def test_rejects_newer_os_requirement(self):
        with self.assertRaisesRegex(ValueError, 'requires iOS'):
            ipa.macho_info(image(minimum=17 << 16))

    def test_rejects_desktop_x86(self):
        with self.assertRaisesRegex(ValueError, 'arm64'):
            ipa.macho_info(image(cpu=0x01000007))

    def test_rejects_truncated_load_commands(self):
        with self.assertRaisesRegex(ValueError, 'Truncated'):
            ipa.macho_info(image()[:-4])

    def test_payload_layout_and_executable_permissions(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / 'FreeKill.app'
            (app / 'fk-data/Fk').mkdir(parents=True)
            (app / 'fk-data/Fk/main.qml').write_text('test fixture')
            (app / 'FreeKill').write_bytes(image())
            info = {'CFBundleSupportedPlatforms': ['iPhoneOS'],
                    'MinimumOSVersion': '16.0', 'UIDeviceFamily': [2],
                    'CFBundleExecutable': 'FreeKill'}
            (app / 'Info.plist').write_bytes(plistlib.dumps(info))
            path = ipa.package(app, Path(temporary) / 'output')
            with zipfile.ZipFile(path) as archive:
                entry = archive.getinfo('Payload/FreeKill.app/FreeKill')
                self.assertEqual((entry.external_attr >> 16) & 0o777, 0o755)
            info['MinimumOSVersion'] = '16.2'
            (app / 'Info.plist').write_bytes(plistlib.dumps(info))
            with self.assertRaisesRegex(ValueError, 'newer'):
                ipa.package(app, Path(temporary) / 'reject')


if __name__ == '__main__':
    unittest.main()
