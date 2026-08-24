"""Generates Crux's launcher icons from the design tokens.

Run:  python tool/generate_icons.py

Produces, from one vector-ish definition so every size stays crisp:
  * legacy square icons        android/app/src/main/res/mipmap-*/ic_launcher.png
  * adaptive foreground        android/app/src/main/res/drawable-*/ic_launcher_foreground.png
  * themed (monochrome) icon   android/app/src/main/res/drawable-*/ic_launcher_monochrome.png
  * Play Store listing icon    store/play/icon-512.png
  * feature graphic            store/play/feature-graphic-1024x500.png

Design intent: the launcher grid is a crowded, tiny place — so the icon is the
brand's ember gradient (the CTA/PR colour) carrying one unmistakable gym mark:
a barbell, drawn in the dark "on-ember" ink. Reads at 48px, and doesn't fall
back on the near-black canvas colour that would go muddy next to other icons.
"""

from PIL import Image, ImageDraw
import os

# --- Design tokens (mirrors lib/core/theme/tokens.dart) ---------------------
EMBER = (255, 92, 57)          # #FF5C39
EMBER_BRIGHT = (255, 122, 92)  # #FF7A5C
ON_EMBER = (27, 14, 9)         # #1B0E09 — dark ink used on ember surfaces
CANVAS = (18, 17, 20)          # #121114
WHITE = (255, 255, 255)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
STORE = os.path.join(ROOT, "store", "play")

# Supersample everything then downscale — cheap anti-aliasing.
SS = 4


def ember_gradient(size):
    """Diagonal ember gradient, bright top-left → deep bottom-right."""
    grad = Image.new("RGB", (size, size))
    px = grad.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size - 2)
            px[x, y] = (
                round(EMBER_BRIGHT[0] + (EMBER[0] - EMBER_BRIGHT[0]) * t),
                round(EMBER_BRIGHT[1] + (EMBER[1] - EMBER_BRIGHT[1]) * t),
                round(EMBER_BRIGHT[2] + (EMBER[2] - EMBER_BRIGHT[2]) * t),
            )
    return grad


def draw_barbell(draw, cx, cy, span, ink):
    """A centred barbell: bar + inner plates + outer plates.

    `span` is the full width of the mark. Proportions are tuned so the shape
    still resolves into "barbell" at 48px rather than turning into a smudge.
    """
    bar_h = span * 0.105
    bar_w = span * 0.62
    r_bar = bar_h / 2
    draw.rounded_rectangle(
        [cx - bar_w / 2, cy - bar_h / 2, cx + bar_w / 2, cy + bar_h / 2],
        radius=r_bar, fill=ink,
    )

    # Inner (tall) plates
    ip_w, ip_h = span * 0.135, span * 0.56
    for sign in (-1, 1):
        x = cx + sign * (bar_w / 2 - ip_w * 0.15) - ip_w / 2
        draw.rounded_rectangle(
            [x, cy - ip_h / 2, x + ip_w, cy + ip_h / 2],
            radius=ip_w * 0.32, fill=ink,
        )

    # Outer (short) plates
    op_w, op_h = span * 0.105, span * 0.335
    for sign in (-1, 1):
        x = cx + sign * (span / 2 - op_w / 2) - op_w / 2
        draw.rounded_rectangle(
            [x, cy - op_h / 2, x + op_w, cy + op_h / 2],
            radius=op_w * 0.34, fill=ink,
        )


def make_legacy_icon(size):
    """Full square icon with rounded corners (pre-Android-8 launchers)."""
    s = size * SS
    grad = ember_gradient(s)

    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1],
                                           radius=int(s * 0.22), fill=255)

    icon = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    icon.paste(grad, (0, 0), mask)

    draw_barbell(ImageDraw.Draw(icon), s / 2, s / 2, s * 0.68, ON_EMBER)
    return icon.resize((size, size), Image.LANCZOS)


