#!/usr/bin/env python3
"""Build and publish the javadoc of each newly released pom-scijava.

Meant for cron (e.g. hourly): it prints nothing when there is nothing to do,
so cron mails only when something happened or went wrong.

A release counts once its GitHub "release" workflow run has succeeded (a bare
tag proves nothing: pom-scijava 38.0.0 was tagged but never deployed) and its
POM is on Maven Central, checked with a single HEAD request. Each new release
is then built with pombast into the build tree, published with this
repository's static files laid over it, and the site checked.

Usage: update.py [--dry-run]
Paths default to this server's layout; override with the environment
variables named in DEFAULTS.
"""

import argparse
import fcntl
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

HOME = Path.home()
SITE = Path(__file__).resolve().parent.parent  # this repository
DEFAULTS = {
    "JD_BUILD": HOME / "javadoc-build",
    "JD_RELEASES": Path("/var/www/javadoc/releases"),
    "JD_LIVE": Path("/var/www/javadoc/current"),
    "JD_POMBAST": HOME / "code/scijava/pombast",
    "JD_POM_SCIJAVA": HOME / "code/scijava/pom-scijava",
    "JD_LOGS": HOME / "javadoc-build-logs",
}
RUNS = (
    "https://api.github.com/repos/scijava/pom-scijava/actions/workflows/"
    "release.yml/runs?status=success&per_page=20"
)
CENTRAL = "https://repo1.maven.org/maven2/org/scijava/pom-scijava/{v}/pom-scijava-{v}.pom"
USER_AGENT = "javadoc.scijava.org-update (+https://github.com/scijava/javadoc.scijava.org)"
TAG = re.compile(r"^pom-scijava-(\d+(?:\.\d+)*)$")
# A build making more requests than this is misbehaving; stop and say so.
MAX_REQUESTS = 3000


def path(name: str) -> Path:
    return Path(os.environ.get(name, DEFAULTS[name]))


def request(url: str, method: str = "GET"):
    req = urllib.request.Request(url, method=method, headers={"User-Agent": USER_AGENT})
    return urllib.request.urlopen(req, timeout=60)


def released_versions() -> list[str]:
    """Versions whose release workflow succeeded, from GitHub."""
    with request(RUNS) as r:
        runs = json.load(r)["workflow_runs"]
    versions = []
    for run in runs:
        m = TAG.match(run.get("head_branch") or "")
        if m and m.group(1) not in versions:
            versions.append(m.group(1))
    return versions


def on_central(version: str) -> bool:
    try:
        with request(CENTRAL.format(v=version), method="HEAD") as r:
            return r.status == 200
    except urllib.error.HTTPError:
        return False


def built(version: str) -> bool:
    union = path("JD_BUILD") / "org.scijava/pom-scijava" / version
    return (union / "redirects.tsv").is_file()


def run(cmd: list[str], cwd: Path, log: Path | None = None) -> str:
    if log:
        # Written as it runs, so a long build can be followed (tail -f).
        with log.open("w") as f:
            code = subprocess.run(cmd, cwd=cwd, stdout=f, stderr=subprocess.STDOUT).returncode
        text = log.read_text(errors="replace")
    else:
        out = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, errors="replace")
        code, text = out.returncode, out.stdout + out.stderr
    if code:
        where = f" (see {log})" if log else ""
        raise SystemExit(f"FAILED ({code}): {' '.join(cmd)}{where}\n{text[-2000:]}")
    return text


def build(version: str) -> None:
    pom_scijava = path("JD_POM_SCIJAVA")
    run(["git", "pull", "-q", "--ff-only"], pom_scijava)  # current pombast.toml
    log = path("JD_LOGS") / f"{version}.log"
    text = run(
        [
            "uv", "run", "--project", str(path("JD_POMBAST")), "pombast", "javadoc",
            "--config", "pombast.toml", "--workers", "2",
            "-o", str(path("JD_BUILD")), f"org.scijava:pom-scijava:{version}",
        ],
        pom_scijava,
        log,
    )  # fmt: skip
    m = re.search(r"Remote requests: (.*)", text)
    counts = [int(n) for n in re.findall(r" (\d+)", m.group(1))] if m else []
    if sum(counts) > MAX_REQUESTS or "Rate-limited" in text:
        raise SystemExit(f"pom-scijava {version}: unexpected repository load; see {log}")
    print(f"Built pom-scijava {version}: {m.group(1) if m else 'no requests'}")


def publish() -> None:
    run(["git", "pull", "-q", "--ff-only"], SITE)  # current front page
    text = run(
        [
            str(path("JD_POMBAST") / "bin/publish-javadoc.sh"), "-s", str(SITE),
            str(path("JD_BUILD")), str(path("JD_RELEASES")), str(path("JD_LIVE")),
        ],
        SITE,
    )  # fmt: skip
    print(text.strip().splitlines()[-1] if "Published" in text else text)
    run([sys.executable, str(SITE / ".tests/check.py"), "-q"], SITE)
    print("Site checks passed.")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("-n", "--dry-run", action="store_true", help="report, change nothing")
    args = ap.parse_args()

    # One run at a time: a build can outlast the cron interval.
    lock = open(path("JD_LOGS") / ".update.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return

    pending = [v for v in released_versions() if not built(v)]
    ready = [v for v in pending if on_central(v)]
    if not ready:
        return
    if args.dry_run:
        print("Would build:", ", ".join(ready))
        return
    for version in ready:
        build(version)
    publish()


if __name__ == "__main__":
    main()
