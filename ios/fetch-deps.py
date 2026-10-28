"""Fetch fixed source archives, verify hashes, then extract without traversal."""
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
import urllib.request

root = Path(sys.argv[1]).resolve()
root.mkdir(parents=True, exist_ok=True)
sources = json.loads(Path(__file__).with_name('sources.json').read_text())
for name, spec in sources.items():
    print('Downloading', name, flush=True)
    with urllib.request.urlopen(spec['url'], timeout=120) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != spec['sha256']:
        raise SystemExit('SHA256 mismatch: ' + name)
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        archive.extractall(root, filter='data')
