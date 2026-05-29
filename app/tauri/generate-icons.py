#!/usr/bin/env python3
"""Generate placeholder icons for the Tauri build (pure stdlib, no Pillow).

Writes RGBA PNGs at 32x32, 128x128, 128x128@2x (256x256), 256x256, 512x512,
and the wildcard icon.png + icon.ico/icon.icns stubs that bundler expects.

Replace with proper artwork later by overwriting these files.
"""
from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

# Ubuntu_Aktualizacje brand: deep indigo background, light accent square,
# small bright accent dot in lower-right. All hand-coded so we don't need
# Pillow / imagemagick.

BG       = (0x12, 0x18, 0x2c, 0xff)   # near-black indigo
ACCENT_1 = (0x7a, 0xa6, 0xff, 0xff)   # blue
ACCENT_2 = (0x34, 0xc2, 0x70, 0xff)   # green (status dot)


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, size: int) -> None:
    """Render the official Ascendo 'A' logo with smooth anti-aliasing."""
    s = size
    margin = 2.0 / 64.0 * s
    R = 14.0 / 64.0 * s
    stroke_width = 6.0 / 64.0 * s
    half_stroke = stroke_width / 2.0

    # Key points for the A shape (M16 44 L32 22 L48 44)
    ax, ay = 16.0 / 64.0 * s, 44.0 / 64.0 * s
    bx, by = 32.0 / 64.0 * s, 22.0 / 64.0 * s
    cx, cy = 48.0 / 64.0 * s, 44.0 / 64.0 * s

    # Corner centers
    c1x, c1y = margin + R, margin + R
    c2x, c2y = s - margin - R, margin + R
    c3x, c3y = margin + R, s - margin - R
    c4x, c4y = s - margin - R, s - margin - R

    def get_pixel(x: float, y: float) -> tuple[int, int, int, int]:
        # 1. Background linear gradient from green (#22c55e) to blue (#0ea5e9)
        # Gradient direction: top-left to bottom-right
        t = (x + y) / (2.0 * (s - 1)) if s > 1 else 0.5
        t = max(0.0, min(1.0, t))
        
        bg_r = int((1.0 - t) * 0x22 + t * 0x0e)
        bg_g = int((1.0 - t) * 0xc5 + t * 0xa5)
        bg_b = int((1.0 - t) * 0x5e + t * 0xe9)
        bg_a = 0xff

        # 2. Rounded rect mask with anti-aliasing
        # Distance to edges
        dist_edge = min(x - margin, (s - margin) - x, y - margin, (s - margin) - y)
        rect_coverage = max(0.0, min(1.0, dist_edge + 0.5))

        # Check corners
        if x < c1x and y < c1y:
            d = ((x - c1x)**2 + (y - c1y)**2)**0.5
            rect_coverage = max(0.0, min(1.0, R + 0.5 - d))
        elif x > c2x and y < c2y:
            d = ((x - c2x)**2 + (y - c2y)**2)**0.5
            rect_coverage = max(0.0, min(1.0, R + 0.5 - d))
        elif x < c3x and y > c3y:
            d = ((x - c3x)**2 + (y - c3y)**2)**0.5
            rect_coverage = max(0.0, min(1.0, R + 0.5 - d))
        elif x > c4x and y > c4y:
            d = ((x - c4x)**2 + (y - c4y)**2)**0.5
            rect_coverage = max(0.0, min(1.0, R + 0.5 - d))

        # If completely outside the rounded rect, return transparent
        if rect_coverage <= 0.0:
            return (0, 0, 0, 0)

        # 3. Stroke coverage (A path: A-B and B-C)
        def dist_to_seg(px: float, py: float, lx1: float, ly1: float, lx2: float, ly2: float) -> float:
            vx, vy = lx2 - lx1, ly2 - ly1
            wx, wy = px - lx1, py - ly1
            v2 = vx * vx + vy * vy
            if v2 == 0.0:
                return (wx * wx + wy * wy)**0.5
            proj = (wx * vx + wy * wy) / v2
            proj = max(0.0, min(1.0, proj))
            cx, cy = lx1 + proj * vx, ly1 + proj * vy
            return ((px - cx)**2 + (py - cy)**2)**0.5

        d1 = dist_to_seg(x, y, ax, ay, bx, by)
        d2 = dist_to_seg(x, y, bx, by, cx, cy)
        d_stroke = min(d1, d2)
        
        stroke_coverage = max(0.0, min(1.0, half_stroke + 0.5 - d_stroke))

        # Blend stroke (white) over gradient background
        r = int((1.0 - stroke_coverage) * bg_r + stroke_coverage * 0xff)
        g = int((1.0 - stroke_coverage) * bg_g + stroke_coverage * 0xff)
        b = int((1.0 - stroke_coverage) * bg_b + stroke_coverage * 0xff)
        a = int(rect_coverage * 0xff)

        return (r, g, b, a)

    rows: list[bytes] = []
    for y in range(s):
        row = bytearray()
        row.append(0)  # PNG filter byte: None
        for x in range(s):
            r, g, b, a = get_pixel(x + 0.5, y + 0.5)
            row.extend([r, g, b, a])
        rows.append(bytes(row))

    raw = b"".join(rows)
    compressed = zlib.compress(raw, 9)

    ihdr = struct.pack(">IIBBBBB", s, s, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", ihdr)
        + _png_chunk(b"IDAT", compressed)
        + _png_chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main(argv: list[str]) -> int:
    here = Path(__file__).resolve().parent
    icons_dir = here / "src-tauri" / "icons"
    icons_dir.mkdir(parents=True, exist_ok=True)

    sizes = {
        "32x32.png":      32,
        "128x128.png":    128,
        "128x128@2x.png": 256,
        "icon.png":       256,
        # Tauri bundler may also probe these names
        "icon-256.png":   256,
        "icon-512.png":   512,
    }
    for name, size in sizes.items():
        target = icons_dir / name
        if "--force" not in argv and target.exists() and target.stat().st_size > 0:
            print(f"  keep {name}")
            continue
        write_png(target, size)
        print(f"  wrote {name} ({size}x{size}, {target.stat().st_size} B)")

    # Linux-only build (deb + appimage) doesn't need icon.icns / icon.ico,
    # and zero-byte stubs make the Tauri bundler choke. Remove if present.
    for name in ("icon.icns", "icon.ico"):
        target = icons_dir / name
        if target.exists():
            target.unlink()
            print(f"  removed stale {name}")

    print(f"\n✔ icons in {icons_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