def make_adaptive_foreground(size):
    """Adaptive foreground: mark only, inside the 66% safe zone."""
    s = size * SS
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    # Adaptive icons are 108dp with a 72dp visible area — keep the mark well
    # inside so no launcher shape (circle/squircle) can clip a plate.
    draw_barbell(ImageDraw.Draw(layer), s / 2, s / 2, s * 0.46, ON_EMBER)
    return layer.resize((size, size), Image.LANCZOS)


def make_monochrome(size):
    """Themed-icon layer (Android 13+): single-colour silhouette."""
    s = size * SS
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw_barbell(ImageDraw.Draw(layer), s / 2, s / 2, s * 0.46,
                 (0, 0, 0, 255))
    return layer.resize((size, size), Image.LANCZOS)


def make_splash_mark(size):
    """Splash logo: ember barbell on transparency.

    Ember reads cleanly on BOTH theme canvases (#F6F4F1 light, #121114 dark),
    so one asset covers day and night without a white flash before the app's
    dark UI appears.
    """
    s = size * SS
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw_barbell(ImageDraw.Draw(layer), s / 2, s / 2, s * 0.9, EMBER)
    return layer.resize((size, size), Image.LANCZOS)


def make_play_icon():
    """512x512 Play listing icon — square, no transparency, no rounding."""
    s = 512 * 2
    icon = Image.new("RGB", (s, s))
    icon.paste(ember_gradient(s), (0, 0))
    draw_barbell(ImageDraw.Draw(icon), s / 2, s / 2, s * 0.68, ON_EMBER)
    return icon.resize((512, 512), Image.LANCZOS)


def make_feature_graphic():
    """1024x500 feature graphic: dark canvas, ember mark, room for overlay."""
    w, h = 1024 * 2, 500 * 2
    img = Image.new("RGB", (w, h), CANVAS)
    d = ImageDraw.Draw(img)

    # Soft ember glow behind the mark (concentric translucent discs).
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(28, 0, -1):
        r = h * 0.16 + i * h * 0.020
        gd.ellipse([w * 0.24 - r, h / 2 - r, w * 0.24 + r, h / 2 + r],
                   fill=(*EMBER, 4))
    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
    d = ImageDraw.Draw(img)

    draw_barbell(d, w * 0.24, h / 2, h * 0.52, EMBER)
    return img.resize((1024, 500), Image.LANCZOS)


# --- Emit -------------------------------------------------------------------
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# Adaptive layers are 108dp at each density.
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324,
            "xxxhdpi": 432}


def main():
    for density, size in LEGACY.items():
        out = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(out, exist_ok=True)
        icon = make_legacy_icon(size)
        icon.save(os.path.join(out, "ic_launcher.png"))
        icon.save(os.path.join(out, "ic_launcher_round.png"))
        print(f"  mipmap-{density}/ic_launcher.png  {size}x{size}")

    for density, size in ADAPTIVE.items():
        out = os.path.join(RES, f"drawable-{density}")
        os.makedirs(out, exist_ok=True)
        make_adaptive_foreground(size).save(
            os.path.join(out, "ic_launcher_foreground.png"))
        make_monochrome(size).save(
            os.path.join(out, "ic_launcher_monochrome.png"))
        print(f"  drawable-{density}/ic_launcher_foreground.png  {size}x{size}")

    # Splash mark — 160dp-ish across densities.
    for density, size in {"mdpi": 160, "hdpi": 240, "xhdpi": 320,
                          "xxhdpi": 480, "xxxhdpi": 640}.items():
        out = os.path.join(RES, f"drawable-{density}")
        os.makedirs(out, exist_ok=True)
        make_splash_mark(size).save(os.path.join(out, "splash_mark.png"))
        print(f"  drawable-{density}/splash_mark.png  {size}x{size}")

    os.makedirs(STORE, exist_ok=True)
    make_play_icon().save(os.path.join(STORE, "icon-512.png"))
    make_feature_graphic().save(
        os.path.join(STORE, "feature-graphic-1024x500.png"))
    print("  store/play/icon-512.png  512x512")
    print("  store/play/feature-graphic-1024x500.png  1024x500")


if __name__ == "__main__":
    print("Generating Crux icons...")
    main()
    print("Done.")
