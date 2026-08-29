from __future__ import annotations

from pathlib import Path
from textwrap import wrap

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets"
OUT.mkdir(parents=True, exist_ok=True)

NAVY = "#0F172A"
NAVY_2 = "#17233A"
AMBER = "#D97706"
AMBER_LIGHT = "#FEF3C7"
WHITE = "#FFFFFF"
SLATE_100 = "#F1F5F9"
SLATE_300 = "#CBD5E1"
SLATE_500 = "#64748B"
SLATE_700 = "#334155"
BLUE = "#2563EB"
GREEN = "#10B981"

FONT_MY = "/usr/share/fonts/truetype/noto/NotoSansMyanmar-Medium.ttf"
FONT_MY_BOLD = "/usr/share/fonts/truetype/noto/NotoSansMyanmar-Bold.ttf"
FONT_EN = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_EN_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(size: int, bold: bool = False, english: bool = False):
    path = FONT_EN_BOLD if english and bold else FONT_EN if english else FONT_MY_BOLD if bold else FONT_MY
    return ImageFont.truetype(path, size)


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def centered(draw, xy, text, fnt, fill=WHITE):
    box = draw.textbbox((0, 0), text, font=fnt)
    draw.text((xy[0] - (box[2] - box[0]) / 2, xy[1] - (box[3] - box[1]) / 2), text, font=fnt, fill=fill)


def wrap_text(text: str, width: int):
    return "\n".join(wrap(text, width=width, break_long_words=False, break_on_hyphens=False))


