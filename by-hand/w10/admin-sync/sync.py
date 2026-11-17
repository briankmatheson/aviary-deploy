"""Keep a Gitea team equal to Gitea's site administrators.

The gateway's gates in front of the System apps can only see teams (the
groups claim of Gitea's ID token), not the is_admin flag on an account. This
makes the team follow the flag: every active site administrator is a member,
and nobody else is. Run on a schedule; it changes nothing when they agree.
"""
import json
import os
import sys
import urllib.parse
import urllib.request

API = os.environ["GITEA_URL"].rstrip("/") + "/api/v1"
ORG, TEAM = os.environ.get("ADMIN_TEAM", "aviary:admins").split(":", 1)
TOKEN = open(os.environ.get("TOKEN_FILE", "/token/token")).read().strip()
DRY = os.environ.get("DRY_RUN", "") not in ("", "0", "false")


def call(method, path):
    req = urllib.request.Request(API + path, method=method, headers={"Authorization": "token " + TOKEN})
    with urllib.request.urlopen(req, timeout=20) as r:
        body = r.read()
    return json.loads(body) if body else None


def pages(path):
    out, page = [], 1
    while True:
        got = call("GET", f"{path}{'&' if '?' in path else '?'}limit=50&page={page}")
        out += got
        if len(got) < 50:
            return out
        page += 1


admins = {u["login"] for u in pages("/admin/users")
          if u.get("is_admin") and u.get("active") and not u.get("prohibit_login")}
if not admins:
    sys.exit("gitea lists no site administrators: refusing to empty the team")
team = next((t for t in pages(f"/orgs/{ORG}/teams") if t["name"] == TEAM), None)
if not team:
    sys.exit(f"no team {TEAM} in organisation {ORG}")
members = {u["login"] for u in pages(f"/teams/{team['id']}/members")}
would = "would have " if DRY else ""
for login in sorted(admins - members):
    if not DRY:
        call("PUT", f"/teams/{team['id']}/members/{urllib.parse.quote(login)}")
    print(f"{would}added {login} to {ORG}:{TEAM} (site administrator)")
for login in sorted(members - admins):
    if not DRY:
        call("DELETE", f"/teams/{team['id']}/members/{urllib.parse.quote(login)}")
    print(f"{would}removed {login} from {ORG}:{TEAM} (not a site administrator)")
if admins == members:
    print(f"{ORG}:{TEAM} = site administrators ({', '.join(sorted(admins))})")
