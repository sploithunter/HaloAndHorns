#!/usr/bin/env python3
"""Loopback-only preset writer for the dedicated Studio VFX lab.

Run from any directory: python3 scripts/vfx_lab/serve.py
Only the fixed crystal preset path is writable. No Roblox credentials required.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json
import math
import os
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / 'configs/vfx/crystal_schema.json').read_text())
DESTINATION = ROOT / 'configs/vfx/crystal_eruption.lua'
MAX_BYTES = 8192


def validate(preset):
    if not isinstance(preset, dict) or type(preset.get('version')) is not int or preset['version'] != SCHEMA['version']:
        raise ValueError('Unsupported preset version')
    keys = {'version'}
    for field in SCHEMA['numbers']:
        key = field['key']
        keys.add(key)
        value = preset.get(key)
        if type(value) not in (int, float) or not math.isfinite(value) or not field['min'] <= value <= field['max']:
            raise ValueError(f'Invalid {key}')
        if field['step'] == 1 and value % 1:
            raise ValueError(f'Expected integer {key}')
    for field in SCHEMA['colors']:
        key = field['key']
        keys.add(key)
        rgb = preset.get(key)
        if not isinstance(rgb, list) or len(rgb) != 3 or any(type(v) not in (int, float) or not math.isfinite(v) or v % 1 or not 0 <= v <= 255 for v in rgb):
            raise ValueError(f'Invalid RGB {key}')
    if set(preset) != keys:
        raise ValueError('Unknown or missing preset keys')


def to_lua(preset):
    validate(preset)
    lines = ['-- Saved by the VFX Lab. Art and timing are owned by this preset.', 'return {', f'    version = {SCHEMA["version"]},']
    for field in SCHEMA['numbers']:
        lines.append(f'    {field["key"]} = {preset[field["key"]]:.10g},')
    for field in SCHEMA['colors']:
        rgb = ', '.join(str(int(v)) for v in preset[field['key']])
        lines.append(f'    {field["key"]} = {{ {rgb} }},')
    return '\n'.join(lines + ['}', ''])


def save(preset, destination=DESTINATION):
    source = to_lua(preset)
    fd, tmp = tempfile.mkstemp(prefix='.crystal-', suffix='.tmp', dir=destination.parent)
    try:
        with os.fdopen(fd, 'w') as handle:
            handle.write(source)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, destination)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, message):
        body = json.dumps({'message': message}).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.respond(200 if self.path == '/health' else 404, 'VFX Lab preset bridge')

    def do_POST(self):
        # Browser-origin requests cannot write presets. Studio HttpService sends no Origin.
        if self.path != '/preset' or self.headers.get('Origin'):
            self.respond(403, 'Only Studio preset saves are accepted')
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= MAX_BYTES:
                raise ValueError('Invalid body size')
            preset = json.loads(self.rfile.read(length))
            save(preset)
        except (ValueError, TypeError, OverflowError) as error:
            self.respond(400, str(error))
            return
        except OSError as error:
            self.respond(500, f'Could not save preset: {error}')
            return
        self.respond(200, 'Saved configs/vfx/crystal_eruption.lua')


if __name__ == '__main__':
    print(f'VFX Lab save bridge: http://127.0.0.1:34874 → {DESTINATION}', flush=True)
    HTTPServer(('127.0.0.1', 34874), Handler).serve_forever()
