"""Linux camera and bounded image jobs. No document or session rules here."""
import asyncio
import fcntl
import io
import os
import shutil
from pathlib import Path
import time

from PIL import Image, ImageDraw, ImageOps

Image.MAX_IMAGE_PIXELS = 50_000_000
MAX_FRAME = 32 * 1024 * 1024


def crop_image(source, destination, crop):
    with Image.open(source) as image:
        image.load()
        image = ImageOps.exif_transpose(image).convert('RGB')
        x, y, w, h = crop
        image.crop((round(x * image.width), round(y * image.height),
                    round((x + w) * image.width), round((y + h) * image.height))).save(destination, 'JPEG', quality=95)


def export_pdf(inputs, destination, reserve):
    # Append one page at a time. Do not hold all full-size pages in RAM.
    for index, page in enumerate(inputs):
        if shutil.disk_usage(destination.parent).free < reserve + 128 * 1024 * 1024:
            raise ValueError('disk_full')
        with Image.open(page['path']) as source:
            image = source.convert('RGB').rotate(-page['rotation'], expand=True)
            image.save(destination, 'PDF', resolution=150, append=index > 0)
            image.close()


def preview_jpeg(frame):
    with Image.open(io.BytesIO(frame)) as image:
        image.thumbnail((960, 720))
        output = io.BytesIO()
        image.convert('RGB').save(output, 'JPEG', quality=70)
        return output.getvalue()


class Camera:
    def __init__(self, args):
        self.args = args
        self.frame = None
        self.preview = None
        self.updated = 0
        self.error = 'camera_wait'
        self.process = None
        self.lock = None
        self.sequence = 0

    def fresh(self):
        if not self.frame or time.monotonic() - self.updated > 3:
            raise ValueError('camera_wait')
        return self.frame

    async def run(self):
        try:
            if self.args.demo:
                while True:
                    self.sequence += 1
                    image = Image.new('RGB', (1200, 1600), 'white')
                    draw = ImageDraw.Draw(image)
                    draw.rectangle((80, 80, 1120, 1520), outline='#384638', width=8)
                    draw.text((140, 180), f'FOLIOBRUMA - SYNTHETIC PAGE {self.sequence}', fill='black', font_size=36)
                    for y in range(350, 1300, 70):
                        draw.line((140, y, 1000, y), fill='#c8cdc5', width=3)
                    output = io.BytesIO(); image.save(output, 'JPEG', quality=90)
                    await self.accept(output.getvalue())
                    await asyncio.sleep(1)
            else:
                self.lock = os.open(self.args.camera_lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
                fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.process = await asyncio.create_subprocess_exec(
                    'ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error',
                    '-f', 'v4l2', '-input_format', 'mjpeg', '-video_size', self.args.size,
                    '-framerate', str(self.args.fps), '-i', self.args.camera,
                    '-an', '-c:v', 'copy', '-f', 'image2pipe', 'pipe:1',
                    stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
                buffer = bytearray()
                while chunk := await self.process.stdout.read(65536):
                    buffer.extend(chunk)
                    if len(buffer) > MAX_FRAME:
                        raise ValueError('camera_format')
                    while True:
                        start = buffer.find(b'\xff\xd8')
                        end = buffer.find(b'\xff\xd9', max(0, start + 2))
                        if start < 0 or end < 0:
                            break
                        frame = bytes(buffer[start:end + 2]); del buffer[:end + 2]
                        with Image.open(io.BytesIO(frame)) as image:
                            if image.size != tuple(map(int, self.args.size.split('x'))):
                                raise ValueError('camera_format')
                        await self.accept(frame)
                self.error = 'camera_stopped'
        except asyncio.CancelledError:
            raise
        except Exception:
            self.error = 'camera_stopped'
        finally:
            self.frame = self.preview = None
            if self.process and self.process.returncode is None:
                self.process.terminate()
                await self.process.wait()
            if self.lock is not None:
                os.close(self.lock)

    async def accept(self, frame):
        # One latest full-size frame and one preview. No unbounded frame queue.
        self.frame = frame
        self.updated = time.monotonic()
        self.error = None
        if self.preview is None or self.updated - getattr(self, 'preview_time', 0) >= 0.5:
            self.preview = await asyncio.to_thread(preview_jpeg, frame)
            self.preview_time = self.updated


def review_jpeg(path, rotation):
    with Image.open(path) as source:
        image = source.convert('RGB').rotate(-rotation, expand=True)
        image.thumbnail((1600, 1600))
        output = io.BytesIO()
        image.save(output, 'JPEG', quality=85)
        image.close()
        return output.getvalue()
