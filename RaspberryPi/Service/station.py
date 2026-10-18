#!/usr/bin/env python3
"""Same-origin HTTPS adapter. The Swift process is the only session writer."""
import argparse
import asyncio
import hashlib
import hmac
import json
import ipaddress
import re
import math
import os
from pathlib import Path
import secrets
import signal
import ssl
import time
from urllib.parse import urlsplit
import uuid

from aiohttp import web
from devices import Camera, crop_image, export_pdf, review_jpeg

WEB = Path(__file__).resolve().parent.parent / 'StationWeb'


def atomic_json(path, value):
    temp = path.with_suffix('.tmp')
    with open(temp, 'w', opener=lambda p, flags: os.open(p, flags, 0o600)) as file:
        json.dump(value, file); file.flush(); os.fsync(file.fileno())
    os.replace(temp, path)
    fd = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def identifier(value):
    try:
        return str(uuid.UUID(value)).upper()
    except (ValueError, TypeError, AttributeError):
        raise web.HTTPBadRequest(text='invalid')


def public_job(job):
    return {k: v for k, v in job.items() if k in ('id', 'session', 'status', 'kind', 'revision', 'error')}


def validate_command(body):
    if not isinstance(body, dict) or set(body) - {'kind', 'session', 'revision', 'title', 'page', 'delta', 'crop'}:
        raise web.HTTPBadRequest(text='invalid')
    if body.get('kind') not in ('create', 'rename', 'capture', 'crop', 'export', 'rotate', 'move', 'remove', 'undo'):
        raise web.HTTPBadRequest(text='invalid')
    if body['kind'] != 'create':
        body['session'] = identifier(body.get('session'))
        if type(body.get('revision')) is not int or body['revision'] < 0:
            raise web.HTTPBadRequest(text='invalid')
    if 'page' in body:
        body['page'] = identifier(body['page'])
    if body['kind'] in ('create', 'rename') and (not isinstance(body.get('title'), str) or not 1 <= len(body['title'].strip()) <= 160):
        raise web.HTTPBadRequest(text='invalid')
    if body['kind'] in ('capture', 'crop'):
        crop = body.get('crop', [0, 0, 1, 1])
        if (not isinstance(crop, list) or len(crop) != 4 or
            any(type(n) not in (float, int) or not math.isfinite(n) for n in crop)):
            raise web.HTTPBadRequest(text='invalid')
        x, y, w, h = crop
        if not (0 <= x < 1 and 0 <= y < 1 and .02 <= w <= 1 and .02 <= h <= 1 and x + w <= 1.000001 and y + h <= 1.000001):
            raise web.HTTPBadRequest(text='invalid')
        body['crop'] = crop
    return body


