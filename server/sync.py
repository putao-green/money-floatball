#!/usr/bin/env python3
# 上班好搭子 · 极简同步服务（共享版，带数据隔离）
# GET  /sync[?key=xxx]  -> {"rev":"<md5前12位>","data":<数据对象或null>}
# POST /sync[?key=xxx]  -> 写入数据文件（原子替换）
# 数据隔离：请求带 key 时读写 data_<key>.json，不带 key 读写 data.json（兼容旧版）
# 提示：key 是前端可见的隔离/防篡改凭据，可挡普通访问者；高安全场景请在 nginx 层加 Basic Auth
# 仅监听 127.0.0.1:8081（可用参数改端口），由 nginx 反代对外（location /sync）
import http.server, json, os, hashlib, sys, re, urllib.parse

BASE = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8081

def datafile_for(key):
    name = 'data_%s.json' % key if key else 'data.json'
    return os.path.join(BASE, name)

class H(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *a): pass
    def _key(self):
        q = urllib.parse.urlparse(self.path).query
        k = urllib.parse.parse_qs(q).get('key', [''])[0] or self.headers.get('X-Sync-Key', '')
        # 只允许字母数字下划线连字符，长度 4-64，防止路径穿越
        return k if re.match(r'^[A-Za-z0-9_-]{4,64}$', k) else ''
    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
    def do_OPTIONS(self):
        self.send_response(204); self._cors(); self.end_headers()
    def do_GET(self):
        if self.path.split('?')[0] != '/sync':
            self.send_error(404); return
        f = datafile_for(self._key())
        try: raw = open(f, 'rb').read()
        except FileNotFoundError: raw = b''
        rev = hashlib.md5(raw).hexdigest()[:12]
        obj = json.loads(raw) if raw else None
        body = json.dumps({'rev': rev, 'data': obj}, ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self._cors()
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def do_POST(self):
        if self.path.split('?')[0] != '/sync':
            self.send_error(404); return
        try:
            n = int(self.headers.get('Content-Length', 0))
            raw = self.rfile.read(n) if n > 0 else b''
            obj = json.loads(raw)
        except Exception:
            self.send_error(400, 'bad json'); return
        f = datafile_for(self._key())
        tmp = f + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as w:
            json.dump(obj, w, ensure_ascii=False)
        os.replace(tmp, f)
        body = b'{"ok":true}'
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self._cors()
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

if __name__ == '__main__':
    try:
        server_cls = getattr(http.server, 'ThreadingHTTPServer', None) or http.server.HTTPServer
        server_cls(('127.0.0.1', PORT), H).serve_forever()
    except OSError as e:
        print('FATAL', e, file=sys.stderr)
        sys.exit(1)
