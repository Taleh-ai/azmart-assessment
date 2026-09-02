# -*- coding: utf-8 -*-
"""
AZMART Orders API — lokal mock server (Python stdlib, heç bir pip paketi tələb etmir).

İşə salmaq:
    python mock_api_server.py            # default port 8008
    python mock_api_server.py --port 9000

Endpoint-lər (bax: OXU_MENI.md):
    GET /health
    GET /api/v1/orders?updated_since=...&updated_until=...&page_size=...&cursor=...
    GET /api/v1/fx/rates?date=YYYY-MM-DD

Bütün /api/* endpoint-ləri `X-API-Key` header-i tələb edir.
DİQQƏT: server QƏSDƏN vaxtaşırı HTTP 429 (Retry-After ilə) və HTTP 500 qaytarır.
Bunları düzgün idarə etmək (retry + backoff + Retry-After-a hörmət) tapşırığın hissəsidir.
Bu faylı dəyişdirmək və ya server_data.bin-i birbaşa oxumaq QADAĞANDIR — ingestion yalnız
HTTP üzərindən olmalıdır.
"""
import argparse
import base64
import gzip
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
SALT = "azmart-v2-cursor"
MAX_PAGE_SIZE = 200
DEFAULT_PAGE_SIZE = 100

STATE = {"orders_request_count": 0}
DATA = {}


def load_data(path):
    with gzip.open(path, "rb") as f:
        blob = json.loads(f.read().decode("utf-8"))
    DATA["api_key"] = blob["api_key"]
    DATA["orders"] = blob["orders"]      # serve order is fixed
    DATA["fx"] = blob["fx"]


def parse_iso_utc(s):
    """Accept 2026-08-25T00:00:00Z / +00:00 / date-only. Return aware UTC dt or None."""
    if not s:
        return None
    s = s.strip()
    if len(s) == 10:
        s += "T00:00:00Z"
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def canon(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def make_cursor(offset, since, until, page_size):
    payload = "%d|%s|%s|%d" % (offset, since, until, page_size)
    sig = hashlib.sha1((payload + SALT).encode()).hexdigest()[:10]
    raw = json.dumps({"p": payload, "s": sig}).encode()
    return base64.urlsafe_b64encode(raw).decode()


def read_cursor(tok, since, until, page_size):
    """Returns offset, or raises ValueError with a client-facing message."""
    try:
        obj = json.loads(base64.urlsafe_b64decode(tok.encode()).decode())
        payload, sig = obj["p"], obj["s"]
    except Exception:
        raise ValueError("malformed cursor")
    if hashlib.sha1((payload + SALT).encode()).hexdigest()[:10] != sig:
        raise ValueError("invalid cursor signature")
    off_s, c_since, c_until, c_ps = payload.split("|")
    if c_since != since or c_until != until or int(c_ps) != page_size:
        raise ValueError("cursor does not match query parameters "
                         "(updated_since/updated_until/page_size changed mid-pagination)")
    return int(off_s)


class Handler(BaseHTTPRequestHandler):
    server_version = "AZMARTMockAPI/2.0"

    def _send(self, code, obj, extra_headers=None):
        body = json.dumps(obj, ensure_ascii=True).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra_headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        sys.stdout.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))
        sys.stdout.flush()

    def do_GET(self):
        parsed = urlparse(self.path)
        route = parsed.path.rstrip("/")
        qs = {k: v[0] for k, v in parse_qs(parsed.query).items()}

        if route == "/health":
            return self._send(200, {"status": "ok", "service": "azmart-orders-api",
                                    "version": "2.0"})

        if not route.startswith("/api/"):
            return self._send(404, {"error": "not found"})

        if self.headers.get("X-API-Key") != DATA["api_key"]:
            return self._send(401, {"error": "missing or invalid X-API-Key header"})

        if route == "/api/v1/orders":
            return self.handle_orders(qs)
        if route == "/api/v1/fx/rates":
            return self.handle_fx(qs)
        return self._send(404, {"error": "not found"})

    # ------------------------------------------------------------ orders
    def handle_orders(self, qs):
        since_dt = parse_iso_utc(qs.get("updated_since"))
        until_dt = parse_iso_utc(qs.get("updated_until"))
        if since_dt is None or until_dt is None:
            return self._send(400, {"error": "updated_since and updated_until are required "
                                             "ISO-8601 UTC timestamps, e.g. "
                                             "updated_since=2026-01-01T00:00:00Z"
                                             "&updated_until=2026-08-25T00:00:00Z. "
                                             "Interval is [since, until)."})
        if until_dt <= since_dt:
            return self._send(400, {"error": "updated_until must be greater than updated_since"})
        try:
            page_size = int(qs.get("page_size", DEFAULT_PAGE_SIZE))
        except ValueError:
            return self._send(400, {"error": "page_size must be an integer"})
        if not (1 <= page_size <= MAX_PAGE_SIZE):
            return self._send(400, {"error": "page_size must be between 1 and %d" % MAX_PAGE_SIZE})

        since, until = canon(since_dt), canon(until_dt)

        offset = 0
        if "cursor" in qs:
            try:
                offset = read_cursor(qs["cursor"], since, until, page_size)
            except ValueError as e:
                return self._send(400, {"error": str(e)})

        # deterministic fault injection (counted only on valid, authed /orders requests)
        STATE["orders_request_count"] += 1
        n = STATE["orders_request_count"]
        if n % 5 == 0:
            return self._send(429, {"error": "rate limit exceeded, slow down"},
                              {"Retry-After": "2"})
        if n % 7 == 0:
            return self._send(500, {"error": "internal server error, please retry"})

        rows = [r for r in DATA["orders"] if since <= r["updated_at"] < until]
        page = rows[offset: offset + page_size]
        next_cursor = None
        if offset + page_size < len(rows):
            next_cursor = make_cursor(offset + page_size, since, until, page_size)
        return self._send(200, {"data": page, "next_cursor": next_cursor,
                                "page_size": page_size})

    # ------------------------------------------------------------ fx
    def handle_fx(self, qs):
        d = qs.get("date")
        if not d or len(d) != 10:
            return self._send(400, {"error": "date=YYYY-MM-DD is required"})
        rates = DATA["fx"].get(d)
        if rates is None:
            return self._send(404, {"error": "no rates published for %s "
                                             "(weekend or holiday)" % d})
        return self._send(200, {"date": d, "quote_currency": "AZN",
                                "note": "rate_azn = 1 vahid valyutanın AZN qarşılığı",
                                "rates": rates})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8008)
    ap.add_argument("--data", default=os.path.join(HERE, "server_data.bin"))
    args = ap.parse_args()
    load_data(args.data)
    srv = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print("AZMART mock API listening on http://127.0.0.1:%d  "
          "(orders: %d rows, fx: %d days)" % (args.port, len(DATA["orders"]), len(DATA["fx"])))
    print("Health check:  curl http://127.0.0.1:%d/health" % args.port)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