class Adapter:
    def __init__(self, args):
        self.args = args
        self.root = Path(args.library).resolve()
        self.origin = args.origin.rstrip('/')
        self.authority = urlsplit(self.origin).netloc
        self.rpc_lock = asyncio.Lock()
        self.command_lock = asyncio.Lock()
        self.review_lock = asyncio.Semaphore(1)
        self.camera = Camera(args)
        self.tasks = set()
        self.owner = None
        self.lease_until = 0
        self.auth = {}
        self.attempts = []
        self.closing = False

    async def rpc(self, request):
        async with self.rpc_lock:
            if self.process.returncode is not None:
                raise web.HTTPServiceUnavailable(text='storage')
            self.process.stdin.write((json.dumps(request, allow_nan=False) + '\n').encode())
            await self.process.stdin.drain()
            line = await self.process.stdout.readline()
            if not line:
                raise web.HTTPServiceUnavailable(text='storage')
            result = json.loads(line)
            if 'error' in result:
                raise web.HTTPConflict(text=result['error'])
            return result['ok']

    async def start(self, app):
        os.umask(0o077)
        command = [self.args.coordinator, str(self.root), "--reserve-bytes", str(self.args.reserve_mib * 1024 * 1024)]
        if self.args.initialize:
            command.append('--initialize')
        self.process = await asyncio.create_subprocess_exec(*command, stdin=asyncio.subprocess.PIPE,
                                                         stdout=asyncio.subprocess.PIPE, limit=32 * 1024 * 1024)
        await self.rpc({'op': 'snapshot'})
        auth_file = self.root / 'phones.json'
        if auth_file.exists() and not self.args.reset_pairing:
            self.auth = json.loads(auth_file.read_text())
        else:
            atomic_json(auth_file, {})
        # A new code is local only, expires, and does not revoke existing phones.
        self.code = secrets.token_hex(4).upper()
        self.code_until = time.monotonic() + 600
        code_file = self.root / 'pairing-code.txt'
        code_file.write_text(self.code + '\n'); os.chmod(code_file, 0o600)
        self.camera_task = asyncio.create_task(self.camera.run())

    async def stop(self, app):
        self.closing = True
        self.camera_task.cancel()
        await asyncio.gather(self.camera_task, return_exceptions=True)
        if self.tasks:
            await asyncio.gather(*self.tasks, return_exceptions=True)
        self.process.stdin.close()
        await self.process.wait()

    def has_control(self, device):
        return self.owner == device and time.monotonic() < self.lease_until

    async def data(self, request):
        try:
            body = await request.json(loads=lambda s: json.loads(s, parse_constant=lambda _: (_ for _ in ()).throw(ValueError())))
            if not isinstance(body, dict):
                raise ValueError()
            return body
        except (ValueError, TypeError):
            raise web.HTTPBadRequest(text='invalid')

    @web.middleware
    async def guard(self, request, handler):
        if request.host != self.authority or (request.headers.get('Origin') and request.headers['Origin'] != self.origin):
            raise web.HTTPForbidden(text='origin')
        if request.method not in ('GET', 'POST'):
            raise web.HTTPMethodNotAllowed(request.method, ['GET', 'POST'])
        if request.method == 'POST' and (request.headers.get('Origin') != self.origin or request.content_type != 'application/json'):
            raise web.HTTPForbidden(text='origin')
        public = request.path in ('/', '/app.js', '/style.css', '/api/pair')
        if not public:
            token = request.cookies.get('station', '')
            device = hashlib.sha256(token.encode()).hexdigest()
            if device not in self.auth or self.auth[device].get('expires', 0) < time.time():
                raise web.HTTPUnauthorized(text='pair_required')
            request['device'] = device
            if request.method == 'POST' and not hmac.compare_digest(request.headers.get('X-Station-CSRF', ''), self.auth[device]['csrf']):
                raise web.HTTPForbidden(text='csrf')
        try:
            response = await handler(request)
        except web.HTTPException as error:
            response = web.Response(status=error.status, text=error.text)
        except Exception:
            response = web.Response(status=503, text='storage')
        response.headers.update({'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
                                 'Referrer-Policy': 'no-referrer', 'Content-Security-Policy':
                                 "default-src 'self'; img-src 'self' blob:; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"})
        return response

    async def pair(self, request):
        now = time.monotonic()
        self.attempts = [t for t in self.attempts if now - t < 60]
        if len(self.attempts) >= 5:
            raise web.HTTPTooManyRequests(text='pair_wait')
        self.attempts.append(now)
        body = await self.data(request)
        if now > self.code_until or not hmac.compare_digest(str(body.get('code', '')).replace(' ', '').upper(), self.code):
            raise web.HTTPForbidden(text='pair_code')
        if sum(v.get('expires', 0) >= time.time() for v in self.auth.values()) >= 8:
            raise web.HTTPConflict(text='phone_limit')
        token = secrets.token_urlsafe(32); csrf = secrets.token_urlsafe(32)
        self.auth = {k: v for k, v in self.auth.items() if v.get('expires', 0) >= time.time()}
        self.auth[hashlib.sha256(token.encode()).hexdigest()] = {'csrf': csrf, 'expires': time.time() + 30 * 86400}
        atomic_json(self.root / 'phones.json', self.auth)
        response = web.json_response({'csrf': csrf})
        response.set_cookie('station', token, secure=True, httponly=True, samesite='Strict', max_age=30 * 86400)
        return response

    async def snapshot(self, request):
        state = await self.rpc({'op': 'snapshot'})
        state.update({'csrf': self.auth[request['device']]['csrf'],
                      'control': self.has_control(request['device']),
                      'occupied': self.owner is not None and time.monotonic() < self.lease_until,
                      'camera': self.camera.error or ('ready' if time.monotonic() - self.camera.updated < 3 else 'camera_wait'),
                      'demo': self.args.demo, 'printing': 'phase2'})
        return web.json_response(state)

    async def control(self, request):
        body = await self.data(request)
        device = request['device']
        if body.get('action') == 'release':
            if self.owner == device:
                self.owner = None; self.lease_until = 0
        elif body.get('action') in ('acquire', 'takeover', 'heartbeat'):
            if body['action'] == 'heartbeat' and not self.has_control(device):
                raise web.HTTPConflict(text='control_required')
            if self.owner != device and time.monotonic() < self.lease_until and body['action'] != 'takeover':
                raise web.HTTPConflict(text='control_busy')
            self.owner = device; self.lease_until = time.monotonic() + 5
        else:
            raise web.HTTPBadRequest(text='invalid')
        return web.json_response({'control': self.has_control(device)})

    async def command(self, request):
        async with self.command_lock:
            return await self.accept_command(request)

    async def accept_command(self, request):
        if self.closing or not self.has_control(request['device']):
            raise web.HTTPConflict(text='control_required')
        body = await self.data(request)
        cmd = validate_command(body.get('command'))
        cid = identifier(body.get('id'))
        # Validate camera availability before a new job. A repeated command is
        # answered from its journal even if the camera is now unavailable.
        try:
            existing = await self.rpc({'op': 'job', 'id': cid})
        except web.HTTPConflict as e:
            if e.text != 'job_missing':
                raise
            existing = None
        if existing is None and cmd['kind'] == 'capture':
            try:
                self.camera.fresh()
            except ValueError:
                raise web.HTTPConflict(text='camera_wait')
        job = await self.rpc({'op': 'begin', 'id': cid, 'command': cmd})
        if existing is None and job['status'] == 'processing':
            # Track the task until shutdown. A dropped HTTP connection does not
            # cancel an accepted save. There is no automatic capture loop.
            frame = self.camera.fresh() if cmd['kind'] == 'capture' else None
            task = asyncio.create_task(self.process_job(job, cmd, frame))
            self.tasks.add(task); task.add_done_callback(self.tasks.discard)
        return web.json_response(public_job(job))

    async def process_job(self, job, cmd, frame):
        try:
            folder = Path(job['folder'])
            if job['kind'] == 'export':
                await asyncio.to_thread(export_pdf, job['inputs'], folder / 'export.pdf', self.args.reserve_mib * 1024 * 1024)
            else:
                source = Path(job['source']) if job['kind'] == 'crop' else folder / 'original.jpg'
                if frame is not None:
                    await asyncio.to_thread(source.write_bytes, frame)
                await asyncio.to_thread(crop_image, source, folder / 'page.jpg', cmd['crop'])
            await self.rpc({'op': 'finish', 'id': job['id']})
        except Exception as error:
            if job['kind'] == 'export':
                try:
                    (Path(job['folder']) / 'export.pdf').unlink(missing_ok=True)
                except OSError:
                    pass
            try:
                await self.rpc({'op': 'fail', 'id': job['id'], 'error': 'disk_full' if str(error) == 'disk_full' else 'processing_failed'})
            except Exception:
                pass  # Coordinator failure is visible as storage unavailable.

    async def job(self, request):
        return web.json_response(public_job(await self.rpc({'op': 'job', 'id': identifier(request.match_info['id'])})))

    async def preview(self, request):
        if self.camera.preview is None or time.monotonic() - self.camera.updated > 3:
            raise web.HTTPServiceUnavailable(text='camera_wait')
        return web.Response(body=self.camera.preview, content_type='image/jpeg')

    async def file(self, request):
        kind = request.match_info['kind']
        if kind not in ('original', 'page', 'view', 'export'):
            raise web.HTTPNotFound()
        result = await self.rpc({'op': 'file', 'id': identifier(request.match_info['id']),
                                 'page': identifier(request.match_info['page']) if kind != 'export' else '', 'kind': 'page' if kind == 'view' else kind})
        if kind == 'view':
            async with self.review_lock:
                image = await asyncio.to_thread(review_jpeg, result['path'], result['rotation'])
            return web.Response(body=image, content_type='image/jpeg')
        response = web.FileResponse(result['path'])
        if kind == 'export':
            response.headers['Content-Disposition'] = 'attachment; filename="Foliobruma.pdf"'
        return response

    async def asset(self, request):
        name = request.path[1:] or 'index.html'
        if name not in ('index.html', 'app.js', 'style.css'):
            raise web.HTTPNotFound()
        return web.FileResponse(WEB / name)


