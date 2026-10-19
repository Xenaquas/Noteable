"""Prepare exact staged Git objects for publication through the GitHub connector.

The connector account is authoritative when the terminal account differs.
Payloads contain staged bytes, not filesystem guesses. Temporary payloads must
be stored outside the repository. No tokens or other credentials are handled.
"""
import argparse
import base64
import json
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('output', type=Path)
args = p.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
entries = []
binary = {}
texts = []
for record in subprocess.check_output(['git', 'ls-files', '-s', '-z']).split(b'\0'):
    if not record:
        continue
    metadata, filename = record.split(b'\t', 1)
    mode, sha, _ = metadata.decode().split()
    path = filename.decode('utf8')
    data = subprocess.check_output(['git', 'cat-file', 'blob', sha])
    entry = {'path': path, 'mode': mode, 'type': 'blob', 'sha': sha}
    entries.append(entry)
    try:
        if b'\0' in data:
            raise ValueError('binary')
        text = data.decode('utf8')
    except (ValueError, UnicodeDecodeError):
        if sha not in binary:
            encoded = base64.b64encode(data).decode('ascii')
            (args.output / (sha + '.b64')).write_text(encoded, encoding='ascii')
            binary[sha] = {'sha': sha, 'path': path, 'bytes': len(data), 'base64_length': len(encoded)}
    else:
        texts.append({'path': path, 'mode': mode, 'type': 'blob', 'content': text})
manifest = {'entries': entries, 'binary': list(binary.values()), 'text_entries': len(texts), 'staged_tree': subprocess.check_output(['git', 'write-tree']).decode().strip()}
(args.output / 'snapshot.json').write_text(json.dumps(manifest, ensure_ascii=True), encoding='ascii')
# JSON is escaped to ASCII so PowerShell and tool encoding cannot alter bytes.
payload = json.dumps(texts, ensure_ascii=True)
(args.output / 'text-tree.json').write_text(payload, encoding='ascii')
print(json.dumps({'files': len(entries), 'unique_binary_blobs': len(binary), 'text_entries': len(texts), 'text_payload_chars': len(payload), 'tree': manifest['staged_tree']}))
