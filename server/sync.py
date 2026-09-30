#!/usr/bin/env python3
# 上班好搭子 · 极简同步服务（共享版，单密钥鉴权）
# GET  /sync -> {"rev":"<md5前12位>","data":<数据对象或null>}
# POST /sync -> 写入本文件同目录 data.json（原子替换）
# 鉴权：请求头 X-Sync-Key 必须等于环境变量 SYNC_KEY；未设置 SYNC_KEY 时不做鉴权（兼容旧版，不推荐）
# 部署：systemd 里配 Environment=SYNC_KEY=你的随机串（32位以上），密钥只存在于服务端环境，不进代码
# 数据文件固定 data.json；仅监听 127.0.0.1:8081（可用参数改端口），由 nginx 反代对外（location /sync）
import http.server, json, os, hashlib, sys, secrets

BASE = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8081
DATA = os.path.join(BASE, 'data.json')
MASTER = os.environ.get('SYNC_KEY', '')

class H(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *a): pass
    def _auth_ok(self):
        if not MASTER:
            return True  # 未配置密钥：兼容旧版（仅本地/内网使用）
        k = self.headers.get('X-Sync-Key', '')
        return bool(k) and secrets.compare_digest(k, MASTER)
    def do_OPTIONS(self):
        self.send_response(204); self.end_headers()
    def do_GET(self):
        if self.path.split('?')[0] != '/sync':
            self.send_error(404); return
        if not self._auth_ok():
            self.send_error(403); return
        try: raw = open(DATA, 'rb').read()
        except FileNotFoundError: raw = b''
        rev = hashlib.md5(raw).hexdigest()[:12]
        obj = json.loads(raw) if raw else None
        body = json.dumps({'rev': rev, 'data': obj}, ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def do_POST(self):
        if self.path.split('?')[0] != '/sync':
            self.send_error(404); return
        if not self._auth_ok():
            self.send_error(403); return
        try:
            n = int(self.headers.get('Content-Length', 0))
            raw = self.rfile.read(n) if n > 0 else b''
            obj = json.loads(raw)
        except Exception:
            self.send_error(400, 'bad json'); return
        tmp = DATA + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as w:
            json.dump(obj, w, ensure_ascii=False)
        os.replace(tmp, DATA)
        body = b'{"ok":true}'
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
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
