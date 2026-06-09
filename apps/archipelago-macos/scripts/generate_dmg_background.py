#!/usr/bin/env python3
"""Generate the DMG installer background image for Archipelago."""

import os
import random

from PIL import Image, ImageDraw, ImageFont

W, H = 1320, 800

BG_TOP = (18, 22, 30)
BG_BOTTOM = (4, 7, 12)
PANEL = (28, 34, 46)
PANEL_DARK = (9, 13, 22)
TEXT_COLOR = (236, 242, 248)
TEXT_DIM = (133, 146, 160)
TEXT_MUTED = (82, 97, 112)
ACCENT = (36, 155, 255)
ACCENT_SOFT = (75, 190, 255)
BLUE_DEEP = (0, 93, 210)

APP_ICON_CENTER = (360, 430)
APPS_ICON_CENTER = (960, 430)

ARROW_Y = 430
ARROW_LEFT = 480
ARROW_RIGHT = 840


def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_gradient(draw, w, h, c1, c2):
    for y in range(h):
        draw.line([(0, y), (w, y)], fill=lerp_color(c1, c2, y / h))


def draw_radial_glow(img, center, radius, color, max_alpha):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    glow = ImageDraw.Draw(overlay)
    cx, cy = center
    steps = 72
    for step in range(steps, 0, -1):
        t = step / steps
        alpha = int(max_alpha * (1 - t) ** 2)
        r = int(radius * t)
        glow.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*color, alpha))
    img.alpha_composite(overlay)


def draw_subtle_grid(draw, w, h):
    color = (255, 255, 255, 4)
    for x in range(0, w, 80):
        draw.line([(x, 0), (x, h)], fill=color, width=1)
    for y in range(0, h, 80):
        draw.line([(0, y), (w, y)], fill=color, width=1)


def draw_corner_brackets(draw, w, h):
    length = 54
    thickness = 3
    margin = 56
    color = (*ACCENT_SOFT, 70)
    segments = [
        ((margin, margin), (margin + length, margin)),
        ((margin, margin), (margin, margin + length)),
        ((w - margin, margin), (w - margin - length, margin)),
        ((w - margin, margin), (w - margin, margin + length)),
        ((margin, h - margin), (margin + length, h - margin)),
        ((margin, h - margin), (margin, h - margin - length)),
        ((w - margin, h - margin), (w - margin - length, h - margin)),
        ((w - margin, h - margin), (w - margin, h - margin - length)),
    ]
    for p1, p2 in segments:
        draw.line([p1, p2], fill=color, width=thickness)


def load_font(size, bold=False, mono=False):
    names = []
    if mono:
        names.extend([
            "/System/Library/Fonts/SFNSMono.ttf",
            "/System/Library/Fonts/Menlo.ttc",
            "/System/Library/Fonts/Monaco.dfont",
        ])
    if bold:
        names.extend([
            "/System/Library/Fonts/SFNSDisplay-Bold.otf",
            "/System/Library/Fonts/Supplemental/Avenir Next.ttc",
            "/System/Library/Fonts/Helvetica.ttc",
        ])
    names.extend([
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ])
    for name in names:
        if os.path.exists(name):
            try:
                return ImageFont.truetype(name, size)
            except Exception:
                continue
    return ImageFont.load_default()


