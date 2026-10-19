"""Capture exact emulator PNGs and UI hierarchies for the review.

Usage: python docs/evidence/capture_android.py screenshot 01-home
       python docs/evidence/capture_android.py dump current
"""
import pathlib
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

ROOT = pathlib.Path(__file__).resolve().parent
ADB = ["adb", "-s", "emulator-5554"]
action, name = sys.argv[1:3]
if action == "screenshot":
    data = subprocess.check_output(ADB + ["exec-out", "screencap", "-p"])
    assert data.startswith(b"\x89PNG\r\n\x1a\n"), "Invalid PNG"
    target = ROOT / "screenshots" / f"{name}.png"
    target.write_bytes(data)
    print(target)
elif action == "dump":
    subprocess.run(ADB + ["shell", "uiautomator", "dump", "/sdcard/dm-review.xml"], check=True, capture_output=True)
    data = subprocess.check_output(ADB + ["exec-out", "cat", "/sdcard/dm-review.xml"])
    (ROOT / "logs" / f"{name}.xml").write_bytes(data)
    import xml.etree.ElementTree as ET
    for node in ET.fromstring(data).iter("node"):
        label = node.get("text") or node.get("content-desc")
        if label:
            print(label, node.get("bounds"), "clickable=" + node.get("clickable", ""))
else:
    raise SystemExit("Expected screenshot or dump")
