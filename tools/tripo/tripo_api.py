"""Minimal Tripo v3 REST client (stdlib only).

Credential policy
-----------------
The API key is read from TRIPO_API_KEY only.  It is never written to disk,
never printed, and never included in task JSON or error messages.  Run
generation through `teamai env exec -- python3 tools/tripo/tripo_gen.py ...`
or export the key in your own shell.

Network
-------
This machine cannot reach openapi.tripo3d.ai directly; requests default to the
system proxy http://127.0.0.1:7897.  Override with TRIPO_PROXY, or --no-proxy.

API (verified against Tripo developer docs, 2026-11-21)
-------------------------------------------------------
POST /v3/files (multipart, field "file")            -> data.file_token
POST /v3/generation/image-to-model {input, model}   -> data.task_id
GET  /v3/tasks/{task_id}                            -> status + output URLs
"""

import hashlib
import json
import mimetypes
import os
import random
import time
import urllib.error
import urllib.request
import uuid

DEFAULT_BASE = 'https://openapi.tripo3d.ai/v3'
DEFAULT_PROXY = 'http://127.0.0.1:7897'
USER_AGENT = 'blender-anime-toolkit/0.1 (original-character-pipeline)'


class TripoError(RuntimeError):
    def __init__(self, message, status=None, code=None):
        super().__init__(message)
        self.status = status
        self.code = code


def _redact(text, key):
    if key:
        text = text.replace(key, '[REDACTED]')
    return text


def _unwrap(obj):
    if isinstance(obj, dict) and isinstance(obj.get('data'), dict):
        return obj['data']
    return obj


def _find_first(obj, keys):
    if isinstance(obj, dict):
        for k in keys:
            if k in obj and obj[k] is not None:
                return obj[k]
        for v in obj.values():
            found = _find_first(v, keys)
            if found is not None:
                return found
    elif isinstance(obj, list):
        for v in obj:
            found = _find_first(v, keys)
            if found is not None:
                return found
    return None


