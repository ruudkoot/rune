#!/usr/bin/env python3
"""The contrast of the palette's colours (docs/diagnostics.md).

Reads the roles' styles from Color.table and Color.wide in
src/util/color.sml and, for each theme, renders every role that has a colour
in the default palettes of five terminals (VS Code's two, of its dark and of
its light themes), on the backgrounds that theme is for (bold drawn bright
where the terminal does that by default) -- wide, auto on a terminal of 256
colours, on dark and light alike, its colours of the 256 the same in every
terminal; then the same seen with protanopia, deuteranopia and tritanopia
(the matrices of Machado, Oliveira and Fernandes 2009, severity 1.0). Each
contrast ratio (WCAG 2.2) must be at least MIN_RATIO, and MIN_RATIO_CVD under
a deficiency; it prints the lowest and fails if one is not.

  python3 tests/color/contrast.py [--verbose]
"""
import re
import sys

# WCAG 2.2's ratio for large or bold text and for parts of an interface
# (1.4.3, 1.4.11): the coloured roles carry a word or a mark besides
# (docs/diagnostics.md), so colour is not what tells them apart.
MIN_RATIO = 3.0
# Under a deficiency of colour vision: no colour of the 16 reaches 3:1 on
# dark and on light backgrounds in all the palettes for all three
# deficiencies; bright red and magenta come closest (2.7 and 2.6), and the
# theme auto keeps to them. The themes dark and light reach 3:1 in most
# roles; this is the floor for all.
MIN_RATIO_CVD = 2.5

# What D24's gate measured and could not meet, with its reason
# (docs/plans/repl.md, M13): VS Code's light theme draws bold in bright
# colours, and its bright magenta, d670d6, is 2.94:1 on white -- no magenta
# of it reaches 3:1 bold, and red is the errors'. The roles in it keep their
# bold and their words (`warning:`, `Interrupt`, a string's quotes), and
# what would fix it is the terminal's background asked (OSC 11) and a theme
# chosen for it, which is under *Ready for, not built*. A ratio of this
# palette and colour at least the figure here passes; every other is held to
# the rule.
KNOWN = {("vscode-light", "d670d6"): 2.9}

# the colours 30-37 then 90-97 of each terminal, and its backgrounds
PALETTES = {
    "xterm": ("000000 cd0000 00cd00 cdcd00 0000ee cd00cd 00cdcd e5e5e5 "
              "7f7f7f ff0000 00ff00 ffff00 5c5cff ff00ff 00ffff ffffff",
              {"dark": "000000", "light": "ffffff"}),
    "vte-gnome": ("171421 c01c28 26a269 a2734c 12488b a347ba 2aa1b3 d0cfcc "
                  "5e5c64 f66151 33da7a e9ad0c 2a7bde c061cb 33c7de ffffff",
                  {"dark": "171421", "light": "ffffff"}),
    "windows-terminal-campbell": ("0c0c0c c50f1f 13a10e c19c00 0037da 881798 3a96dd cccccc "
                                  "767676 e74856 16c60c f9f1a5 3b78ff b4009e 61d6d6 f2f2f2",
                                  {"dark": "0c0c0c", "light": "ffffff"}),
    "legacy-console": ("000000 800000 008000 808000 000080 800080 008080 c0c0c0 "
                       "808080 ff0000 00ff00 ffff00 0000ff ff00ff 00ffff ffffff",
                       {"dark": "000000"}),
    # VS Code's terminal (ansiColorMap of terminalColorRegistry.ts), a palette
    # of each kind of theme, on the background of Dark+ and of Light+
    "vscode-dark": ("000000 cd3131 0dbc79 e5e510 2472c8 bc3fbc 11a8cd e5e5e5 "
                    "666666 f14c4c 23d18b f5f543 3b8eea d670d6 29b8db e5e5e5",
                    {"dark": "1e1e1e"}),
    "vscode-light": ("000000 cd3131 107c10 949800 0451a5 bc05bc 0598bc 555555 "
                     "666666 f14c4c 14ce14 b5ba00 3b8eea d670d6 29b8db a5a5a5",
                     {"light": "ffffff"}),
}

# whether bold draws the colours 30-37 as 90-97 by default: xterm's
# boldColors is true, VTE's bold-is-bright false (since 0.52), Windows
# Terminal's intenseTextStyle "bright", and the console's SGR 1 sets the
# foreground's intensity
BOLD_IS_BRIGHT = {"xterm": True, "vte-gnome": False, "windows-terminal-campbell": True,
                  "legacy-console": True, "vscode-dark": True, "vscode-light": True}

