"""Publish a tested installer using the user's existing Git Credential Manager login.

Run without --publish to review the exact release and assets. Never prints secrets.
"""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
REPO = "nobklop/OPTIMUM"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Unexpected redirect from authenticated GitHub API")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--publish", action="store_true")
    parser.add_argument("--latest", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("Expected major.minor.patch")
    version = args.version
    assets = [ROOT / "dist" / "installers" / f"OPTIMUM-{version}-Setup-x64.exe"]
    assets.append(assets[0].with_suffix(".exe.sha256"))
    notes = ROOT / "docs" / "releases" / f"v{version}.md"
    body = notes.read_text(encoding="utf-8")
    for asset in assets:
        if not asset.is_file():
            raise RuntimeError(f"Missing asset: {asset.name}")
    sha = hashlib.sha256(assets[0].read_bytes()).hexdigest()
    if assets[1].read_text().split()[0] != sha:
        raise RuntimeError("Installer SHA-256 mismatch")
    tag = f"v{version}"
    remote = subprocess.run(["git", "remote", "get-url", "origin"], cwd=ROOT,
                            capture_output=True, text=True, check=True).stdout.strip()
    if remote not in {f"https://github.com/{REPO}.git", f"git@github.com:{REPO}.git"}:
        raise RuntimeError("Origin does not match the authorized release repository")
    refs = subprocess.run(["git", "ls-remote", "origin", f"refs/tags/{tag}"],
                          cwd=ROOT, check=True, capture_output=True, text=True)
    if not refs.stdout.strip():
        raise RuntimeError("Publish the verified source tag first")
    print(json.dumps({"repo": REPO, "tag": tag, "assets": [p.name for p in assets],
                      "installer_sha256": sha, "publish": args.publish}, ensure_ascii=False))
    if not args.publish:
        print(body)
        return
    credential = subprocess.run(
        ["git", "-c", "credential.interactive=false", "credential", "fill"],
        cwd=ROOT, input="protocol=https\nhost=github.com\n\n", text=True,
        capture_output=True, check=False)
    if credential.returncode:
        raise RuntimeError("Git Credential Manager login required")
    values = dict(line.split("=", 1) for line in credential.stdout.splitlines() if "=" in line)
    token = values.get("password")
    if not token:
        raise RuntimeError("Git credential is unavailable")
    opener = urllib.request.build_opener(NoRedirect())

    def api(path, method="GET", data=None, binary=False):
        url = path if path.startswith("https://") else f"https://api.github.com/repos/{REPO}/{path}"
        if urllib.parse.urlparse(url).hostname not in {"api.github.com", "uploads.github.com"}:
            raise RuntimeError("Unexpected GitHub host")
        payload = data if binary else (json.dumps(data).encode() if data is not None else None)
        req = urllib.request.Request(url, data=payload, method=method, headers={
            "Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "OPTIMUM-release-builder",
            "Content-Type": "application/octet-stream" if binary else "application/json",
        })
        with opener.open(req, timeout=120) as response:
            return json.load(response)

    reference = api(f"git/ref/tags/{tag}")
    if reference["object"]["sha"] != refs.stdout.split()[0]:
        raise RuntimeError("Remote source tag changed before release publication")
    try:
        release = api(f"releases/tags/{tag}")
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise RuntimeError(f"GitHub release lookup failed: HTTP {error.code}") from None
        release = api("releases", "POST", {"tag_name": tag, "name": f"OPTIMUM {version}",
                                           "body": body, "draft": True})
    existing = {entry["name"]: entry for entry in release["assets"]}
    for asset in assets:
        data = asset.read_bytes()
        digest = "sha256:" + hashlib.sha256(data).hexdigest()
        if asset.name in existing:
            entry = existing[asset.name]
            if entry.get("digest") != digest or entry["size"] != len(data):
                raise RuntimeError(f"Existing asset differs; refusing to overwrite: {asset.name}")
            continue
        upload = release["upload_url"].split("{", 1)[0] + "?name=" + urllib.parse.quote(asset.name)
        result = api(upload, "POST", data, binary=True)
        if result["size"] != len(data) or result.get("digest") != digest:
            raise RuntimeError("GitHub asset verification failed; release remains draft")
    release = api(f'releases/{release["id"]}', "PATCH", {
        "body": body, "draft": False, "make_latest": "true" if args.latest else "false",
    })
    print(release["html_url"])


if __name__ == "__main__":
    main()
