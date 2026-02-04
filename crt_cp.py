#!/bin/python3
# this script copies cert recorded in INFO file from src to des.

import json
import sys
import shutil
import os

CERT_FILES = [
    "cert.pem",
    "privkey.pem",
    "fullchain.pem",
]

CERT_BASE_PATH = "/usr/syno/etc/certificate"
PKG_CERT_BASE_PATH = "/usr/local/etc/certificate"

ARCHIVE_PATH = os.path.join(CERT_BASE_PATH, "_archive")
INFO_FILE_PATH = os.path.join(ARCHIVE_PATH, "INFO")


def eprint(msg: str) -> None:
    print(msg, file=sys.stderr)


def main() -> int:
    if len(sys.argv) < 2:
        eprint("[ERROR] Usage: crt_cp.py <SRC_DIR_NAME>")
        return 1

    src_dir_name = sys.argv[1]

    # Load INFO
    try:
        with open(INFO_FILE_PATH, "r", encoding="utf-8") as f:
            info = json.load(f)
        services = info[src_dir_name]["services"]
    except Exception as ex:
        eprint(f"[ERROR] Failed to load INFO file {INFO_FILE_PATH}: {ex}")
        return 1

    cp_from_dir = os.path.join(ARCHIVE_PATH, src_dir_name)
    if not os.path.isdir(cp_from_dir):
        eprint(f"[ERROR] Source certificate directory not found: {cp_from_dir}")
        return 1

    for service in services:
        display_name = service.get("display_name", "")
        is_pkg = bool(service.get("isPkg", False))
        subscriber = service.get("subscriber", "")
        service_name = service.get("service", "")

        print(f"[INFO] Copying certificate for {display_name}")

        base = PKG_CERT_BASE_PATH if is_pkg else CERT_BASE_PATH
        cp_to_dir = os.path.join(base, subscriber, service_name)

        # Ensure destination exists
        try:
            os.makedirs(cp_to_dir, exist_ok=True)
        except Exception as ex:
            eprint(f"[WARN] Cannot create directory {cp_to_dir}: {ex}")

        for fname in CERT_FILES:
            src = os.path.join(cp_from_dir, fname)
            des = os.path.join(cp_to_dir, fname)
            try:
                shutil.copy2(src, des)
            except Exception as ex:
                eprint(f"[WARN] Failed to copy {fname} to {cp_to_dir}: {ex}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
