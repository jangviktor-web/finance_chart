#!/usr/bin/env python3
"""Mirror a finance_chart GitHub release to Gitee.

Workflow (per flutter-gitee-release skill):
  GITEE_TOKEN="<tok>" GITHUB_REF_NAME=v1.11.3 \
    APK_DIR=<dir-with-4-apks> python3 .github/scripts/gitee_release.py

- Creates/PATCHes the Gitee release for the tag.
- Uploads only the explicit 4-APK whitelist (no wildcard -> no stray/debug packages).
- Re-reads assets and retries missing uploads (<=2 rounds) because Gitee's
  attach_files can return 201 yet silently drop the asset (假成功).
"""
from __future__ import annotations
import os
import sys
import json
import time
import subprocess
import urllib.request
import urllib.error
import urllib.parse

API = "https://gitee.com/api/v5"
OWNER = os.environ.get("GITEE_OWNER", "jangviktor")
REPO = os.environ.get("GITEE_REPO", "finance_chart")
TOKEN = os.environ.get("GITEE_TOKEN", "")
TAG = os.environ.get("GITHUB_REF_NAME", "") or (sys.argv[1] if len(sys.argv) > 1 else "")
APK_DIR = os.environ.get("APK_DIR", "build/app/outputs/flutter-apk")
NOTES_DIR = os.environ.get("RELEASE_NOTES_DIR", "release_notes")
# Explicit whitelist — never glob, to avoid uploading stale/debug APKs.
# Mirror the 4 GitHub release packages (1 universal + 3 split-ABI),
# matching what CI builds and what the README download section links.
APK_WHITELIST = [
    "app-release.apk",
    "app-arm64-v8a-release.apk",
    "app-armeabi-v7a-release.apk",
    "app-x86_64-release.apk",
] if TAG else []


def api(method: str, path: str, data=None, is_json=True, raw=False, timeout=120):
    url = f"{API}{path}"
    sep = "&" if "?" in url else "?"
    url += f"{sep}access_token={TOKEN}"
    headers = {}
    body = None
    if data is not None:
        if is_json:
            body = json.dumps(data).encode("utf-8")
            headers["Content-Type"] = "application/json"
        else:
            body = data  # pre-built multipart bytes
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw_body = r.read()
            return r.status, (raw_body if raw else (json.loads(raw_body) if raw_body else {}))
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "ignore")
    except Exception as e:  # timeout / connection reset -> treated as retryable
        return 0, f"{type(e).__name__}: {e}"


def find_or_create_release(body: str):
    code, releases = api("GET", f"/repos/{OWNER}/{REPO}/releases?per_page=100")
    rel_id = None
    if code == 200 and isinstance(releases, list):
        for r in releases:
            if r.get("tag_name") == TAG:
                rel_id = r["id"]
                break
    if rel_id:
        # NOTE: Gitee's PATCH /releases/{id} REQUIRES tag_name — omitting it -> 400.
        code, resp = api("PATCH", f"/repos/{OWNER}/{REPO}/releases/{rel_id}",
                         {"tag_name": TAG, "name": TAG, "body": body, "prerelease": False})
        if code == 200:
            return rel_id
        print(f"WARN: PATCH failed ({code}); will try recreate-safe path", flush=True)
        return rel_id
    code, resp = api("POST", f"/repos/{OWNER}/{REPO}/releases",
                     {"tag_name": TAG, "name": TAG, "body": body,
                      "target_commitish": "master", "prerelease": False})
    if code == 201 and isinstance(resp, dict):
        return resp.get("id")
    # Already exists (race) -> refetch
    if code in (403, 409, 422):
        _, releases = api("GET", f"/repos/{OWNER}/{REPO}/releases?per_page=100")
        if isinstance(releases, list):
            for r in releases:
                if r.get("tag_name") == TAG:
                    return r["id"]
    print(f"ERROR: create release failed: {code} {resp}")
    sys.exit(1)


def upload_apk(rel_id: int, fn: str) -> bool:
    src = os.path.join(APK_DIR, fn)
    if not os.path.exists(src):
        print(f"SKIP (missing locally): {fn}", flush=True)
        return False
    # Use curl to STREAM the file as multipart: avoids loading ~67MB into RAM
    # and tolerates slow links (urllib's 120s socket timeout used to abort here).
    url = f"{API}/repos/{OWNER}/{REPO}/releases/{rel_id}/attach_files?access_token={TOKEN}"
    cmd = [
        "curl", "-sS", "--ssl-no-revoke",
        "--connect-timeout", "60", "--max-time", "1800",
        "-X", "POST", url,
        "-F", f"file=@{src}",
    ]
    p = subprocess.run(cmd, capture_output=True, text=True)
    body = (p.stdout or "").strip()
    ok = p.returncode == 0 and fn in body
    print(f"  upload {fn}: curl rc={p.returncode} {'OK' if ok else 'FAIL'}", flush=True)
    if not ok:
        print(f"    detail: {(body or p.stderr)[:300]}", flush=True)
    return ok


def get_asset_names(rel_id: int):
    code, rel = api("GET", f"/repos/{OWNER}/{REPO}/releases/{rel_id}")
    if code == 200 and isinstance(rel, dict):
        return {a.get("name") for a in rel.get("assets", [])}
    return set()


def main():
    if not TOKEN:
        print("ERROR: GITEE_TOKEN not set", flush=True)
        sys.exit(2)
    if not TAG:
        print("ERROR: tag not provided (set GITHUB_REF_NAME or pass as argv)", flush=True)
        sys.exit(2)

    body_path = os.path.join(NOTES_DIR, f"{TAG}.md")
    if os.path.exists(body_path):
        with open(body_path, encoding="utf-8") as f:
            body = f.read()
    else:
        body = f"## 策盈 QuantWin {TAG}\n\n详见 GitHub Release。"

    print(f"==> release for {TAG}", flush=True)
    rel_id = find_or_create_release(body)
    if not rel_id:
        print("ERROR: no release id", flush=True)
        sys.exit(1)

    present = get_asset_names(rel_id)
    for fn in APK_WHITELIST:
        if fn in present:
            print(f"OK (already): {fn}", flush=True)

    # Retry loop: Gitee attach_files 假成功 / 慢链路超时 -> re-read and补传 (<=3 rounds)
    for _round in range(3):
        present = get_asset_names(rel_id)
        missing = [f for f in APK_WHITELIST
                   if f not in present and os.path.exists(os.path.join(APK_DIR, f))]
        if not missing:
            break
        print(f"-- round {_round+1}: uploading {missing}", flush=True)
        for fn in missing:
            upload_apk(rel_id, fn)
        time.sleep(2)

    final = get_asset_names(rel_id)
    still_missing = [f for f in APK_WHITELIST if f not in final]
    if still_missing:
        print(f"❌ 核验失败，仍缺失: {still_missing}", flush=True)
        sys.exit(1)
    # also confirm the release body (notes) actually landed
    _, rel = api("GET", f"/repos/{OWNER}/{REPO}/releases/{rel_id}")
    body_len = len((rel or {}).get("body") or "") if isinstance(rel, dict) else 0
    if body_len == 0:
        print("⚠️ 发行说明正文为空（PATCH 可能失败）", flush=True)
    print(f"✅ 核验通过：{len(APK_WHITELIST)} 个附件均已挂载 {APK_WHITELIST}（正文 {body_len} 字）", flush=True)
    print(f"   页面: https://gitee.com/{OWNER}/{REPO}/releases/tag/{TAG}")
    sys.exit(0)


if __name__ == "__main__":
    main()
