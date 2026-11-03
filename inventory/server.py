#!/usr/bin/env python3
"""Inventory service used to observe Kubernetes service discovery and readiness."""

import json
import os
import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("PORT", "8080"))
POD_NAME = os.environ.get("POD_NAME") or socket.gethostname()
READY_FILE = os.environ.get("READY_FILE", "/tmp/ready")

ITEMS = [
    {"sku": "SKU-1001", "name": "Wireless Mouse", "quantity": 42},
    {"sku": "SKU-1002", "name": "Mechanical Keyboard", "quantity": 17},
    {"sku": "SKU-1003", "name": "USB-C Hub", "quantity": 8},
]

lock = threading.Lock()
served = 0


def is_ready() -> bool:
    return os.path.exists(READY_FILE)


def set_ready(ready: bool) -> None:
    if ready:
        open(READY_FILE, "a").close()
        return
    if os.path.exists(READY_FILE):
        os.remove(READY_FILE)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        print(f"[{POD_NAME}] {self.address_string()} {fmt % args}", flush=True)

    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("X-Pod-Name", POD_NAME)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _next_served(self) -> int:
        global served
        with lock:
            served += 1
            return served

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/healthz", "/livez"):
            self._send(200, {"status": "ok", "pod": POD_NAME})
            return
        if path == "/ready":
            ready = is_ready()
            self._send(200 if ready else 503, {"ready": ready, "pod": POD_NAME})
            return
        if path == "/inventory":
            count = self._next_served()
            self._send(
                200,
                {
                    "service": "inventory",
                    "pod": POD_NAME,
                    "served": count,
                    "items": ITEMS,
                },
            )
            return
        self._send(404, {"error": "not found", "pod": POD_NAME})

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path == "/admin/ready":
            set_ready(True)
            self._send(200, {"ready": True, "pod": POD_NAME})
            return
        if path == "/admin/unready":
            set_ready(False)
            self._send(200, {"ready": False, "pod": POD_NAME})
            return
        self._send(404, {"error": "not found", "pod": POD_NAME})


def main() -> None:
    set_ready(True)
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"[{POD_NAME}] inventory listening on {PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
