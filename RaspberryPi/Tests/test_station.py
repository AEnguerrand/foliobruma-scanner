#!/usr/bin/env python3
"""Real HTTPS, Swift coordinator, and synthetic camera integration tests."""
import asyncio
import io
import json
from pathlib import Path
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
import uuid

import aiohttp
from aiohttp import web
from PIL import Image

PI = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PI / 'Service'))
from station import application, validate_command


class StationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        cert = self.root / 'cert.pem'; key = self.root / 'key.pem'
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                        '-subj', '/CN=localhost', '-keyout', str(key), '-out', str(cert)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); self.tls.load_cert_chain(cert, key)
        sock = socket.socket(); sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]; sock.close()
        self.origin = f'https://127.0.0.1:{port}'
        self.port = port
        self.args = SimpleNamespace(library=str(self.root / 'library'), coordinator=str(PI / '.build/debug/ScannerStation'),
                                    initialize=True, reset_pairing=False, demo=True, origin=self.origin, reserve_mib=512)
        self.clients = []
        await self.start()
        self.client = await self.phone()

    async def start(self):
        self.app = application(self.args)
        self.runner = web.AppRunner(self.app, access_log=None)
        await self.runner.setup()
        self.site = web.TCPSite(self.runner, '127.0.0.1', self.port, ssl_context=self.tls)
        await self.site.start()
        for _ in range(100):
            if (await self.request(self.client if hasattr(self, 'client') else None, 'GET', '/'))[0] == 200:
                break
            await asyncio.sleep(.01)

    async def phone(self, paired=True):
        client = aiohttp.ClientSession(connector=aiohttp.TCPConnector(ssl=False), cookie_jar=aiohttp.CookieJar(unsafe=True))
        self.clients.append(client)
        client.csrf = ''
        if paired:
            code = (self.root / 'library/pairing-code.txt').read_text().strip()
            status, body = await self.request(client, 'POST', '/api/pair', {'code': code})
            self.assertEqual(status, 200, body); client.csrf = body['csrf']
        return client

    async def request(self, client, method, path, data=None, headers=None):
        if client is None:
            async with aiohttp.ClientSession(connector=aiohttp.TCPConnector(ssl=False)) as temporary:
                async with temporary.get(self.origin + path) as response:
                    return response.status, await response.text()
        h = {'Origin': self.origin, 'X-Station-CSRF': client.csrf}
        h.update(headers or {})
        async with client.request(method, self.origin + path, json=data, headers=h) as response:
            raw = await response.read()
            try:
                body = json.loads(raw)
            except (ValueError, UnicodeDecodeError):
                body = raw
            return response.status, body

    async def acquire(self, client=None, action='acquire'):
        status, body = await self.request(client or self.client, 'POST', '/api/control', {'action': action})
        self.assertEqual(status, 200, body)

    async def state(self):
        status, body = await self.request(self.client, 'GET', '/api/state')
        self.assertEqual(status, 200, body)
        return body

    async def send(self, command, cid=None, wait=True):
        cid = cid or str(uuid.uuid4())
        await self.acquire()
        status, body = await self.request(self.client, 'POST', '/api/command', {'id': cid, 'command': command})
        self.assertEqual(status, 200, body)
        if wait:
            for _ in range(200):
                status, body = await self.request(self.client, 'GET', '/api/jobs/' + cid)
                if body['status'] in ('done', 'failed'):
                    break
                await asyncio.sleep(.03)
            self.assertEqual(body['status'], 'done', body)
        return body

    async def create(self):
        job = await self.send({'kind': 'create', 'title': 'Synthetic test'})
        return job['session']

    async def edit(self, sid, kind, **fields):
        doc = next(s for s in (await self.state())['sessions'] if s['id'] == sid)
        command = {'kind': kind, 'session': sid, 'revision': doc['revision'], **fields}
        return await self.send(command), command

    async def asyncTearDown(self):
        await self.runner.cleanup()
        for client in self.clients:
            await client.close()
        self.temp.cleanup()

    async def test_twenty_pages_restart_retries_and_pdf(self):
        sid = await self.create()
        await asyncio.sleep(.2)
        requests = []
        for _ in range(20):
            job, cmd = await self.edit(sid, 'capture', crop=[.1, .1, .8, .8])
            requests.append((job['id'], cmd))
        before = next(s for s in (await self.state())['sessions'] if s['id'] == sid)
        self.assertEqual(len(before['document']['pages']), 20)
        self.assertEqual(before['revision'], 21)
        originals = sorted((self.root / 'library/Sessions' / sid / 'Originals').glob('*.jpg'))
        hashes = [p.read_bytes() for p in originals]
        await self.runner.cleanup()
        self.args.initialize = False
        await self.start()
        await self.acquire()
        for cid, cmd in requests:
            await self.send(cmd, cid)
        after = next(s for s in (await self.state())['sessions'] if s['id'] == sid)
        self.assertEqual(before, after)
        self.assertEqual(hashes, [p.read_bytes() for p in originals])
        job, _ = await self.edit(sid, 'export')
        status, pdf = await self.request(self.client, 'GET', f'/api/files/export/{job["id"]}/download')
        self.assertEqual(status, 200)
        self.assertTrue(pdf.startswith(b'%PDF-'))
        self.assertIn(b'/Count 20', pdf)
        path = self.root / 'export.pdf'; path.write_bytes(pdf)
        info = shutil.which('pdfinfo') or str(Path.home() / '.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/override/pdfinfo')
        if Path(info).is_file():
            text = subprocess.check_output([info, str(path)], text=True)
            self.assertIn('Pages:           20', text)

    async def test_page_operations_and_original_preservation(self):
        sid = await self.create()
        for _ in range(3):
            await self.edit(sid, 'capture')
        doc = (await self.state())['sessions'][0]
        ids = [p['id'] for p in doc['document']['pages']]
        original = self.root / 'library/Sessions' / sid / doc['document']['pages'][0]['original']
        data = original.read_bytes()
        await self.edit(sid, 'rotate', page=ids[0])
        await self.edit(sid, 'move', page=ids[0], delta=1)
        await self.edit(sid, 'remove', page=ids[0])
        await self.runner.cleanup(); await self.start()
        await self.edit(sid, 'undo')
        await self.edit(sid, 'crop', page=ids[0], crop=[.2, .2, .5, .5])
        final = (await self.state())['sessions'][0]
        self.assertEqual([p['id'] for p in final['document']['pages']], [ids[1], ids[0], ids[2]])
        page = final['document']['pages'][1]
        self.assertEqual(page['rotation'], 90)
        with Image.open(self.root / 'library/Sessions' / sid / page['file']) as cropped:
            self.assertEqual(cropped.size, (600, 800))
        status, view = await self.request(self.client, 'GET', f'/api/files/view/{sid}/{ids[0]}')
        self.assertEqual(status, 200)
        with Image.open(io.BytesIO(view)) as preview:
            self.assertEqual(preview.size, (800, 600))
        self.assertEqual(data, original.read_bytes())
        self.assertFalse(final['canUndo'])
        # A Mac-compatible manifest has no new required Pi fields.
        manifest = json.loads((self.root / 'library/Sessions' / sid / 'session.json').read_text())
        self.assertTrue(set(manifest) <= {'title', 'pages', 'metadata', 'automation', 'rejected', 'resolvedRejections'})

    async def test_pair_security_and_single_operator(self):
        anon = await self.phone(paired=False)
        for path in ('/api/state', '/api/preview', '/api/files/original/no/no'):
            self.assertEqual((await self.request(anon, 'GET', path))[0], 401)
        self.assertEqual((await self.request(self.client, 'POST', '/api/control', {'action': 'acquire'}, {'Origin':'https://evil.example'}))[0], 403)
        self.assertEqual((await self.request(self.client, 'POST', '/api/control', {'action': 'acquire'}, {'X-Station-CSRF':'bad'}))[0], 403)
        self.assertEqual((await self.request(self.client, 'GET', '/api/state', headers={'Host':'evil.example'}))[0], 403)
        second = await self.phone()
        await self.acquire()
        self.assertEqual((await self.request(second, 'POST', '/api/control', {'action':'acquire'}))[0], 409)
        await self.acquire(second, 'takeover')
        self.assertEqual((await self.request(self.client, 'POST', '/api/command', {'id':str(uuid.uuid4()),'command':{'kind':'create','title':'Denied'}}))[0], 409)
        # A disconnected phone has no lease after five seconds, and no job is started.
        await asyncio.sleep(5.05)
        self.assertEqual((await self.request(second, 'POST', '/api/command', {'id':str(uuid.uuid4()),'command':{'kind':'create','title':'Denied'}}))[0], 409)
        self.assertEqual((await self.state())['sessions'], [])
        for _ in range(4):
            await self.request(anon, 'POST', '/api/pair', {'code':'wrong'})
        self.assertEqual((await self.request(anon, 'POST', '/api/pair', {'code':'wrong'}))[0], 429)
        for bad in (['x'], {'kind':'capture','session':'../escape'}, {'kind':'capture','session':str(uuid.uuid4()),'revision':1,'crop':[0,0,float('nan'),1]}):
            with self.assertRaises(web.HTTPBadRequest):
                validate_command(bad)

    async def test_stale_uuid_reuse_and_no_capture_after_disconnect(self):
        sid = await self.create()
        job, command = await self.edit(sid, 'capture')
        await self.send(command, job['id'])
        await self.acquire()
        stale = {'id':str(uuid.uuid4()),'command':command}
        status, body = await self.request(self.client, 'POST', '/api/command', stale)
        self.assertEqual((status, body), (409, b'stale'))
        changed = {**command, 'crop':[0,0,.5,.5]}
        status, body = await self.request(self.client, 'POST', '/api/command', {'id':job['id'],'command':changed})
        self.assertEqual((status, body), (409, b'command_reused'))
        await self.request(self.client, 'POST', '/api/control', {'action':'release'})
        await asyncio.sleep(.2)
        self.assertEqual(len((await self.state())['sessions'][0]['document']['pages']), 1)

    async def test_restart_recovery_lock_and_missing_volume(self):
        sid = await self.create()
        # A second process cannot own the same library.
        other = await asyncio.create_subprocess_exec(self.args.coordinator, str(self.root / 'library'),
                                                     stdin=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE)
        _, stderr = await other.communicate()
        self.assertEqual(other.returncode, 1); self.assertIn(b'library_locked', stderr)
        await self.runner.cleanup()
        journal = self.root / 'library/station.json'; state = json.loads(journal.read_text())
        pending_id, commit_id = str(uuid.uuid4()).upper(), str(uuid.uuid4()).upper()
        state['jobs'][pending_id] = {'id':pending_id,'kind':'capture','session':sid,'status':'processing'}
        state['jobs'][commit_id] = {'id':commit_id,'kind':'rename','session':sid,'status':'committing',
                                    'revision':2,'document':{'title':'Recovered commit','pages':[]}}
        journal.write_text(json.dumps(state))
        await self.start()
        self.assertEqual((await self.state())['sessions'][0]['document']['title'], 'Recovered commit')
        status, body = await self.request(self.client, 'GET', '/api/jobs/'+pending_id)
        self.assertEqual(body['status'], 'failed'); self.assertEqual(body['error'], 'interrupted')
        missing = await asyncio.create_subprocess_exec(self.args.coordinator, str(self.root / 'not-mounted'),
                                                     stdin=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE)
        _, stderr = await missing.communicate()
        self.assertIn(b'library_missing', stderr); self.assertFalse((self.root / 'not-mounted').exists())

    async def test_removed_library_marker_stops_writes(self):
        root = self.root / 'removed-volume'
        process = await asyncio.create_subprocess_exec(self.args.coordinator, str(root), '--initialize',
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE)
        process.stdin.write(b'{"op":"snapshot"}\n'); await process.stdin.drain()
        self.assertIn(b'"ok"', await process.stdout.readline())
        (root / 'station-library').unlink()
        request = {'op':'begin', 'id':str(uuid.uuid4()), 'command':{'kind':'create','title':'Must not save'}}
        process.stdin.write((json.dumps(request)+'\n').encode()); await process.stdin.drain()
        self.assertIn(b'library_missing', await process.stdout.readline())
        await process.wait()
        self.assertEqual(process.returncode, 1)
        self.assertFalse((root / 'Sessions').exists())

    async def test_simultaneous_commands_and_failed_image_save(self):
        sid = await self.create()
        doc = (await self.state())['sessions'][0]
        await self.acquire()
        command = {'kind':'capture', 'session':sid, 'revision':doc['revision'], 'crop':[0,0,1,1]}
        cid = str(uuid.uuid4())
        replies = await asyncio.gather(*(self.request(self.client, 'POST', '/api/command', {'id':cid, 'command':command}) for _ in range(4)))
        self.assertTrue(all(status == 200 for status, _ in replies), replies)
        for _ in range(100):
            _, job = await self.request(self.client, 'GET', '/api/jobs/'+cid)
            if job['status'] == 'done':
                break
            await asyncio.sleep(.02)
        self.assertEqual(len((await self.state())['sessions'][0]['document']['pages']), 1)
        # Invalid image data must never produce a saved page or delete originals.
        adapter = next(callback.__self__ for callback in self.app.on_startup if getattr(callback, '__name__', '') == 'start')
        adapter.camera_task.cancel()
        await asyncio.gather(adapter.camera_task, return_exceptions=True)
        adapter.camera.frame = b'not a JPEG'
        adapter.camera.updated = __import__('time').monotonic()
        next_doc = (await self.state())['sessions'][0]
        command['revision'] = next_doc['revision']
        failed_id = str(uuid.uuid4())
        status, _ = await self.request(self.client, 'POST', '/api/command', {'id':failed_id, 'command':command})
        self.assertEqual(status, 200)
        for _ in range(100):
            _, job = await self.request(self.client, 'GET', '/api/jobs/'+failed_id)
            if job['status'] == 'failed':
                break
            await asyncio.sleep(.02)
        self.assertEqual(job['status'], 'failed')
        self.assertEqual(len((await self.state())['sessions'][0]['document']['pages']), 1)

    async def test_disk_reserve_rejects_before_capture(self):
        await self.runner.cleanup()
        self.args.reserve_mib = 10**9
        await self.start(); await self.acquire()
        status, body = await self.request(self.client, 'POST', '/api/command', {'id':str(uuid.uuid4()),'command':{'kind':'create','title':'No space'}})
        self.assertEqual((status, body), (409, b'disk_full'))
        self.assertEqual((await self.state())['sessions'], [])


if __name__ == '__main__':
    unittest.main(verbosity=2)
