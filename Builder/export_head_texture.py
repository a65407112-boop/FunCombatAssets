#!/usr/bin/env python3
"""Export the verified original head image as exact RGBA runs.

This is a manual rendering experiment, not a replacement avatar texture.
No pixel, skin color, alpha or mesh is changed. The normal game builder copies
the resulting standalone resource; the loader never invokes head_test.lua.
"""
from __future__ import annotations

import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
import urllib.request
import zlib

from PIL import Image

TEXTURE_ID = 130652123696339
EXPECTED_PNG_SHA256 = '72bde92df1de980578edbb21f40858771ea7d4cb215a68cd24627d6e4b88e461'
EXPECTED_RGBA_SHA256 = 'cd67ba43010b8d05a72a95134620a7f7e829bbd67f535a58f7715fc7fdef9e1e'


def encode(source: bytes, uri: str) -> dict:
    with Image.open(BytesIO(source)) as image:
        if image.mode != 'RGBA':
            raise ValueError('Expected original RGBA image; conversion is not permitted')
        width, height = image.size
        pixels = image.tobytes()
    runs = []
    for offset in range(0, len(pixels), 4):
        color = int.from_bytes(pixels[offset:offset + 4], 'little')
        if runs and runs[-1][1] == color:
            runs[-1][0] += 1
        else:
            runs.append([1, color])
    return {'schema': 1, 'format': 'rgba-u32le-rle', 'sourceTexture': uri,
            'sourcePngSha256': hashlib.sha256(source).hexdigest(),
            'rgbaSha256': hashlib.sha256(pixels).hexdigest(),
            'rgbaAdler32': zlib.adler32(pixels) & 0xffffffff,
            'width': width, 'height': height, 'runs': runs}


def export(source: Path, output: Path) -> None:
    if source.resolve() == output.resolve() or (output.exists() and source.samefile(output)):
        raise ValueError('Output must not overwrite the original PNG')
    data = source.read_bytes()
    if hashlib.sha256(data).hexdigest() != EXPECTED_PNG_SHA256:
        raise ValueError('Original image SHA256 differs; no substitute face will be exported')
    document = encode(data, 'rbxassetid://' + str(TEXTURE_ID))
    if document['rgbaSha256'] != EXPECTED_RGBA_SHA256:
        raise ValueError('Original RGBA SHA256 differs')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, separators=(',', ':')) + '\n', encoding='utf8')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, help='Verified original PNG; never overwritten')
    parser.add_argument('--download', action='store_true', help='Fetch the exact public original from Roblox')
    parser.add_argument('--output', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'diagnostics/head_texture_130652123696339.json')
    args = parser.parse_args()
    if bool(args.source) == args.download:
        parser.error('Choose exactly one of --source or --download')
    if args.download:
        url = 'https://assetdelivery.roblox.com/v1/asset/?id=' + str(TEXTURE_ID)
        with urllib.request.urlopen(url, timeout=20) as response:
            data = response.read(2 * 1024 * 1024 + 1)
        if hashlib.sha256(data).hexdigest() != EXPECTED_PNG_SHA256:
            raise ValueError('Downloaded original image SHA256 differs')
        document = encode(data, 'rbxassetid://' + str(TEXTURE_ID))
        if document['rgbaSha256'] != EXPECTED_RGBA_SHA256:
            raise ValueError('Downloaded RGBA SHA256 differs')
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(document, separators=(',', ':')) + '\n', encoding='utf8')
    else:
        if args.source.resolve() == args.output.resolve():
            parser.error('Output must not overwrite the original PNG')
        export(args.source, args.output)
    print('Exported exact original RGBA pixels:', args.output)


if __name__ == '__main__':
    main()