class TripoClient:
    def __init__(self, api_key=None, base_url=None, proxy='auto',
                 timeout=60):
        if api_key is None:
            api_key = os.environ.get('TRIPO_API_KEY')
        self.api_key = api_key or ''
        self.base_url = (base_url or os.environ.get('TRIPO_BASE_URL')
                         or DEFAULT_BASE).rstrip('/')
        if proxy == 'auto':
            proxy = os.environ.get('TRIPO_PROXY') or os.environ.get(
                'HTTPS_PROXY') or os.environ.get('HTTP_PROXY')
            if not proxy:
                proxy = DEFAULT_PROXY
        self.proxy = None if proxy in (None, '', 'none', 'off') else proxy
        self.timeout = timeout

    # -- networking --------------------------------------------------------
    def _opener(self):
        handlers = []
        if self.proxy:
            handlers.append(urllib.request.ProxyHandler(
                {'http': self.proxy, 'https': self.proxy}))
        else:
            handlers.append(urllib.request.ProxyHandler({}))
        return urllib.request.build_opener(*handlers)

    def _request(self, method, path, body=None, content_type=None,
                 raw_body=None, retries=4):
        url = self.base_url + path
        headers = {'Accept': 'application/json',
                   'User-Agent': USER_AGENT}
        if self.api_key:
            headers['Authorization'] = 'Bearer ' + self.api_key
        data = None
        if raw_body is not None:
            data = raw_body
        elif body is not None:
            data = json.dumps(body).encode('utf-8')
            content_type = content_type or 'application/json'
        if content_type:
            headers['Content-Type'] = content_type
        last = None
        for attempt in range(retries + 1):
            req = urllib.request.Request(url, data=data, headers=headers,
                                         method=method)
            try:
                with self._opener().open(req, timeout=self.timeout) as resp:
                    payload = resp.read()
                    return json.loads(payload.decode('utf-8'))
            except urllib.error.HTTPError as e:
                payload = e.read().decode('utf-8', errors='replace')
                try:
                    detail = json.loads(payload)
                except Exception:
                    detail = {}
                code = detail.get('code')
                msg = detail.get('message') or detail.get('msg') or payload
                last = TripoError(
                    _redact('HTTP %s: %s' % (e.code, str(msg)[:300]),
                            self.api_key), e.code, code)
                if e.code in (408, 429, 500, 502, 503, 504) and \
                        attempt < retries:
                    wait = e.headers.get('Retry-After')
                    try:
                        wait = float(wait) if wait else None
                    except ValueError:
                        wait = None
                    if wait is None:
                        wait = min(30.0, (2 ** attempt) + random.random())
                    time.sleep(wait)
                    continue
                raise last
            except (urllib.error.URLError, TimeoutError, OSError) as e:
                last = TripoError(_redact('network: %s' % e, self.api_key))
                if attempt < retries:
                    time.sleep(min(20.0, (2 ** attempt) + random.random()))
                    continue
                raise last
        raise last or TripoError('request failed')

    # -- endpoints ---------------------------------------------------------
    def upload_file(self, path):
        path = os.path.abspath(path)
        if not os.path.isfile(path):
            raise TripoError('image not found: %s' % path)
        if os.path.getsize(path) > 20 * 1024 * 1024:
            raise TripoError('image exceeds Tripo 20 MB upload limit')
        boundary = '----blender-anime-' + uuid.uuid4().hex
        ctype = mimetypes.guess_type(path)[0] or 'application/octet-stream'
        with open(path, 'rb') as f:
            content = f.read()
        fname = os.path.basename(path)
        pre = ('--%s\r\nContent-Disposition: form-data; name="file"; '
               'filename="%s"\r\nContent-Type: %s\r\n\r\n'
               % (boundary, fname, ctype)).encode('utf-8')
        post = ('\r\n--%s--\r\n' % boundary).encode('utf-8')
        body = pre + content + post
        resp = self._request('POST', '/files', raw_body=body,
                             content_type='multipart/form-data; boundary=%s'
                             % boundary)
        data = _unwrap(resp)
        token = _find_first(data, ['file_token', 'fileToken', 'token',
                                   'file_id', 'fileId'])
        if not token:
            raise TripoError('upload succeeded but no file_token in response')
        return token

    def create_image_to_model(self, file_token, model='P2-20260801',
                              face_limit=None, texture=True, pbr=True,
                              quad=False, auto_size=None, model_seed=None,
                              texture_seed=None, texture_quality=None,
                              geometry_quality=None, extra=None):
        body = {'input': file_token, 'model': model, 'texture': bool(texture),
                'pbr': bool(pbr)}
        if face_limit is not None:
            body['face_limit'] = int(face_limit)
        if quad:
            body['quad'] = True
        if auto_size is not None:
            body['auto_size'] = bool(auto_size)
        if model_seed is not None:
            body['model_seed'] = int(model_seed)
        if texture_seed is not None:
            body['texture_seed'] = int(texture_seed)
        if texture_quality:
            body['texture_quality'] = texture_quality
        if geometry_quality:
            body['geometry_quality'] = geometry_quality
        if extra:
            body.update(extra)
        resp = self._request('POST', '/generation/image-to-model', body=body)
        data = _unwrap(resp)
        task_id = _find_first(data, ['task_id', 'taskId', 'id'])
        if not task_id:
            raise TripoError('create succeeded but no task_id in response')
        return task_id, resp

    def get_task(self, task_id):
        resp = self._request('GET', '/tasks/%s' % task_id)
        return _unwrap(resp), resp

    def poll(self, task_id, timeout=600, interval=2.0, on_tick=None):
        deadline = time.time() + timeout
        last_status = None
        while time.time() < deadline:
            data, raw = self.get_task(task_id)
            status = str(_find_first(data, ['status', 'state',
                                            'task_status']) or '').lower()
            progress = _find_first(data, ['progress', 'percent'])
            if status != last_status:
                print('TRIPO_STATUS task_id=%s status=%s progress=%s' % (
                    task_id, status or '?', progress))
                last_status = status
            if on_tick:
                on_tick(data)
            if status in ('success', 'succeeded', 'completed', 'done'):
                return data, raw
            if status in ('failed', 'failure', 'cancelled', 'canceled',
                          'error'):
                msg = _find_first(data, ['message', 'error_code', 'error',
                                         'msg'])
                raise TripoError('task %s %s: %s' % (
                    task_id, status, str(msg)[:400] or 'no message'))
            time.sleep(interval)
        raise TripoError('task %s timed out after %ss (do not resubmit; '
                         'use --resume %s)' % (task_id, timeout, task_id))

    @staticmethod
    def extract_outputs(data):
        out = []
        seen = set()

        def walk(node, key_hint=''):
            if isinstance(node, dict):
                for k, v in node.items():
                    walk(v, k)
            elif isinstance(node, list):
                for v in node:
                    walk(v, key_hint)
            elif isinstance(node, str):
                low = node.lower()
                if low.startswith('http') and any(
                        low.split('?')[0].endswith(ext) for ext in
                        ('.glb', '.gltf', '.fbx', '.obj', '.stl', '.zip')):
                    if node not in seen:
                        seen.add(node)
                        out.append({'url': node, 'key': key_hint})
        walk(data)
        # prefer explicit model fields if URLs are nested without extensions
        return out

    @staticmethod
    def extract_credits(data):
        return _find_first(data, ['credits_consumed', 'creditsConsumed',
                                  'consumed_credits', 'credits', 'cost'])

    def download(self, url, out_path, retries=4):
        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        tmp = out_path + '.part'
        last = None
        for attempt in range(retries + 1):
            try:
                req = urllib.request.Request(url, headers={
                    'User-Agent': USER_AGENT})
                with self._opener().open(req, timeout=self.timeout) as resp, \
                        open(tmp, 'wb') as f:
                    while True:
                        chunk = resp.read(65536)
                        if not chunk:
                            break
                        f.write(chunk)
                size = os.path.getsize(tmp)
                if size < 64:
                    raise TripoError('downloaded file is too small: %d B'
                                     % size)
                os.replace(tmp, out_path)
                h = hashlib.sha256()
                with open(out_path, 'rb') as f:
                    for chunk in iter(lambda: f.read(65536), b''):
                        h.update(chunk)
                return {'path': out_path, 'bytes': size,
                        'sha256': h.hexdigest()}
            except (urllib.error.URLError, urllib.error.HTTPError,
                    TimeoutError, OSError, TripoError) as e:
                last = e
                if attempt < retries:
                    time.sleep(min(20.0, 2 ** attempt + random.random()))
                    continue
        raise TripoError(_redact('download failed: %s' % last, self.api_key))

    def redact(self, text):
        return _redact(str(text), self.api_key)


def file_sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()
