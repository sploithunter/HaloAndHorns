"""Render QuickLook's square viewport, then crop its bottom padding explicitly."""
from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess
from PIL import Image

root = Path(__file__).resolve().parent
source = (root / 'crossroads-as-built.svg').read_text()
with TemporaryDirectory(prefix='crossroads-as-built-') as tmp:
    tmp = Path(tmp)
    square = tmp / 'sheet.svg'
    square.write_text(source.replace('height="1260" viewBox="0 0 1540 1260"',
                                     'height="1540" viewBox="0 0 1540 1540"'))
    subprocess.run(['qlmanage', '-t', '-s', '1600', '-o', str(tmp), str(square)], check=True,
                   stdout=subprocess.DEVNULL)
    with Image.open(tmp / 'sheet.svg.png') as image:
        width = image.width
        height = round(width * 1260 / 1540)
        image.crop((0, 0, width, height)).save(root / 'crossroads-as-built.png')