def application(args):
    adapter = Adapter(args)
    app = web.Application(client_max_size=16384, middlewares=[adapter.guard])
    app.on_startup.append(adapter.start); app.on_cleanup.append(adapter.stop)
    app.router.add_get('/', adapter.asset)
    app.router.add_get('/app.js', adapter.asset); app.router.add_get('/style.css', adapter.asset)
    app.router.add_post('/api/pair', adapter.pair)
    app.router.add_get('/api/state', adapter.snapshot)
    app.router.add_post('/api/control', adapter.control)
    app.router.add_post('/api/command', adapter.command)
    app.router.add_get('/api/jobs/{id}', adapter.job)
    app.router.add_get('/api/preview', adapter.preview)
    app.router.add_get('/api/files/{kind}/{id}/{page}', adapter.file)
    return app


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--library', required=True)
    parser.add_argument('--coordinator', default=str(Path(__file__).resolve().parent.parent / '.build/release/ScannerStation'))
    parser.add_argument('--reserve-mib', type=int, default=512)
    parser.add_argument('--initialize', action='store_true', help='Create a library marker only during first setup')
    parser.add_argument('--reset-pairing', action='store_true', help='Revoke all phones at this local start')
    parser.add_argument('--bind', required=True, help='One interface IP; do not use 0.0.0.0')
    parser.add_argument('--origin', required=True, help='Exact HTTPS origin, including the port')
    parser.add_argument('--certificate', required=True); parser.add_argument('--key', required=True)
    parser.add_argument('--demo', action='store_true')
    parser.add_argument('--camera', help='Stable /dev/v4l/by-id path')
    parser.add_argument('--camera-lock', help='Shared lock path, for example /run/foliobruma/camera.lock')
    parser.add_argument('--size', default='3264x2448'); parser.add_argument('--fps', type=int, default=5)
    args = parser.parse_args()
    try:
        ipaddress.ip_address(args.bind)
    except ValueError:
        parser.error('Bind must be an IP address.')
    if not re.fullmatch(r'[1-9][0-9]{1,4}x[1-9][0-9]{1,4}', args.size) or not 1 <= args.fps <= 30 or args.reserve_mib < 512:
        parser.error('Check the MJPG size, frame rate, and disk reserve (at least 512 MiB).')
    width, height = map(int, args.size.split('x'))
    if width * height > 50_000_000:
        parser.error('The image must not exceed 50 megapixels.')
    origin = urlsplit(args.origin)
    if (origin.scheme != 'https' or not origin.hostname or origin.path or origin.query or origin.fragment or
        origin.username or args.bind in ('0.0.0.0', '::') or
        (not args.demo and (not args.camera or not args.camera_lock))):
        parser.error('Use one HTTPS origin and one interface IP. Live mode needs a camera and its shared lock.')
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(args.certificate, args.key)
    # No access log: no private document identifiers or pair tokens in logs.
    web.run_app(application(args), host=args.bind, port=origin.port or 443, ssl_context=context,
                access_log=None, print=None, shutdown_timeout=60)


if __name__ == '__main__':
    main()
