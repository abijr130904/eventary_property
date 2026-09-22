#!/usr/bin/env python3
"""Shrink the textures inside a .glb so it loads quickly on the web.

Geometry, materials, node hierarchy and extensions are copied byte-for-byte;
only the embedded images are downscaled and re-encoded (as JPEG). Blender's
glTF export often embeds 2K PNG textures, which is where nearly all of a
"heavy" .glb's size comes from.

Usage:
    python3 tools/optimize_glb.py input.glb output.glb
    python3 tools/optimize_glb.py input.glb output.glb --max-size 2048

Requires: Pillow, numpy  (pip install pillow numpy)

Notes
- Colour textures (base colour / emissive) use JPEG 4:2:0.
- Data textures (normal, roughness/metallic, occlusion, ...) use JPEG 4:4:4
  so packed channels don't bleed into each other.
- An image that still needs an alpha channel (used by a material with
  alphaMode != OPAQUE, or as a KHR_materials_specular texture) stays PNG.
- JPEGs that are already small enough are copied untouched (no re-encode loss).
- Texture *resolution* is the only visual trade-off. If something looks
  soft, re-run with a larger --max-size.
"""
import argparse
import io
import json
import struct

import numpy as np
from PIL import Image


def read_glb(path):
    data = open(path, 'rb').read()
    magic, version, total = struct.unpack('<4sII', data[:12])
    if magic != b'glTF' or version != 2 or total != len(data):
        raise SystemExit('Not a valid glTF 2.0 binary (.glb) file')
    json_len, json_type = struct.unpack('<I4s', data[12:20])
    if json_type != b'JSON':
        raise SystemExit('First chunk is not JSON')
    gltf = json.loads(data[20:20 + json_len].decode('utf8').rstrip('\x00 '))
    bin_len, bin_type = struct.unpack('<I4s', data[20 + json_len:28 + json_len])
    if bin_type != b'BIN\x00':
        raise SystemExit('Second chunk is not BIN')
    binary = data[28 + json_len:28 + json_len + bin_len]
    return gltf, binary, len(data)


def texture_roles(gltf):
    """Map image index -> set of roles it plays, and the set of images that need alpha."""
    roles, needs_alpha = {}, set()

    def add(tex_info, name, alpha=False):
        if not tex_info:
            return
        src = gltf['textures'][tex_info['index']].get('source')
        roles.setdefault(src, set()).add(name)
        if alpha:
            needs_alpha.add(src)

    for m in gltf.get('materials', []):
        blended = m.get('alphaMode', 'OPAQUE') != 'OPAQUE'
        pbr = m.get('pbrMetallicRoughness', {})
        add(pbr.get('baseColorTexture'), 'base', alpha=blended)
        add(pbr.get('metallicRoughnessTexture'), 'mr')
        add(m.get('normalTexture'), 'normal')
        add(m.get('occlusionTexture'), 'occlusion')
        add(m.get('emissiveTexture'), 'emissive')
        for ext_name, ext in m.get('extensions', {}).items():
            for key, val in ext.items():
                if isinstance(val, dict) and 'index' in val:
                    add(val, f'{ext_name}:{key}', alpha=(key == 'specularTexture'))
    return roles, needs_alpha


def to_rgb8(im):
    """Return an 8-bit RGB image (handles 16-bit / palette / grayscale inputs)."""
    if im.mode.startswith('I;16') or im.mode in ('I', 'F'):
        arr = np.asarray(im).astype(np.float32)
        arr /= 65535.0 if arr.max() > 255 else 255.0
        return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), 'L').convert('RGB')
    return im.convert('RGB')


def has_real_alpha(im):
    if im.mode in ('RGBA', 'LA', 'PA') or (im.mode == 'P' and 'transparency' in im.info):
        return np.asarray(im.convert('RGBA'))[..., 3].min() < 255
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('input')
    ap.add_argument('output')
    ap.add_argument('--max-size', type=int, default=1024, help='longest texture side in px (default 1024)')
    ap.add_argument('--quality-color', type=int, default=82, help='JPEG quality for colour maps (default 82)')
    ap.add_argument('--quality-data', type=int, default=90, help='JPEG quality for data maps (default 90)')
    args = ap.parse_args()

    gltf, binary, size_before = read_glb(args.input)
    roles, needs_alpha = texture_roles(gltf)
    views = gltf['bufferViews']
    image_of_view = {im['bufferView']: i for i, im in enumerate(gltf.get('images', [])) if 'bufferView' in im}
    if len(image_of_view) != len(gltf.get('images', [])):
        raise SystemExit('This .glb references external image files; only embedded images are supported')

    chunks = []
    for i, v in enumerate(views):
        start = v.get('byteOffset', 0)
        raw = binary[start:start + v['byteLength']]
        if i in image_of_view:
            idx = image_of_view[i]
            im = Image.open(io.BytesIO(raw))
            keep_alpha = idx in needs_alpha and has_real_alpha(im)
            if im.format == 'JPEG' and max(im.size) <= args.max_size:
                pass  # already small: keep the original bytes
            elif keep_alpha:
                rgba = im.convert('RGBA')
                rgba.thumbnail((args.max_size, args.max_size), Image.LANCZOS)
                buf = io.BytesIO()
                rgba.save(buf, 'PNG', optimize=True)
                raw = buf.getvalue()
                gltf['images'][idx]['mimeType'] = 'image/png'
            else:
                rgb = to_rgb8(im)
                rgb.thumbnail((args.max_size, args.max_size), Image.LANCZOS)
                r = roles.get(idx, set())
                colour_only = bool(r) and r <= {'base', 'emissive'}
                buf = io.BytesIO()
                if colour_only:
                    rgb.save(buf, 'JPEG', quality=args.quality_color, optimize=True, subsampling='4:2:0')
                else:
                    rgb.save(buf, 'JPEG', quality=args.quality_data, optimize=True, subsampling=0)
                raw = buf.getvalue()
                gltf['images'][idx]['mimeType'] = 'image/jpeg'
        chunks.append(raw)

    # Re-pack the binary chunk with 4-byte alignment and patch offsets/lengths.
    out_bin = bytearray()
    for v, raw in zip(views, chunks):
        out_bin += b'\x00' * (-len(out_bin) % 4)
        v['byteOffset'] = len(out_bin)
        v['byteLength'] = len(raw)
        out_bin += raw
    out_bin += b'\x00' * (-len(out_bin) % 4)
    gltf['buffers'][0]['byteLength'] = len(out_bin)

    js = json.dumps(gltf, separators=(',', ':')).encode('utf8')
    js += b' ' * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out_bin)
    with open(args.output, 'wb') as f:
        f.write(struct.pack('<4sII', b'glTF', 2, total))
        f.write(struct.pack('<I4s', len(js), b'JSON') + js)
        f.write(struct.pack('<I4s', len(out_bin), b'BIN\x00') + bytes(out_bin))

    print(f'{args.input}: {size_before / 1e6:.2f} MB  ->  {args.output}: {total / 1e6:.2f} MB')


if __name__ == '__main__':
    main()
