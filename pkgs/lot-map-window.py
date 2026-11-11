"""lot-map-window: shows the lot-map Claude Code plugin's map in its own window.

The plugin (linux-window fork) writes its SVG to $XDG_RUNTIME_DIR/lot-map/map.svg
on every change. This serves that file plus a small page on localhost and opens
the page as a Brave app window. The server exits after a while with no requests,
so closing the window eventually stops it.
"""

import http.server
import os
import socket
import subprocess
import sys
import threading
import time

PORT = int(os.environ.get("LOT_MAP_PORT", "7393"))
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
MAP_PATH = os.environ.get("LOT_MAP_SVG", os.path.join(RUNTIME, "lot-map", "map.svg"))
IDLE_EXIT_S = 120
BROWSER = os.environ.get("LOT_MAP_BROWSER", "brave")

PAGE = b"""<!doctype html>
<meta charset="utf-8">
<title>lot-map</title>
<style>
  :root { color-scheme: light dark; --bg: #faf9f5; --fg: #6b6a65; }
  @media (prefers-color-scheme: dark) { :root { --bg: #1f1e1d; --fg: #9a9893; } }
  html, body { margin: 0; height: 100%; background: var(--bg); color: var(--fg);
               font: 13px system-ui, sans-serif; overflow: hidden; }
  #stage { position: fixed; inset: 0; display: grid; place-items: center; }
  #stage img { position: absolute; max-width: 100%; max-height: 100%; }
  #wait { position: fixed; inset: 0; display: grid; place-items: center; }
</style>
<div id="wait">Waiting for Claude Code\xe2\x80\xa6 (start a session with the lot-map plugin)</div>
<div id="stage"></div>
<script>
  const stage = document.getElementById('stage')
  const wait = document.getElementById('wait')
  let last = ''
  async function poll() {
    try {
      const r = await fetch('map.svg', { cache: 'no-store' })
      if (r.ok) {
        const v = r.headers.get('X-Map-Version') || ''
        if (v !== last) {
          last = v
          // Load the new frame off-screen, then swap, so the map never flashes empty.
          const img = new Image()
          img.onload = () => {
            stage.replaceChildren(img)
            wait.hidden = true
          }
          img.src = 'map.svg?v=' + encodeURIComponent(v)
        }
      }
    } catch {}
    setTimeout(poll, 300)
  }
  poll()
</script>
"""

last_request = time.monotonic()


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global last_request
        last_request = time.monotonic()
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            self._send(200, "text/html; charset=utf-8", PAGE)
        elif path == "/map.svg":
            try:
                st = os.stat(MAP_PATH)
                with open(MAP_PATH, "rb") as f:
                    body = f.read()
            except OSError:
                self._send(404, "text/plain", b"no map yet")
                return
            self._send(200, "image/svg+xml", body, {"X-Map-Version": str(st.st_mtime_ns)})
        else:
            self._send(404, "text/plain", b"not found")

    def _send(self, code, ctype, body, extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def serve():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)

    def reaper():
        while time.monotonic() - last_request < IDLE_EXIT_S:
            time.sleep(5)
        server.shutdown()

    threading.Thread(target=reaper, daemon=True).start()
    server.serve_forever()


def port_open():
    with socket.socket() as s:
        s.settimeout(0.3)
        return s.connect_ex(("127.0.0.1", PORT)) == 0


def main():
    if "--serve" in sys.argv:
        serve()
        return
    if not port_open():
        subprocess.Popen(
            [sys.executable, os.path.abspath(__file__), "--serve"],
            start_new_session=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        for _ in range(30):
            if port_open():
                break
            time.sleep(0.1)
    url = f"http://127.0.0.1:{PORT}/"
    if "--no-window" in sys.argv:
        print(url)
        return
    os.execvp(BROWSER, [BROWSER, f"--app={url}"])


if __name__ == "__main__":
    main()
