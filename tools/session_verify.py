#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

BEARER = (
    "AAAAAAAAAAAAAAAAAAAAAFXzAwAAAAAAMHCxpeSDG1gLNLghVe8d74hl6k4"
    "%3DRUMF4xAQLsbeBhTSRrCiQpJtxoGWeyHrDb5te2jpGskWDFW82F"
)
URL = "https://api.twitter.com/1.1/account/verify_credentials.json"
USER_AGENT = "TwitterAndroid/10.53.2-release.0 (310532000-r-0)"
RED = "\033[31mSUSPENDED\033[0m"
PURPLE = "\033[35mvalid\033[0m"


def verify(auth_token, ct0):
    query = urllib.parse.urlencode(
        {"include_email": "true", "skip_status": "true", "include_entities": "true"}
    )
    req = urllib.request.Request(
        f"{URL}?{query}",
        headers={
            "Authorization": f"Bearer {BEARER}",
            "User-Agent": USER_AGENT,
            "X-Csrf-Token": ct0,
            "Cookie": f"ct0={ct0}; auth_token={auth_token}",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read()
    except urllib.error.HTTPError as e:
        body = e.read()
    except (urllib.error.URLError, OSError) as e:
        return {"errors": [{"message": str(e)}]}
    try:
        data = json.loads(body)
    except ValueError:
        return {}
    return data if isinstance(data, dict) else {}


def errors_of(resp):
    errors = resp.get("errors")
    if not isinstance(errors, list):
        return []
    return [e for e in errors if isinstance(e, dict)]


def account_status(resp):
    if resp.get("suspended") is True or any(e.get("code") == 64 for e in errors_of(resp)):
        return "suspended"
    if resp.get("suspended") is False:
        return "valid"
    return "invalid"


def pretty(resp):
    status = account_status(resp)
    name = resp.get("screen_name") or ""
    if not isinstance(name, str):
        name = ""
    if status != "suspended" and any(e.get("message") is not None for e in errors_of(resp)):
        name += "invalid"
    label = {"suspended": RED, "valid": PURPLE}.get(status, "")
    return " ".join(p for p in (name, label) if p)


def update_session(session, status):
    session = dict(session)
    if status == "suspended":
        session["suspended"] = "true"
    elif status == "valid":
        session.pop("suspended", None)
    return session


def dump(obj):
    return json.dumps(obj, indent=2, ensure_ascii=False)


def show(resp, prefix, raw):
    if raw:
        print(dump(resp))
    else:
        print(" ".join(p for p in (prefix, pretty(resp)) if p))
    sys.stdout.flush()


def process_file(path, out, raw, delay):
    lines_out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\r\n")
            if not line.strip():
                continue
            try:
                session = json.loads(line)
            except ValueError:
                print(f"skipping unparseable line: {line[:40]}", file=sys.stderr)
                lines_out.append(line)
                continue

            kind = session.get("kind") or ""
            username = session.get("username") or ""
            auth_token = session.get("auth_token") or ""
            ct0 = session.get("ct0") or ""

            if not auth_token or not ct0:
                print(
                    f"skipping {username or '<unknown>'} ({kind or 'oauth'}): no auth_token/ct0",
                    file=sys.stderr,
                )
                lines_out.append(line)
                continue

            resp = verify(auth_token, ct0)
            show(resp, f"{auth_token} {kind}", raw)

            updated = update_session(session, account_status(resp))
            lines_out.append(json.dumps(updated, separators=(",", ":"), ensure_ascii=False))
            time.sleep(delay)

    if out:
        fd, tmp = tempfile.mkstemp()
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write("".join(l + "\n" for l in lines_out))
            with open(tmp, encoding="utf-8") as src, open(out, "w", encoding="utf-8") as dst:
                dst.write(src.read())
        finally:
            os.unlink(tmp)
        print(f"wrote {out}", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(
        description="verify_credentials check for a single auth_token or a nitter sessions.jsonl"
    )
    ap.add_argument("-r", "--raw", action="store_true", help="raw verify_credentials json output")
    ap.add_argument(
        "-w",
        "--write",
        metavar="OUT",
        help="write modified sessions to OUT (may be the input file): suspended accounts get "
        '"suspended":"true", valid accounts lose the key, others are left untouched',
    )
    ap.add_argument("-d", "--delay", type=float, default=2.0, help="seconds between sessions (default 2)")
    ap.add_argument("input", help="sessions.jsonl or a 40 character auth_token")
    args = ap.parse_args()

    if os.path.isfile(args.input):
        process_file(args.input, args.write, args.raw, args.delay)
    elif re.fullmatch(r"[0-9a-f]{40}", args.input):
        if args.write:
            print("note: -w only applies to a sessions.jsonl file, ignoring", file=sys.stderr)
        resp = verify(args.input, os.urandom(16).hex())
        show(resp, args.input, args.raw)
    else:
        ap.print_usage(sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
