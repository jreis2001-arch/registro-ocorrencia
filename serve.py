import http.server
import socketserver
import sys
import os

# python -m http.server serves HTTP/1.0 with no persistent connections, which
# makes Chrome's service-worker install fetch fail with "An unknown error
# occurred when fetching the script." HTTP/1.1 + keep-alive fixes it.
class Handler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

port = int(sys.argv[1]) if len(sys.argv) > 1 else int(os.environ.get("PORT", 8791))
with Server(("0.0.0.0", port), Handler) as httpd:
    print(f"Serving on 0.0.0.0:{port}")
    httpd.serve_forever()
