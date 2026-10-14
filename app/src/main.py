"""
Minimal HTTP application used by the "Insecure AWS infrastructure remediation"
exercise.

Endpoints
---------
GET /        -> confirms the application is running (JSON).
GET /health  -> health check (JSON).
GET /version -> deployed version / commit SHA (JSON).

The version and commit are injected at build/run time through the
APP_VERSION and GIT_COMMIT environment variables so that the running
container can always be traced back to a concrete build.
"""

import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

APP_NAME = os.environ.get("APP_NAME", "insecure-infra-demo")
APP_VERSION = os.environ.get("APP_VERSION", "dev")
GIT_COMMIT = os.environ.get("GIT_COMMIT", "unknown")
PORT = int(os.environ.get("PORT", "8080"))


def _json(message, **extra):
    """Return a tiny JSON document without pulling in extra dependencies."""
    import json

    payload = {
        "app": APP_NAME,
        "message": message,
        "version": APP_VERSION,
        "commit": GIT_COMMIT,
    }
    payload.update(extra)
    return json.dumps(payload).encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    server_version = "insecure-infra-demo"

    def _respond(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802 (http.server API)
        if self.path == "/":
            self._respond(200, _json("La aplicacion esta funcionando correctamente"))
        elif self.path == "/health":
            self._respond(200, _json("ok", status="healthy"))
        elif self.path == "/version":
            self._respond(200, _json("version", app_version=APP_VERSION, git_commit=GIT_COMMIT))
        else:
            self._respond(404, _json("not found"))

    def log_message(self, fmt, *args):  # noqa: A003
        # Keep logs on stdout so ECS awslogs can capture them.
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Listening on 0.0.0.0:{PORT} (version={APP_VERSION}, commit={GIT_COMMIT})", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
