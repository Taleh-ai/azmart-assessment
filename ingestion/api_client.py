import logging
import os
import time

import requests

log = logging.getLogger("ingestion")

BASE_URL = os.environ.get("API_BASE_URL", "http://127.0.0.1:8008")
API_KEY = os.environ.get("API_KEY", "azcon-de-2026")
TIMEOUT = 10
MAX_ATTEMPTS = 8


def get(path, params):
    for attempt in range(1, MAX_ATTEMPTS + 1):
        response = requests.get(BASE_URL + path, params=params,
                                headers={"X-API-Key": API_KEY}, timeout=TIMEOUT)

        if response.status_code == 429:
            wait = float(response.headers.get("Retry-After", 2))
        elif response.status_code >= 500:
            wait = min(2 ** attempt, 30)
        else:
            response.raise_for_status()
            return response.json()

        log.warning("%d on %s, attempt %d/%d, waiting %.1fs",
                    response.status_code, path, attempt, MAX_ATTEMPTS, wait)
        time.sleep(wait)

    raise RuntimeError("gave up on %s after %d attempts" % (path, MAX_ATTEMPTS))


def fetch_orders(updated_since, updated_until, page_size=200):
    params = {
        "updated_since": updated_since,
        "updated_until": updated_until,
        "page_size": page_size,
    }

    while True:
        payload = get("/api/v1/orders", params)
        log.info("orders page: %d records", len(payload["data"]))
        yield from payload["data"]

        cursor = payload.get("next_cursor")
        if not cursor:
            return
        params["cursor"] = cursor


def fetch_fx_rates(date):
    return get("/api/v1/fx/rates", {"date": date})