def bus_icon(size=180, bg=(0, 0, 0, 0), bus=WHITE):
    img = Image.new("RGBA", (size, size), bg)
    d = ImageDraw.Draw(img)
    pad = int(size * 0.2)
    x0, y0, x1, y1 = pad, pad + 8, size - pad, size - pad - 4
    rounded(d, (x0, y0, x1, y1), int(size * 0.12), bus)
    d.rectangle((x0 + int(size*.12), y0 + int(size*.12), x1 - int(size*.12), y0 + int(size*.42)), fill=bg)
    d.ellipse((x0 + int(size*.16), y1 - int(size*.17), x0 + int(size*.31), y1 - int(size*.02)), fill=bg)
    d.ellipse((x1 - int(size*.31), y1 - int(size*.17), x1 - int(size*.16), y1 - int(size*.02)), fill=bg)
    d.line((x0 + int(size*.12), y1 - int(size*.28), x1 - int(size*.12), y1 - int(size*.28)), fill=bg, width=max(2, size//38))
    return img


def add_phone_base(draw: ImageDraw.ImageDraw, title: str, subtitle: str):
    # background and soft glow
    draw.rectangle((0, 0, 1080, 1920), fill=NAVY)
    draw.ellipse((760, -180, 1260, 320), fill="#24324E")
    draw.ellipse((-220, 1420, 300, 1940), fill="#182640")
    centered(draw, (540, 82), title, font(48, bold=True), WHITE)
    centered(draw, (540, 145), subtitle, font(25), "#CBD5E1")
    # phone shadow and frame
    rounded(draw, (92, 220, 988, 1850), 70, "#050B17")
    rounded(draw, (112, 240, 968, 1830), 58, WHITE)
    rounded(draw, (470, 260, 610, 282), 10, "#0B1220")
    # status bar
    draw.text((150, 292), "10:15", font=font(20, bold=True, english=True), fill=SLATE_700)
    draw.text((818, 292), "4G   73%", font=font(18, english=True), fill=SLATE_500)
    # app header
    rounded(draw, (150, 340, 222, 412), 18, NAVY)
    icon = bus_icon(72)
    draw._image.paste(icon, (150, 340), icon)
    draw.text((244, 353), "YBS AI", font=font(27, bold=True, english=True), fill=NAVY)
    rounded(draw, (380, 358, 470, 397), 12, SLATE_100)
    draw.text((400, 363), "3.3.4", font=font(17, english=True), fill=SLATE_500)
    draw.line((150, 440, 930, 440), fill="#E2E8F0", width=2)


def draw_home_content(d):
    rounded(d, (150, 480, 930, 650), 28, SLATE_100)
    d.text((185, 510), "လမ်းကြောင်းကို ရှာဖွေပါ", font=font(33, bold=True), fill=NAVY)
    d.text((185, 570), "သွားမည့်နေရာကို အလွယ်တကူ ရွေးချယ်ပါ", font=font(22), fill=SLATE_500)
    rounded(d, (150, 690, 930, 850), 28, AMBER_LIGHT)
    d.text((185, 724), "မြန်မြန်ရှာရန်", font=font(27, bold=True), fill=AMBER)
    d.text((185, 774), "စတင်မှတ်တိုင်  →  ဆင်းမည့်မှတ်တိုင်", font=font(22), fill=SLATE_700)
    rounded(d, (150, 895, 930, 1035), 28, NAVY)
    d.text((190, 940), "လမ်းကြောင်းရှာပါ", font=font(28, bold=True), fill=WHITE)
    centered(d, (860, 964), "→", font(40, bold=True, english=True), AMBER_LIGHT)


def draw_route_content(d):
    rounded(d, (150, 480, 930, 590), 22, SLATE_100)
    d.text((195, 510), "ကားလိုင်း သို့မဟုတ် မြို့နယ်ဖြင့်ရှာရန်", font=font(23), fill=SLATE_500)
    for i, (num, name, color) in enumerate([("1", "YBS Route · GYCT", NAVY), ("36", "မြေနီကုန်း → ဆူးလေ", AMBER), ("117", "လှည်းတန်း → အင်းစိန်", BLUE)]):
        y = 650 + i * 190
        rounded(d, (150, y, 930, y + 150), 24, WHITE, "#E2E8F0", 2)
        rounded(d, (180, y + 28, 285, y + 116), 20, color)
        centered(d, (232, y + 70), num, font(28, bold=True, english=True), WHITE)
        d.text((325, y + 30), name, font=font(25, bold=True), fill=NAVY)
        d.text((325, y + 84), "မှတ်တိုင်များနှင့် အသေးစိတ်ကြည့်ရန်  ›", font=font(19), fill=SLATE_500)


def draw_assistant_content(d):
    rounded(d, (150, 480, 930, 720), 24, "#EEF2F7")
    d.text((185, 520), wrap_text("မင်္ဂလာပါ! YBS Assistant ပါ။ ဘယ်ကနေ ဘယ်ကို သွားချင်လဲ?", 30), font=font(25), fill=NAVY, spacing=10)
    rounded(d, (150, 780, 930, 930), 20, AMBER_LIGHT)
    d.text((190, 820), "မြေနီကုန်း ကနေ ဆူးလေ ကို", font=font(23, bold=True), fill=AMBER)
    rounded(d, (150, 980, 930, 1195), 24, WHITE, "#E2E8F0", 2)
    d.text((190, 1015), "ရှာဖွေတွေ့ရှိသော လမ်းကြောင်း", font=font(23, bold=True), fill=NAVY)
    rounded(d, (190, 1080, 295, 1145), 15, NAVY)
    centered(d, (242, 1112), "YBS 36", font(19, bold=True, english=True), WHITE)
    d.text((325, 1092), "တိုက်ရိုက် • 8.4 km", font=font(22), fill=SLATE_700)
    rounded(d, (150, 1270, 930, 1400), 24, SLATE_100)
    d.text((185, 1310), "မေးမြန်းလိုသည်များကို ရိုက်ထည့်ပါ...", font=font(22), fill=SLATE_500)
    rounded(d, (840, 1285, 910, 1385), 20, AMBER)
    centered(d, (875, 1335), "→", font(35, bold=True, english=True), WHITE)


def draw_plan_content(d):
    rounded(d, (150, 480, 930, 720), 24, "#E8F0FF")
    # simple map area
    for x, y, x2, y2 in [(180, 560, 900, 650), (250, 500, 450, 700), (520, 500, 760, 700), (300, 680, 860, 520)]:
        d.line((x, y, x2, y2), fill="#B7CCE9", width=11)
    d.line((190, 670, 850, 520), fill=BLUE, width=16)
    d.ellipse((180, 635, 220, 675), fill=GREEN, outline=WHITE, width=5)
    d.ellipse((820, 485, 860, 525), fill=AMBER, outline=WHITE, width=5)
    rounded(d, (185, 755, 895, 835), 18, AMBER_LIGHT)
    d.text((215, 778), "လမ်းကြောင်းအကျဉ်းချုပ်  •  1 transfer", font=font(23, bold=True), fill=AMBER)
    for i, (route, from_to, color) in enumerate([("117", "စတင်မှတ်တိုင် → ပြောင်းစီးရန်", GREEN), ("36", "ပြောင်းစီးရန် → ဆင်းမည့်မှတ်တိုင်", BLUE)]):
        y = 900 + i * 210
        rounded(d, (150, y, 930, y + 170), 24, WHITE, "#E2E8F0", 2)
        rounded(d, (185, y + 30, 300, y + 95), 16, color)
        centered(d, (242, y + 62), f"YBS {route}", font(20, bold=True, english=True), WHITE)
        d.text((335, y + 28), from_to, font=font(22, bold=True), fill=NAVY)
        d.text((335, y + 88), "လမ်းလျှောက်အကွာအဝေးနှင့် မှတ်တိုင်များ", font=font(19), fill=SLATE_500)


def draw_offline_content(d):
    rounded(d, (150, 480, 930, 675), 24, GREEN)
    d.text((190, 520), "Offline route data", font=font(31, bold=True, english=True), fill=WHITE)
    d.text((190, 580), "အင်တာနက်မရှိချိန်တွင်လည်း လမ်းကြောင်းရှာနိုင်ပါသည်", font=font(21), fill=WHITE)
    rounded(d, (150, 735, 930, 910), 24, AMBER_LIGHT)
    d.text((190, 778), "ရောက်ခါနီး သတိပေးချက်", font=font(27, bold=True), fill=AMBER)
    d.text((190, 835), "လိုအပ်ချိန်တွင်သာ ဖွင့်ပြီး GPS ဖြင့်အသုံးပြုပါ", font=font(20), fill=SLATE_700)
    for i, txt in enumerate(["မှတ်တိုင် data ကို local တွင်သိမ်းထားသည်", "Live ETA မရလျှင် retry လုပ်နိုင်သည်", "Battery-safe opt-in alert"]):
        y = 1000 + i * 125
        d.ellipse((185, y + 8, 225, y + 48), fill=AMBER)
        centered(d, (205, y + 28), "✓", font(22, bold=True, english=True), WHITE)
        d.text((255, y), txt, font=font(23), fill=NAVY)


def add_bottom_note(d):
    rounded(d, (150, 1580, 930, 1740), 24, SLATE_100)
    centered(d, (540, 1630), "ရန်ကုန်သွားလာရေးအတွက် ရိုးရှင်းသောအကူအညီ", font(25, bold=True), NAVY)
    centered(d, (540, 1688), "YBS AI · Yangon YBS Guide", font(19, english=True), SLATE_500)


def make_mockup(filename: str, title: str, subtitle: str, content_fn):
    img = Image.new("RGB", (1080, 1920), NAVY)
    d = ImageDraw.Draw(img)
    add_phone_base(d, title, subtitle)
    content_fn(d)
    add_bottom_note(d)
    img.save(OUT / filename, quality=95, optimize=True)


def make_feature_graphic():
    img = Image.new("RGB", (1024, 500), NAVY)
    d = ImageDraw.Draw(img)
    d.ellipse((650, -180, 1120, 300), fill="#24324E")
    d.ellipse((-190, 260, 300, 650), fill="#17233A")
    # route lines
    for points in [((40, 90), (360, 225), (230, 455)), ((430, 30), (540, 250), (920, 90)), ((560, 430), (720, 250), (960, 400))]:
        d.line(points, fill="#334E76", width=13, joint="curve")
    for x, y, color in [(65, 96, GREEN), (355, 220, AMBER), (230, 450, BLUE), (915, 92, GREEN), (955, 400, AMBER)]:
        d.ellipse((x - 16, y - 16, x + 16, y + 16), fill=color, outline=WHITE, width=4)
    rounded(d, (62, 110, 250, 298), 36, AMBER)
    icon = bus_icon(188, bus=WHITE)
    img.paste(icon, (62, 110), icon)
    d.text((300, 100), "YBS AI", font=font(78, bold=True, english=True), fill=WHITE)
    d.text((305, 215), "ရန်ကုန် YBS လမ်းကြောင်းအကူအညီ", font=font(33, bold=True), fill=AMBER_LIGHT)
    d.text((305, 285), "Route search · Assistant · Offline guide", font=font(25, english=True), fill="#CBD5E1")
    rounded(d, (305, 350, 710, 420), 18, "#1E293B")
    d.text((340, 370), "မြန်မာလို ရှာဖွေပြီး လွယ်ကူစွာသွားပါ", font=font(22), fill=WHITE)
    img.save(OUT / "feature_graphic_1024x500.png", quality=95, optimize=True)


def make_icon():
    img = Image.new("RGB", (512, 512), NAVY)
    d = ImageDraw.Draw(img)
    d.ellipse((40, 40, 472, 472), fill="#17233A")
    rounded(d, (116, 102, 396, 374), 44, WHITE)
    d.rectangle((150, 145, 362, 235), fill=NAVY)
    d.line((148, 280, 364, 280), fill=NAVY, width=10)
    d.ellipse((150, 320, 202, 372), fill=NAVY)
    d.ellipse((310, 320, 362, 372), fill=NAVY)
    d.rectangle((170, 118, 204, 148), fill=AMBER)
    d.rectangle((308, 118, 342, 148), fill=AMBER)
    img.save(OUT / "app_icon_512x512.png", quality=95, optimize=True)


def main():
    make_icon()
    make_feature_graphic()
    make_mockup("01_find_route_1080x1920.png", "လမ်းကြောင်းကို အလွယ်တကူရှာပါ", "Find your YBS route", draw_home_content)
    make_mockup("02_route_directory_1080x1920.png", "ကားလိုင်းများကို လျင်မြန်စွာကြည့်ပါ", "Browse routes and stops", draw_route_content)
    make_mockup("03_burmese_assistant_1080x1920.png", "မြန်မာလို မေးပြီး လမ်းကြောင်းရှာပါ", "Ask the YBS Assistant", draw_assistant_content)
    make_mockup("04_trip_plan_1080x1920.png", "ပြောင်းစီးမှုကို ရှင်းလင်းစွာသိပါ", "Plan your trip with confidence", draw_plan_content)
    make_mockup("05_offline_alerts_1080x1920.png", "Offline data နှင့် သတိပေးချက်", "Useful when you need it", draw_offline_content)


if __name__ == "__main__":
    main()
