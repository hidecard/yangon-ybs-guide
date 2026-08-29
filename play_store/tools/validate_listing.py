from pathlib import Path
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
listing = (ROOT / "PLAY_STORE_PACKAGE.md").read_text(encoding="utf-8")
assets = ROOT / "assets"

for label, pattern in [
    ("Burmese title", r"### App title\n\n\*\*(.*?)\*\*"),
    ("Burmese short description", r"### Short description\n\n\*\*(.*?)\*\*"),
]:
    match = re.search(pattern, listing, flags=re.S)
    value = match.group(1).strip() if match else ""
    print(f"{label}: {len(value)} chars | {value}")

english = re.findall(r"### Short description\n\n\*\*(.*?)\*\*", listing, flags=re.S)
if len(english) > 1:
    print(f"English short description: {len(english[1].strip())} chars | {english[1].strip()}")

for path in sorted(assets.glob("*.png")):
    with Image.open(path) as img:
        size_mb = path.stat().st_size / (1024 * 1024)
        print(f"{path.name}: {img.width}x{img.height}, {size_mb:.3f} MB")
        assert size_mb <= 8, f"{path.name} exceeds 8 MB"

for name, expected in [("feature_graphic_1024x500.png", (1024, 500)), ("app_icon_512x512.png", (512, 512))]:
    with Image.open(assets / name) as img:
        assert (img.width, img.height) == expected, f"{name} has wrong dimensions"

for name in [
    "01_find_route_1080x1920.png",
    "02_route_directory_1080x1920.png",
    "03_burmese_assistant_1080x1920.png",
    "04_trip_plan_1080x1920.png",
    "05_offline_alerts_1080x1920.png",
]:
    with Image.open(assets / name) as img:
        assert (img.width, img.height) == (1080, 1920), f"{name} has wrong dimensions"

print("Asset checks: PASS")
