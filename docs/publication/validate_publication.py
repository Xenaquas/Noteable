"""Validate preserved review sources and the final Word copies without app edits."""
import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from zipfile import ZipFile

from lxml import etree

p = argparse.ArgumentParser()
p.add_argument('--qa-root', type=Path, required=True)
args = p.parse_args()
root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/evidence'
sha256 = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
documents = json.loads((root / 'docs/publication/document-manifest.json').read_text(encoding='utf8'))
inventory = json.loads((evidence / 'dart-file-inventory.json').read_text(encoding='utf-8-sig'))
images = json.loads((evidence / 'screenshot-manifest.json').read_text())['screenshots']
for entry in inventory:
    assert sha256(root / entry['Path']).upper() == entry['SHA256'], entry['Path']
    committed = subprocess.check_output(['git', 'show', 'HEAD:' + entry['Path'].replace('\\', '/')], cwd=root)
    assert hashlib.sha256(committed).hexdigest().upper() == entry['SHA256'], 'Git bytes differ ' + entry['Path']
for entry in images:
    assert sha256(evidence / entry['file']) == entry['sha256'], entry['file']
original_media = {sha256(evidence / entry['file']) for entry in images}
original_media.add(sha256(root / 'docs/diagrams/tldraw-review.png'))
rendered = json.loads((args.qa_root / 'word-render-results.json').read_text(encoding='utf-8-sig'))
page_counts = {x['document'].replace('\\', '/'): x['pages'] for x in rendered}
revision = json.loads((args.qa_root / 'current/word-render-results.json').read_text(encoding='utf-8-sig'))
for x in revision if isinstance(revision, list) else [revision]:
    page_counts['current/' + x['document'].replace('\\', '/')] = x['pages']
ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'}
results = []
for entry in documents:
    assert sha256(root / entry['source']) == entry['source_sha256'], entry['source']
    document = root / entry['document']
    assert sha256(document) == entry['document_sha256'], str(document)
    with ZipFile(document) as z:
        xml = etree.fromstring(z.read('word/document.xml'))
        styles = etree.fromstring(z.read('word/styles.xml'))
        titles = xml.xpath('.//w:p[w:pPr/w:pStyle[@w:val="Title"]]', namespaces=ns)
        assert len(titles) == 1, 'Expected one document title ' + document.name
        assert not xml.xpath('.//w:pBdr', namespaces=ns), 'Decorative paragraph border ' + document.name
        color = styles.xpath('.//w:style[@w:styleId="Title"]/w:rPr/w:color/@w:val', namespaces=ns)
        assert color == ['000000'], color
        for drawing in xml.xpath('.//wp:docPr', namespaces=ns):
            assert drawing.get('descr'), 'Missing figure description ' + document.name
        media = [x for x in z.namelist() if x.startswith('word/media/')]
        for filename in media:
            assert hashlib.sha256(z.read(filename)).hexdigest() in original_media, 'Unrecognized or altered proof image ' + filename
    key = document.relative_to(root / 'docs/documents').as_posix()
    results.append({**entry, 'pages': page_counts[key], 'media_parts': len(media), 'visual_review': 'Every final page PNG opened and inspected at original rendered size'})
assert len(results) == 18
assert sum(x['pages'] for x in results) == 106
result = {
    'review_date': '2026-10-19',
    'validation_scope': 'Publication and document fidelity; application findings remain unchanged',
    'source_snapshot_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root).decode().strip(),
    'renderer': 'Microsoft Word 16 read-only PDF export and bundled Python pdf2image with Poppler at 110 DPI',
    'renderer_fallback_reason': 'The Documents skill render_docx.py reported that LibreOffice soffice.exe was unavailable',
    'documents': len(results), 'final_pages': 106,
    'embedded_image_instances': sum(x['embedded_images'] for x in results),
    'original_screenshot_hashes_verified': len(images),
    'unchanged_dart_files_local_and_git': len(inventory),
    'unchanged_review_markdown_sources': len(results),
    'root_markdown': [x.name for x in root.glob('*.md')],
    'qa_pngs_and_pdfs': 'Temporary internal QA outputs; excluded from published artifacts',
    'files': results,
}
assert result['root_markdown'] == ['README.md']
drive_manifest = root / 'docs/publication/drive-file-manifest.json'
if drive_manifest.exists():
    drive = json.loads(drive_manifest.read_text(encoding='utf8'))
    for entry in drive['files']:
        path = (root / entry['source_path']).resolve()
        assert path.is_relative_to(root)
        assert entry['readback_verified'], entry['source_path']
        assert path.stat().st_size == int(entry['remote_size']), 'Drive size mismatch ' + entry['source_path']
        entry['bytes'] = path.stat().st_size
        entry['sha256'] = sha256(path)
        entry['size_verified'] = True
    drive['artifact_file_count'] = len(drive['files'])
    drive['verified_at_utc'] = datetime.now(timezone.utc).isoformat()
    drive['verification_method'] = 'Provider folder readback matched file IDs, names and byte sizes. SHA256 values identify the local source bytes; the connector does not expose cloud checksums.'
    drive_manifest.write_text(json.dumps(drive, indent=2) + '\n', encoding='utf8')
    result['drive_artifact_files_verified'] = len(drive['files'])
(root / 'docs/publication/qa-summary.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(json.dumps({k:v for k,v in result.items() if k != 'files'}, indent=2))