def draw_centered_text(draw, text, center_x, y, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text((center_x - tw // 2, y), text, fill=fill, font=font)


def draw_wordmark(draw, center_x, top_y):
    title_font = load_font(66, bold=True)
    subtitle_font = load_font(24)
    draw_centered_text(draw, "ARCHIPELAGO", center_x, top_y, title_font, TEXT_COLOR)
    draw_centered_text(
        draw,
        "multi-agent coding island",
        center_x,
        top_y + 78,
        subtitle_font,
        (*TEXT_DIM, 210),
    )


def draw_island_hub(draw, center_x, center_y):
    for inset, alpha in [(34, 20), (22, 30), (12, 38)]:
        draw.rounded_rectangle(
            [
                center_x - 260 - inset,
                center_y - 48 - inset // 3,
                center_x + 260 + inset,
                center_y + 48 + inset // 3,
            ],
            radius=64 + inset // 2,
            outline=(*ACCENT, alpha),
            width=2,
        )
    draw.rounded_rectangle(
        [center_x - 250, center_y - 46, center_x + 250, center_y + 46],
        radius=54,
        fill=(*PANEL, 230),
        outline=(140, 155, 172, 120),
        width=2,
    )
    draw.rounded_rectangle(
        [center_x - 180, center_y - 26, center_x + 180, center_y + 26],
        radius=34,
        fill=(*PANEL_DARK, 255),
        outline=(68, 90, 115, 110),
        width=1,
    )
    draw.ellipse(
        [center_x + 128, center_y - 12, center_x + 152, center_y + 12],
        fill=(*ACCENT_SOFT, 255),
        outline=(170, 230, 255, 210),
        width=2,
    )


def draw_connection(draw, points, width=4, alpha=130):
    for glow_w, glow_alpha in [(12, 18), (7, 30)]:
        draw.line(points, fill=(*ACCENT, glow_alpha), width=glow_w, joint="curve")
    for i in range(len(points) - 1):
        x1, y1 = points[i]
        x2, y2 = points[i + 1]
        length = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
        steps = max(1, int(length // 18))
        for step in range(steps + 1):
            t = step / steps
            x = x1 + (x2 - x1) * t
            y = y1 + (y2 - y1) * t
            draw.ellipse([x - width, y - width, x + width, y + width], fill=(*ACCENT_SOFT, alpha))


def draw_node(draw, x, y, r, label):
    draw.ellipse([x - r - 18, y - r - 18, x + r + 18, y + r + 18], fill=(*ACCENT, 18))
    draw.ellipse(
        [x - r, y - r, x + r, y + r],
        fill=(17, 24, 36, 235),
        outline=(120, 138, 160, 120),
        width=2,
    )
    draw.ellipse([x - r // 2, y - r // 2, x + r // 2, y + r // 2], fill=(*ACCENT, 255))
    draw_centered_text(draw, label, x, y + r + 12, load_font(18, mono=True), (*TEXT_MUTED, 180))


def draw_agent_archipelago(draw):
    hub = (W // 2, 245)
    nodes = [
        (APP_ICON_CENTER[0] - 120, APP_ICON_CENTER[1] + 150, "Claude"),
        (W // 2, APP_ICON_CENTER[1] + 175, "Codex"),
        (APPS_ICON_CENTER[0] + 120, APPS_ICON_CENTER[1] + 150, "OpenCode"),
    ]
    anchors = [
        (hub[0] - 155, hub[1] + 50),
        (hub[0], hub[1] + 52),
        (hub[0] + 155, hub[1] + 50),
    ]
    for anchor, node in zip(anchors, nodes):
        nx, ny, _ = node
        mid_y = (anchor[1] + ny) // 2
        draw_connection(draw, [anchor, (nx, mid_y), (nx, ny - 38)])
    for nx, ny, label in nodes:
        draw_node(draw, nx, ny, 38, label)


def draw_noise(draw, w, h):
    rng = random.Random(23)
    for _ in range(350):
        x = rng.randrange(w)
        y = rng.randrange(h)
        alpha = rng.randrange(3, 9)
        draw.point((x, y), fill=(255, 255, 255, alpha))


def draw_dashed_arrow(draw, y, x1, x2):
    dash_len = 20
    gap_len = 14
    thickness = 3
    color = (*TEXT_DIM, 185)
    x = x1
    while x < x2 - 26:
        end = min(x + dash_len, x2 - 26)
        draw.rounded_rectangle([x, y - thickness // 2, end, y + thickness // 2], radius=2, fill=color)
        x = end + gap_len
    arrow_size = 15
    draw.polygon(
        [(x2, y), (x2 - arrow_size, y - arrow_size), (x2 - arrow_size, y + arrow_size)],
        fill=color,
    )
    label = "drag to install"
    font = load_font(24, mono=True)
    bbox = draw.textbbox((0, 0), label, font=font)
    lw = bbox[2] - bbox[0]
    draw.text(((x1 + x2) // 2 - lw // 2, y + 18), label, fill=(*TEXT_DIM, 205), font=font)


def draw_bottom_bar(draw, w, h):
    bar_h = 52
    bar_y = h - bar_h
    draw.rectangle([0, bar_y, w, h], fill=(8, 11, 17, 235))
    draw.line([(0, bar_y), (w, bar_y)], fill=(*ACCENT_SOFT, 45), width=1)
    tagline = "Archipelago.app    group chats for coding agents"
    font = load_font(22, mono=True)
    bbox = draw.textbbox((0, 0), tagline, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(((w - tw) // 2, bar_y + 15), tagline, fill=(*TEXT_DIM, 190), font=font)


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output_path = os.path.join(repo_root, "Assets", "Brand", "dmg-background.png")
    retina_path = os.path.join(repo_root, "Assets", "Brand", "dmg-background@2x.png")

    img = Image.new("RGBA", (W, H))
    draw = ImageDraw.Draw(img)
    draw_gradient(draw, W, H, BG_TOP, BG_BOTTOM)
    draw_radial_glow(img, (W // 2, 190), 520, ACCENT, 90)
    draw_radial_glow(img, APP_ICON_CENTER, 260, BLUE_DEEP, 65)
    draw_radial_glow(img, APPS_ICON_CENTER, 260, ACCENT, 55)
    draw = ImageDraw.Draw(img)
    draw_subtle_grid(draw, W, H)
    draw_corner_brackets(draw, W, H)
    draw_wordmark(draw, W // 2, 62)
    draw_island_hub(draw, W // 2, 245)
    draw_agent_archipelago(draw)
    draw_dashed_arrow(draw, ARROW_Y, ARROW_LEFT, ARROW_RIGHT)
    draw_noise(draw, W, H)
    draw_bottom_bar(draw, W, H)

    opaque = Image.new("RGBA", (W, H), (*BG_BOTTOM, 255))
    opaque.alpha_composite(img)
    img = opaque

    img.save(retina_path, "PNG")
    img.resize((W // 2, H // 2), Image.LANCZOS).save(output_path, "PNG")
    print(f"DMG background: {output_path}")
    print(f"DMG background @2x: {retina_path}")


if __name__ == "__main__":
    main()
