"""Stage game data into an already-built iOS app; never include build outputs."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request

src, dest, host = (Path(p).resolve() for p in sys.argv[1:4])
dest.mkdir(parents=True, exist_ok=False)
for name in ('audio', 'fonts', 'image', 'lua', 'ltk', 'LunarLtk', 'Fk'):
    shutil.copytree(src / name, dest / name)
packages = dest / 'packages'
packages.mkdir()
for name in ('standard', 'standard_cards', 'maneuvering', 'test'):
    shutil.copytree(src / 'packages' / name, packages / name)
(packages / 'test' / 'test.lua').unlink(missing_ok=True)
for name in ('packages', 'server', 'client'):
    (dest / name).mkdir(exist_ok=True)
    for sql in (src / name).glob('*.sql'):
        shutil.copy2(sql, dest / name / sql.name)
for name in ('LICENSE', 'waiting_tips.txt'):
    shutil.copy2(src / name, dest / name)
for lang in ('zh_CN', 'en_US', 'vi_VN'):
    subprocess.run([str(host / 'bin/lrelease'), str(src / 'lang' / (lang + '.ts')),
                    '-qm', str(dest / (lang + '.qm'))], check=True)
revision = subprocess.check_output(['git', '-C', str(src), 'rev-parse', 'HEAD'], text=True).strip()
revision += '-' + hashlib.sha256((src / 'ios/freekill-ios.patch').read_bytes()).hexdigest()
(dest / 'ios-source-revision').write_text(revision + '\n')
# Use upstream's protocol version, not an unrelated iOS marketing version.
import re
match = re.search(r'project\(FreeKill VERSION ([\d.]+)\)', (src / 'CMakeLists.txt').read_text())
if not match:
    raise SystemExit('Cannot identify FreeKill version')
(dest / 'fk_ver').write_text(match.group(1) + '\n')
url = 'https://raw.githubusercontent.com/Qsgs-Fans/freekill-server-list/master/server-list.json'
with urllib.request.urlopen(url, timeout=60) as response:
    server_list = response.read()
json.loads(server_list)
(dest / 'server-list.json').write_bytes(server_list)
print('Staged resources for', revision)
