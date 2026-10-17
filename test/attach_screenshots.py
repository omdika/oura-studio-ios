#!/usr/bin/env python3
"""Lampirkan screenshot Maestro terakhir ke hasil Allure.

Alur: baca status dari JUnit XML Maestro (test-results/maestro/report.xml),
ambil PNG terbaru dari test-results/maestro-artifacts/*/TC003_DashboardFlow/,
tulis satu Allure result JSON + attachment ke test-results/allure-results/.

Pakai: python3 test/attach_screenshots.py [--flow TC003_DashboardFlow] [--tc TC-003]
Doc: doc/test/TC-003-dashboard-maestro-allure.md
"""
import argparse
import glob
import json
import os
import shutil
import sys
import time
import uuid
import xml.etree.ElementTree as ET
from typing import Optional, Tuple

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def latest_run_dir(flow: str) -> Optional[str]:
    pattern = os.path.join(
        ROOT, "test-results", "maestro-artifacts", "*", flow, "takeScreenshot"
    )
    candidates = sorted(glob.glob(pattern))
    if not candidates:
        return None
    # Struktur: .../maestro-artifacts/<timestamp>/<flow>/takeScreenshot -> naik 2 level = run dir
    run_dirs = sorted({os.path.dirname(os.path.dirname(p)) for p in candidates})
    return run_dirs[-1]


def junit_status(report: str) -> Tuple[str, float]:
    """Return (allure_status, elapsed_seconds). Default passed/0 bila XML tak ada."""
    if not os.path.exists(report):
        return "passed", 0.0
    tree = ET.parse(report)
    for tc in tree.getroot().iter("testcase"):
        elapsed = float(tc.get("time", 0) or 0)
        bad = tc.find("failure") is not None or tc.find("error") is not None
        skipped = tc.find("skipped") is not None
        status = "failed" if bad else ("skipped" if skipped else "passed")
        return status, elapsed
    return "passed", 0.0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--flow", default="TC003_DashboardFlow")
    ap.add_argument("--tc", default="TC-003")
    args = ap.parse_args()

    run_dir = latest_run_dir(args.flow)
    if not run_dir:
        print("Tidak ada screenshot Maestro di test-results/maestro-artifacts/", file=sys.stderr)
        return 1
    shots = sorted(glob.glob(os.path.join(run_dir, args.flow, "takeScreenshot", "*.png")))
    if not shots:
        print(f"Tidak ada PNG di {run_dir}", file=sys.stderr)
        return 1

    status, elapsed = junit_status(os.path.join(ROOT, "test-results", "maestro", "report.xml"))

    out = os.path.join(ROOT, "test-results", "allure-results")
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out, exist_ok=True)

    stop_ms = int(time.time() * 1000)
    start_ms = stop_ms - int(elapsed * 1000)
    attachments = []
    for shot in shots:
        uid = uuid.uuid4().hex
        dest = f"{uid}-attachment.png"
        shutil.copyfile(shot, os.path.join(out, dest))
        attachments.append(
            {"name": os.path.splitext(os.path.basename(shot))[0],
             "source": dest, "type": "image/png"}
        )

    result = {
        "uuid": uuid.uuid4().hex,
        "historyId": args.tc,
        "testCaseId": args.tc,
        "name": args.flow,
        "fullName": f"{args.tc} {args.flow}",
        "status": status,
        "stage": "finished",
        "start": start_ms,
        "stop": stop_ms,
        "attachments": attachments,
        "labels": [
            {"name": "testClass", "value": args.tc},
            {"name": "suite", "value": "Maestro"},
        ],
    }
    with open(os.path.join(out, f"{result['uuid']}-result.json"), "w") as f:
        json.dump(result, f)

    print(f"status={status} screenshots={len(shots)} run={os.path.basename(run_dir)} out={out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