# Machado, Oliveira and Fernandes 2009, severity 1.0, on linear RGB
CVD = {
    "normal": None,
    "protanopia": ((0.152286, 1.052583, -0.204868), (0.114503, 0.786281, 0.099216),
                   (-0.003882, -0.048116, 1.051998)),
    "deuteranopia": ((0.367322, 0.860646, -0.227968), (0.280085, 0.672501, 0.047413),
                     (-0.011820, 0.042940, 0.968881)),
    "tritanopia": ((1.255528, -0.076749, -0.178779), (-0.078411, 0.930809, 0.147602),
                   (0.004733, 0.691367, 0.303900)),
}

# which backgrounds each theme is for
THEMES = {"auto": ("dark", "light"), "wide": ("dark", "light"), "dark": ("dark",), "light": ("light",)}


def table(path):
    """Each role and its style in each theme: Color.table's, and wide's where
    Color.wide has the role, else auto's"""
    text = open(path, encoding="utf-8").read()
    body = text[text.index("val table"):text.index("val roles")]
    rows = re.findall(r'\("([^"]+)", "([^"]*)", "([^"]*)", "([^"]*)"\)', body)
    if len(rows) < 20:
        sys.exit("contrast.py: could not read Color.table from " + path)
    start = text.index("val wide")
    wide = dict(re.findall(r'\("([^"]+)", "([^"]*)"\)', text[start:text.index("]", start)]))
    if len(wide) < 5:
        sys.exit("contrast.py: could not read Color.wide from " + path)
    return [(r, {"auto": a, "wide": wide.get(r, a), "dark": d, "light": l}) for r, a, d, l in rows]


def colour256(n, colours):
    """Colour n of the 256: the terminal's own 16, then the cube and the greys,
    which are the same in every terminal"""
    if n < 16:
        return colours[n]
    if n < 232:
        levels = [0, 95, 135, 175, 215, 255]
        n -= 16
        return "%02x%02x%02x" % (levels[n // 36], levels[n // 6 % 6], levels[n % 6])
    v = 8 + 10 * (n - 232)
    return "%02x%02x%02x" % (v, v, v)


def linear(hexcolour):
    out = []
    for i in (0, 2, 4):
        c = int(hexcolour[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return out


def seen(rgb, matrix):
    if matrix is None:
        return rgb
    return [min(1.0, max(0.0, sum(m * c for m, c in zip(row, rgb)))) for row in matrix]


def luminance(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def ratio(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def colour_of(style, colours, bold_is_bright):
    """The foreground a style gives in a palette, or None for the default."""
    found = None
    ps = [int(p) for p in style.split(";")] if style else []
    for i, p in enumerate(ps):
        if p == 38 and ps[i + 1:i + 2] == [5]:
            return colour256(ps[i + 2], colours)
    bold = 1 in ps
    for p in ps:
        if 30 <= p <= 37:
            found = colours[p - 30 + (8 if bold and bold_is_bright else 0)]
        elif 90 <= p <= 97:
            found = colours[p - 82]
    return found


def main():
    verbose = "--verbose" in sys.argv
    roles = table("src/util/color.sml")
    worst = []
    failures = 0
    for theme, kinds in THEMES.items():
        for name, (colours, backgrounds) in PALETTES.items():
            colours = colours.split()
            for kind in kinds:
                if kind not in backgrounds:
                    continue
                bg = backgrounds[kind]
                for role, styles in roles:
                    fg = colour_of(styles[theme], colours, BOLD_IS_BRIGHT[name])
                    if fg is None:
                        continue
                    for vision, matrix in CVD.items():
                        r = ratio(seen(linear(fg), matrix), seen(linear(bg), matrix))
                        line = "%-6s %-26s %-5s %-20s %-12s %5.2f" % (theme, name, kind, role, vision, r)
                        worst.append((r, line))
                        floor = MIN_RATIO if matrix is None else MIN_RATIO_CVD
                        floor = min(floor, KNOWN.get((name, fg), floor))
                        if r < floor:
                            failures += 1
                            print("FAIL " + line)
                        elif verbose:
                            print("     " + line)
    worst.sort()
    print("the lowest ratios:")
    for r, line in worst[:5]:
        print("  " + line)
    print("%s colour: %d of %d ratios below %.1f (%.1f with a deficiency)" %
          ("FAIL" if failures else "PASS", failures, len(worst), MIN_RATIO, MIN_RATIO_CVD))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
