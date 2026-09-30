#!/usr/bin/env python3
# 上班聚宝盆 · 极简同步服务（共享版）
# GET  /sync  -> {"rev":"<md5前12位>","data":<数据对象或null>}
# POST /sync  -> 写入本文件同目录 data.json（原子替换）
# 仅监听 127.0.0.1:8081（可用参数改端口），由 nginx 反代对外（location /sync）
import http.server, json, os, hashlib, sys

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data.json')
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8081

class H(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *a): pass
    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
    def do_OPTIONS(self):
        self.send_response(204); self._cors(); self.end_headers()
    def do_GET(self):
        if self.path.split('?')[0] != '/sync':
            self.send_error(404); return
        try: raw = open(DATA, 'rb').read()
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
        tmp = DATA + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as f:
            json.dump(obj, f, ensure_ascii=False)
        os.replace(tmp, DATA)
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
