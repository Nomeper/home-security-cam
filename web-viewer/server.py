from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
import sys
import webbrowser
from datetime import datetime

ROOT = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
LOG = os.path.join(ROOT, "debug.log")
os.chdir(ROOT)


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript; charset=utf-8",
        ".html": "text/html; charset=utf-8",
        ".css": "text/css; charset=utf-8",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_POST(self):
        if self.path.split("?")[0] != "/debug-log":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8", "replace")
        line = "%s %s\n" % (datetime.now().isoformat(timespec="seconds"), body)
        with open(LOG, "a", encoding="utf-8") as handle:
            handle.write(line)
        self.send_response(204)
        self.end_headers()

    def log_message(self, format, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))


class Server(ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    httpd = Server(("127.0.0.1", PORT), Handler)
    url = f"http://localhost:{PORT}/index.html?v=19g"
    print("Visore PC:", url, flush=True)
    print("Lascia questa finestra aperta. Ctrl+C per chiudere.", flush=True)
    if "--no-browser" not in sys.argv:
        webbrowser.open(url)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nChiuso.")
