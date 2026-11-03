#!/usr/bin/env python3
"""Send a short burst of requests through the Inventory Service and count replicas."""

import json
import os
import sys
import urllib.request
from collections import Counter

URL = os.environ.get("INVENTORY_URL", "http://inventory:8080/inventory")
REQUESTS = int(os.environ.get("REQUESTS", "20"))
LABEL = os.environ.get("BURST_LABEL", "replica counts")
MIN_PODS = int(os.environ.get("MIN_PODS", "1"))

counts: Counter[str] = Counter()
for _ in range(REQUESTS):
    with urllib.request.urlopen(URL, timeout=2) as response:
        body = json.load(response)
        pod = body["pod"]
        counts[pod] += 1
        print(
            f"via {URL} -> pod={pod} served={body.get('served')} status={response.status}",
            flush=True,
        )

print(f"--- {LABEL} ---")
for pod, count in sorted(counts.items()):
    print(f"{pod}: {count}")

if len(counts) < MIN_PODS:
    print(f"expected at least {MIN_PODS} replica(s), saw {len(counts)}", file=sys.stderr)
    sys.exit(1)
