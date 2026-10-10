#!/usr/bin/env python3
"""Standalone wallpaper glow mask generator.

Inspired by the glow pipeline in satoshoe-dev/dms-audiofx. This standalone
version deliberately has no DankMaterialShell dependency.

Dependencies: numpy, Pillow.
"""
import argparse, hashlib, json, os
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

VERSION = 2

def ramp(x, a, b):
    return np.clip((x - a) / max(1e-6, b - a), 0, 1)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--cache", default=os.path.expanduser("~/.cache/audiofx-wallpaper-glow"))
    ap.add_argument("--threshold", type=int, default=50)
    args = ap.parse_args()

    path = Path(args.image).expanduser().resolve()
    if not path.is_file():
        ap.error(f"image does not exist or is not a file: {path}")
    if not 0 <= args.threshold <= 100:
        ap.error("--threshold must be between 0 and 100")
    st = path.stat()
    key = hashlib.sha1(f"{VERSION}|{path}|{st.st_size}|{st.st_mtime_ns}|{args.threshold}".encode()).hexdigest()[:16]
    out = Path(args.cache) / key
    meta = out / "meta.json"
    if meta.exists():
        print(meta.read_text())
        return
    out.mkdir(parents=True, exist_ok=True)

    im = Image.open(path).convert("RGB")
    W, H = im.size
    if W > 3840:
        im = im.resize((3840, round(H * 3840 / W)), Image.Resampling.LANCZOS)
        W, H = im.size

    rgb8 = np.asarray(im)
    rgb = rgb8.astype(np.float32) / 255.0
    hsv = np.asarray(im.convert("HSV")).astype(np.float32) / 255.0
    sat, val = hsv[..., 1], hsv[..., 2]

    small = Image.fromarray((val * 255).astype(np.uint8)).resize(
        (max(8, W // 8), max(8, H // 8)), Image.Resampling.BOX
    ).filter(ImageFilter.GaussianBlur(max(2.0, W / 320)))
    surround = np.asarray(small.resize((W, H), Image.Resampling.BILINEAR)).astype(np.float32) / 255.0
    contrast = val - surround

    t = np.clip(args.threshold, 0, 100) / 100.0
    s0 = 0.25 + 0.45 * t
    v0 = 0.20 + 0.40 * t
    c0 = 0.04 + 0.10 * t

    candidate = (sat > s0) & (val > v0) & (
        (contrast > c0) | ((val > 0.93) & (sat > 0.5) & (contrast > c0 * 0.3))
    )
    for _ in range(6):
        if candidate.mean() <= 0.06:
            break
        t = min(1.0, t + 0.12)
        s0 = 0.25 + 0.45 * t
        v0 = 0.20 + 0.40 * t
        c0 = 0.04 + 0.10 * t
        candidate = (sat > s0) & (val > v0) & (
            (contrast > c0) | ((val > 0.93) & (sat > 0.5) & (contrast > c0 * 0.3))
        )

    core = ramp(sat, s0 - 0.08, s0 + 0.22) * ramp(val, v0 - 0.08, v0 + 0.28)
    core *= ramp(contrast, c0 * 0.4, c0 * 1.6)
    core = core * core * (3.0 - 2.0 * core)

    # Also detect small white/blue stars and other bright, low-saturation details.
    # These are often rejected by the saturation-only mask above.
    sparks = ramp(val, 0.52, 0.94) * ramp(contrast, 0.012, 0.085)
    core = np.maximum(core, sparks * 0.78)

    density_im = Image.fromarray((candidate * 255).astype(np.uint8)).resize(
        (max(8, W // 8), max(8, H // 8)), Image.Resampling.BOX
    ).filter(ImageFilter.GaussianBlur(max(2.0, W / 267)))
    density = np.asarray(density_im.resize((W, H), Image.Resampling.BILINEAR)).astype(np.float32) / 255.0
    core *= 1.0 - 0.30 * np.clip((density - 0.25) / 0.65, 0, 1)

    # Add strong white light sources if the wallpaper contains very little colour.
    if (core > 0.15).mean() < 0.003:
        light = ramp(val, 0.76, 0.94) * ramp(contrast, 0.025, 0.10)
        core = np.maximum(core, light * np.clip((0.9 - density) / 0.35, 0, 1))

    core = np.clip(core, 0, 1).astype(np.float32)
    bloom = np.asarray(
        Image.fromarray((core * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(max(4.0, min(W, H) * 0.025))
        ), dtype=np.uint8
    )

    qW, qH = max(8, W // 4), max(8, H // 4)
    info_im = Image.fromarray(bloom, mode="L").resize((qW, qH), Image.Resampling.LANCZOS)
    info = np.zeros((qH, qW, 3), dtype=np.uint8)
    info[..., 0] = np.asarray(info_im)
    xx = np.linspace(0, 255, qW, dtype=np.uint8)[None, :]
    info[..., 1] = np.repeat(xx, qH, axis=0)
    yy, xx2 = np.mgrid[0:qH, 0:qW]
    phase = ((xx2 * 1103515245 + yy * 12345 + 1013904223) & 0xFF).astype(np.uint8)
    info[..., 2] = phase

    # The standalone shader does not need flow distance, but keeps the same texture contract.
    dist = Image.new("L", (qW, qH), 0)

    # Per-pixel wallpaper colour, sampled by the shader for image-coloured glow.
    color = im.resize((W, H), Image.Resampling.BILINEAR)

    core_path = out / "core.png"
    info_path = out / "info.png"
    dist_path = out / "dist.png"
    color_path = out / "colors.png"
    Image.fromarray((core * 255).astype(np.uint8), mode="L").save(core_path)
    Image.fromarray(info, mode="RGB").save(info_path)
    dist.save(dist_path)
    color.save(color_path)

    strong = core > 0.6
    mean = rgb[strong].mean(axis=0) if strong.sum() > 20 else rgb.reshape(-1, 3).mean(axis=0)
    result = {
        "width": W, "height": H,
        "core": str(core_path), "info": str(info_path),
        "dist": str(dist_path), "colors": str(color_path),
        "color": "#%02x%02x%02x" % tuple(np.clip(mean * 255, 0, 255).astype(int)),
    }
    # Write metadata only after all textures have been written successfully.
    meta.write_text(json.dumps(result))
    print(json.dumps(result))

if __name__ == "__main__":
    main()
