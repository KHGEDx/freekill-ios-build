"""Validate a device build before creating an unsigned IPA for external signing."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import stat
import struct
import subprocess
import sys
import zipfile

TARGET_OS = (16, 1, 1)


def version(text):
    return tuple((list(map(int, text.split('.'))) + [0, 0])[:3])


def macho_info(data):
    if len(data) < 32:
        raise ValueError('Truncated Mach-O header')
    magic, cpu, _, _, count, size, _, _ = struct.unpack_from('<8I', data)
    if magic != 0xFEEDFACF or cpu != 0x0100000C:
        raise ValueError('Expected a thin arm64 device Mach-O binary')
    end = 32 + size
    if end > len(data):
        raise ValueError('Truncated Mach-O load commands')
    position = 32
    build = None
    for _ in range(count):
        if position + 8 > end:
            raise ValueError('Invalid load command')
        command, length = struct.unpack_from('<2I', data, position)
        if length < 8 or position + length > end:
            raise ValueError('Invalid load command size')
        if command == 0x32:  # LC_BUILD_VERSION
            if length < 24:
                raise ValueError('Truncated LC_BUILD_VERSION')
            platform, minimum = struct.unpack_from('<2I', data, position + 8)
            deployment = (minimum >> 16, minimum >> 8 & 255, minimum & 255)
            if platform != 2:
                raise ValueError('Binary targets simulator/macOS instead of iOS device')
            if deployment > TARGET_OS:
                raise ValueError('Binary requires iOS ' + '.'.join(map(str, deployment)))
            build = {'platform': 'iOS-device', 'minimum_os': '.'.join(map(str, deployment))}
        if command in (0xC, 0x18 | 0x80000000, 0x1F | 0x80000000):
            name_offset = struct.unpack_from('<I', data, position + 8)[0]
            name = data[position + name_offset:position + length].split(b'\0', 1)[0].decode()
            if name.startswith('/') and not name.startswith(('/usr/lib/', '/System/Library/')):
                raise ValueError('Host library reference in device binary: ' + name)
        position += length
    if build is None:
        raise ValueError('No explicit iOS device LC_BUILD_VERSION')
    return build


def package(app, output, source=None):
    app, output = Path(app).resolve(), Path(output).resolve()
    with (app / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
        raise ValueError('Info.plist does not target iPhoneOS')
    if version(info['MinimumOSVersion']) > TARGET_OS:
        raise ValueError('Info.plist requires a system newer than iPadOS 16.1.1')
    if 2 not in info.get('UIDeviceFamily', []):
        raise ValueError('Info.plist does not support iPad')
    executable = app / info['CFBundleExecutable']
    if executable.parent != app or not executable.is_file():
        raise ValueError('Missing or invalid app executable')
    if not (app / 'fk-data/Fk/main.qml').is_file():
        raise ValueError('Missing FreeKill QML resources')
    binaries = {executable.relative_to(app).as_posix(): macho_info(executable.read_bytes())}
    for path in app.rglob('*'):
        if path.is_symlink():
            raise ValueError('Unexpected symlink in iOS app: ' + str(path))
        if path.is_file() and path != executable:
            with path.open('rb') as stream:
                magic = stream.read(4)
            if magic in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'):
                binaries[path.relative_to(app).as_posix()] = macho_info(path.read_bytes())
    output.mkdir(parents=True, exist_ok=True)
    ipa = output / 'FreeKill-iPad-unsigned.ipa'
    with zipfile.ZipFile(ipa, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(app.rglob('*')):
            if not path.is_file():
                continue
            name = 'Payload/' + app.name + '/' + path.relative_to(app).as_posix()
            item = zipfile.ZipInfo(name)
            item.create_system = 3
            mode = stat.S_IFREG | (0o755 if path == executable or os.access(path, os.X_OK) else 0o644)
            item.external_attr = mode << 16
            item.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(item, path.read_bytes())
    report = {'status': 'compiled-device-binary-not-device-tested', 'signed': False,
              'target_device_os': '16.1.1', 'binaries': binaries,
              'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest()}
    if source:
        report['upstream_commit'] = subprocess.check_output(
            ['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    (output / 'build-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Created unsigned IPA:', ipa)
    return ipa


if __name__ == '__main__':
    try:
        package(*sys.argv[1:4])
    except (ValueError, KeyError, OSError) as error:
        raise SystemExit('IPA validation failed: ' + str(error))
