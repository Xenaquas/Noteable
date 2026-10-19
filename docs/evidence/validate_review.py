"""Validate current report links, evidence hashes, and unchanged Dart sources."""
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
REPORTS = [ROOT / "README.md", *sorted((ROOT / "docs").glob("*.md"))]
broken = []
links_checked = 0
for report in REPORTS:
    source = report.read_text(encoding="utf-8-sig")
    links = re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", source)
    links += re.findall(r'src="([^"]+)"', source)
    for link in links:
        if link.startswith(("https:", "http:", "#", "mailto:")):
            continue
        target = (report.parent / link.split("#")[0]).resolve()
        links_checked += 1
        if not target.exists():
            broken.append([str(report.relative_to(ROOT)), link])

evidence = ROOT / "docs" / "evidence"
inventory = json.loads((evidence / "dart-file-inventory.json").read_text(encoding="utf-8-sig"))
changed = [
    item["Path"] for item in inventory
    if hashlib.sha256((ROOT / item["Path"]).read_bytes()).hexdigest().upper() != item["SHA256"]
]
images = json.loads((evidence / "screenshot-manifest.json").read_text())["screenshots"]
invalid_images = [
    item["file"] for item in images
    if hashlib.sha256((evidence / item["file"]).read_bytes()).hexdigest() != item["sha256"]
]
result = {
    "reports_checked": len(REPORTS),
    "local_links_checked": links_checked,
    "broken_links": broken,
    "unchanged_dart_files": len(inventory) - len(changed),
    "changed_dart_files": changed,
    "screenshots_verified": len(images),
    "bad_image_hashes": invalid_images,
    "root_markdown": sorted(item.name for item in ROOT.glob("*.md")),
}
(evidence / "logs" / "documentation-validation.json").write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
assert not broken, "Broken report links"
assert not changed, "Application Dart changed since baseline"
assert not invalid_images, "Evidence PNG hash mismatch"
assert result["root_markdown"] == ["README.md"], "Unexpected root Markdown file"
