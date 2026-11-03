#!/usr/bin/env python3
"""Client that calls Inventory through the Kubernetes Service name."""

import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

URL = os.environ.get("INVENTORY_URL", "http://inventory:8080/inventory")
INTERVAL = float(os.environ.get("INTERVAL_SECONDS", "1"))


def stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main() -> None:
    print(f"client starting; inventory service url={URL}", flush=True)
    while True:
        try:
            with urllib.request.urlopen(URL, timeout=2) as response:
                body = json.load(response)
                print(
                    f"{stamp()} OK via {URL} -> pod={body.get('pod')} "
                    f"served={body.get('served')} status={response.status}",
                    flush=True,
                )
        except urllib.error.HTTPError as exc:
            print(f"{stamp()} HTTP {exc.code} via {URL}", flush=True)
        except Exception as exc:
            print(f"{stamp()} ERROR via {URL}: {exc}", flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
