"""Rasterize the read-only Word exports into temporary QA page images."""
import json
import sys
from pathlib import Path
from pdf2image import convert_from_path
from PIL import Image, ImageOps, ImageDraw

root = Path(sys.argv[1])
records = json.loads((root / 'word-render-results.json').read_text(encoding='utf-8-sig'))
if isinstance(records, dict):
    records = [records]
pages = []
for record in records:
    pdf = Path(record['pdf'])
    images = convert_from_path(str(pdf), dpi=110)
    for i, im in enumerate(images, 1):
        target = pdf.parent / f'page-{i}.png'
        im.save(target)
        pages.append({'document': record['document'], 'page': i, 'image': str(target)})
    print(record['document'], len(images), flush=True)
(root / 'pages.json').write_text(json.dumps(pages, indent=2), encoding='utf8')
# Contact sheets are navigation aids; individual page PNGs remain available.
for start in range(0, len(pages), 6):
    sheet = Image.new('RGB', (1800, 2628), 'white')
    draw = ImageDraw.Draw(sheet)
    for n, page in enumerate(pages[start:start+6]):
        im = Image.open(page['image']); im.thumbnail((590, 1250))
        x, y = (n % 3) * 600, (n // 3) * 1314
        sheet.paste(im, (x + (600-im.width)//2, y+40))
        draw.text((x+8,y+8), f"{start+n+1} {page['document']} p{page['page']}", fill='black')
    sheet.save(root / f'contact-{start//6+1:02}.png')
print(json.dumps({'pages': len(pages), 'documents': len(records)}))
